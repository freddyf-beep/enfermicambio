package com.enfermicambio.healthbridge.sync

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import com.enfermicambio.healthbridge.health.HealthConnectReader
import com.enfermicambio.healthbridge.health.HealthPermissions
import com.enfermicambio.healthbridge.network.IngestHealthClient
import com.enfermicambio.healthbridge.network.IngestResult
import com.enfermicambio.healthbridge.storage.SecureSettingsStore
import com.enfermicambio.healthbridge.storage.SyncStatus
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.UUID

sealed class SyncRunResult {
    data class Success(val message: String, val days: Int, val exercise: Int, val httpCode: Int = 200) : SyncRunResult()
    data class Failure(val message: String, val retryable: Boolean, val httpCode: Int? = null, val requiresRepairing: Boolean = false) : SyncRunResult()
}

class HealthSyncRepository(
    private val context: Context,
    private val store: SecureSettingsStore = SecureSettingsStore(context),
    private val network: IngestHealthClient = IngestHealthClient(),
) {
    suspend fun validateAndSave(pairing: com.enfermicambio.healthbridge.pairing.PairingPayload): IngestResult {
        val result = network.validate(pairing)
        if (result is IngestResult.Success && result.validated) store.savePairing(pairing)
        return result
    }

    suspend fun syncOnce(): SyncRunResult {
        val pairing = store.loadPairing()
            ?: return SyncRunResult.Failure("Falta emparejar este Android con EnfermiCambio.", false)
        if (HealthPermissions.availability(context) != HealthConnectClient.SDK_AVAILABLE) {
            return SyncRunResult.Failure("Health Connect no está disponible en este dispositivo.", false)
        }
        val reader = runCatching { HealthConnectReader(context) }.getOrElse {
            return SyncRunResult.Failure("No se pudo abrir Health Connect.", false)
        }
        if (!runCatching { reader.hasBasePermissions() }.getOrDefault(false)) {
            return SyncRunResult.Failure("Faltan permisos de Health Connect. Ábrelos desde Permisos.", false)
        }
        val batchId = store.getOrCreatePendingBatchId(::newBatchId)
        val snapshot = try {
            reader.read(store.syncDays)
        } catch (_: SecurityException) {
            return SyncRunResult.Failure("Faltan permisos de Health Connect. Revisa Permisos.", false)
        } catch (_: Exception) {
            return SyncRunResult.Failure("No se pudieron leer los datos de Health Connect.", true)
        }
        if (snapshot.dailyTotals.isEmpty() && snapshot.exercise.isEmpty()) {
            store.clearPendingBatch()
            val status = SyncStatus(
                lastSyncEpochMillis = System.currentTimeMillis(),
                lastHttpCode = 200,
                lastDaysSent = 0,
                lastExerciseSent = 0,
                lastMessage = "No hay datos nuevos",
            )
            store.saveStatus(status)
            return SyncRunResult.Success("No hay datos nuevos", 0, 0)
        }
        val payload = HealthPayload(
            device = reader.deviceName(),
            batchId = batchId,
            dailyTotals = snapshot.dailyTotals,
            exercise = snapshot.exercise,
        ).toJson()
        if (payload.toByteArray(Charsets.UTF_8).size > MAX_PAYLOAD_BYTES) {
            return SyncRunResult.Failure("Reduce el período de sincronización e inténtalo nuevamente.", false, 413)
        }
        return when (val result = network.ingest(pairing, payload)) {
            is IngestResult.Success -> {
                store.clearPendingBatch()
                store.saveStatus(
                    SyncStatus(
                        lastSyncEpochMillis = System.currentTimeMillis(),
                        lastHttpCode = result.httpCode,
                        lastDaysSent = snapshot.dailyTotals.size,
                        lastExerciseSent = snapshot.exercise.size,
                        lastMessage = result.warning ?: "Sincronización completada",
                    )
                )
                SyncRunResult.Success(
                    result.warning ?: "Sincronización completada",
                    snapshot.dailyTotals.size,
                    snapshot.exercise.size,
                    result.httpCode,
                )
            }
            is IngestResult.Failure -> {
                if (!result.retryable) store.clearPendingBatch()
                store.saveStatus(
                    store.loadStatus().copy(
                        lastHttpCode = result.httpCode ?: 0,
                        lastMessage = result.userMessage,
                    )
                )
                SyncRunResult.Failure(
                    result.userMessage,
                    result.retryable,
                    result.httpCode,
                    result.requiresRepairing,
                )
            }
        }
    }

    companion object {
        const val MAX_PAYLOAD_BYTES = 900 * 1024
        private val BATCH_TIME = DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss'Z'").withZone(ZoneOffset.UTC)
        fun newBatchId(): String = "android-${BATCH_TIME.format(Instant.now())}-${UUID.randomUUID()}"
    }
}
