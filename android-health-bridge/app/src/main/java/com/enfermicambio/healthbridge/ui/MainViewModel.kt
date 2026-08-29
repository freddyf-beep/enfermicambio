package com.enfermicambio.healthbridge.ui

import android.app.Application
import androidx.health.connect.client.HealthConnectClient
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.enfermicambio.healthbridge.health.HealthPermissions
import com.enfermicambio.healthbridge.network.IngestHealthClient
import com.enfermicambio.healthbridge.network.IngestResult
import com.enfermicambio.healthbridge.pairing.PairingParseResult
import com.enfermicambio.healthbridge.pairing.PairingParser
import com.enfermicambio.healthbridge.pairing.PairingPayload
import com.enfermicambio.healthbridge.storage.SecureSettingsStore
import com.enfermicambio.healthbridge.sync.HealthSyncRepository
import com.enfermicambio.healthbridge.sync.SyncRunResult
import com.enfermicambio.healthbridge.sync.SyncScheduler
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.text.DateFormat
import java.util.Date

data class MainUiState(
    val paired: PairingPayload? = null,
    val pendingPairing: PairingPayload? = null,
    val message: String = "",
    val busy: Boolean = false,
    val healthStatus: Int = HealthConnectClient.SDK_UNAVAILABLE,
    val hasBasePermissions: Boolean = false,
    val automaticSync: Boolean = false,
    val intervalMinutes: Long = 60,
    val syncDays: Int = 7,
    val lastSyncText: String = "Nunca",
    val lastSentText: String = "0 días · 0 entrenamientos",
)

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val context = application.applicationContext
    private val store = SecureSettingsStore(context)
    private val parser = PairingParser()
    private val network = IngestHealthClient()
    private val repository = HealthSyncRepository(context, store, network)
    private val _ui = MutableStateFlow(loadState())
    val ui: StateFlow<MainUiState> = _ui.asStateFlow()

    init { refreshPermissions() }

    fun handlePairingInput(raw: String?) {
        if (raw.isNullOrBlank()) return
        when (val result = parser.parse(raw)) {
            is PairingParseResult.Valid -> _ui.value = _ui.value.copy(
                pendingPairing = result.payload,
                message = "Revisa el servidor y confirma la conexión.",
            )
            is PairingParseResult.Invalid -> _ui.value = _ui.value.copy(message = result.message)
        }
    }

    fun confirmPairing() {
        val pending = _ui.value.pendingPairing ?: return
        viewModelScope.launch {
            setBusy(true)
            when (val result = repository.validateAndSave(pending)) {
                is IngestResult.Success -> {
                    _ui.value = loadState().copy(message = "Conexión lista")
                    refreshPermissions()
                }
                is IngestResult.Failure -> _ui.value = _ui.value.copy(message = result.userMessage, busy = false)
            }
        }
    }

    fun cancelPendingPairing() {
        _ui.value = _ui.value.copy(pendingPairing = null, message = "")
    }

    fun testConnection() {
        val pairing = store.loadPairing() ?: return
        viewModelScope.launch {
            setBusy(true)
            _ui.value = when (val result = network.validate(pairing)) {
                is IngestResult.Success -> _ui.value.copy(message = "Conexión lista", busy = false)
                is IngestResult.Failure -> _ui.value.copy(message = result.userMessage, busy = false)
            }
        }
    }

    fun syncNow() {
        viewModelScope.launch {
            setBusy(true)
            _ui.value = when (val result = repository.syncOnce()) {
                is SyncRunResult.Success -> loadState().copy(
                    message = if (result.days == 0 && result.exercise == 0) "No hay datos nuevos" else "${result.message}: ${result.days} días · ${result.exercise} entrenamientos",
                    busy = false,
                )
                is SyncRunResult.Failure -> {
                    if (result.retryable) SyncScheduler.enqueueManual(context)
                    loadState().copy(message = result.message, busy = false)
                }
            }
        }
    }

    fun refreshPermissions() {
        val healthStatus = HealthPermissions.availability(context)
        if (healthStatus != HealthConnectClient.SDK_AVAILABLE) {
            _ui.value = _ui.value.copy(healthStatus = healthStatus, hasBasePermissions = false)
            return
        }
        viewModelScope.launch {
            val granted = runCatching {
                HealthConnectClient.getOrCreate(context).permissionController.getGrantedPermissions()
            }.getOrDefault(emptySet())
            _ui.value = _ui.value.copy(
                healthStatus = healthStatus,
                hasBasePermissions = granted.containsAll(HealthPermissions.baseReadPermissions),
            )
        }
    }

    fun onPermissionsResult(granted: Set<String>, enablingAutomatic: Boolean) {
        val baseGranted = granted.containsAll(HealthPermissions.baseReadPermissions)
        _ui.value = _ui.value.copy(
            hasBasePermissions = baseGranted,
            message = if (baseGranted) "Permisos de Health Connect listos" else "Faltan permisos; la sincronización quedará limitada.",
        )
        if (enablingAutomatic && baseGranted) {
            store.automaticSync = true
            SyncScheduler.schedulePeriodic(context, store.intervalMinutes)
            _ui.value = _ui.value.copy(automaticSync = true)
        }
    }

    fun disableAutomaticSync() {
        store.automaticSync = false
        SyncScheduler.cancelPeriodic(context)
        _ui.value = _ui.value.copy(automaticSync = false, message = "Sincronización automática pausada")
    }

    fun setInterval(minutes: Long) {
        store.intervalMinutes = minutes
        if (store.automaticSync) SyncScheduler.schedulePeriodic(context, minutes)
        _ui.value = _ui.value.copy(intervalMinutes = minutes)
    }

    fun setDays(days: Int) {
        store.syncDays = days
        _ui.value = _ui.value.copy(syncDays = days)
    }

    fun disconnect() {
        SyncScheduler.cancelAll(context)
        store.disconnect()
        _ui.value = loadState().copy(message = "Este Android fue desconectado localmente.")
    }

    fun basePermissions() = HealthPermissions.baseReadPermissions
    fun automaticPermissions() = HealthPermissions.permissionsForAutomaticSync(context)

    private fun setBusy(busy: Boolean) { _ui.value = _ui.value.copy(busy = busy) }

    private fun loadState(): MainUiState {
        val status = store.loadStatus()
        return MainUiState(
            paired = store.loadPairing(),
            healthStatus = HealthPermissions.availability(context),
            automaticSync = store.automaticSync,
            intervalMinutes = store.intervalMinutes,
            syncDays = store.syncDays,
            lastSyncText = if (status.lastSyncEpochMillis > 0) DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT).format(Date(status.lastSyncEpochMillis)) else "Nunca",
            lastSentText = "${status.lastDaysSent} días · ${status.lastExerciseSent} entrenamientos",
            message = status.lastMessage,
        )
    }
}
