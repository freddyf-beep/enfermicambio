package com.enfermicambio.healthbridge

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.enfermicambio.healthbridge.ui.MainUiState
import com.enfermicambio.healthbridge.ui.MainViewModel
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val vm: MainViewModel = viewModel()
            intent?.dataString?.let { link ->
                LaunchedEffect(link) { vm.handlePairingInput(link) }
            }
            HealthBridgeApp(vm)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        recreate()
    }
}

@Composable
private fun HealthBridgeApp(vm: MainViewModel) {
    val state by vm.ui.collectAsStateWithLifecycle()
    var requestWasForAuto by remember { mutableStateOf(false) }
    val permissionsLauncher = rememberLauncherForActivityResult(
        PermissionController.createRequestPermissionResultContract()
    ) { granted -> vm.onPermissionsResult(granted, requestWasForAuto) }
    val qrLauncher = rememberLauncherForActivityResult(ScanContract()) { result ->
        result.contents?.let(vm::handlePairingInput)
    }
    val dark = androidx.compose.foundation.isSystemInDarkTheme()
    MaterialTheme(colorScheme = if (dark) darkColorScheme() else lightColorScheme()) {
        Scaffold { padding ->
            Column(
                Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                if (state.paired == null) {
                    Welcome(
                        state = state,
                        onScan = {
                            qrLauncher.launch(
                                ScanOptions()
                                    .setPrompt("Escanea el código de EnfermiCambio")
                                    .setBeepEnabled(false)
                                    .setOrientationLocked(false)
                            )
                        },
                        onManual = vm::handlePairingInput,
                        onConfirm = vm::confirmPairing,
                        onCancel = vm::cancelPendingPairing,
                    )
                } else {
                    Connected(
                        state = state,
                        onTest = vm::testConnection,
                        onSync = vm::syncNow,
                        onRequestBasePermissions = {
                            requestWasForAuto = false
                            permissionsLauncher.launch(vm.basePermissions())
                        },
                        onEnableAuto = {
                            requestWasForAuto = true
                            permissionsLauncher.launch(vm.automaticPermissions())
                        },
                        onDisableAuto = vm::disableAutomaticSync,
                        onInterval = vm::setInterval,
                        onDays = vm::setDays,
                        onManual = vm::handlePairingInput,
                        onDisconnect = vm::disconnect,
                    )
                }
            }
        }
    }
}

@Composable
private fun Welcome(
    state: MainUiState,
    onScan: () -> Unit,
    onManual: (String) -> Unit,
    onConfirm: () -> Unit,
    onCancel: () -> Unit,
) {
    Text("Conecta tu Android", style = MaterialTheme.typography.headlineMedium)
    Text("EnfermiCambio leerá pasos, calorías, distancia y entrenamientos desde Health Connect. Tus datos se envían solo a tu cuenta.")
    state.pendingPairing?.let { pending ->
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Confirma el emparejamiento", style = MaterialTheme.typography.titleMedium)
                Text("Servidor: ${pending.truncatedEndpoint}")
                Text("Código: ${pending.tokenPrefix}…")
                Button(onClick = onConfirm, enabled = !state.busy, modifier = Modifier.fillMaxWidth()) { Text("Probar y guardar") }
                TextButton(onClick = onCancel, modifier = Modifier.fillMaxWidth()) { Text("Cancelar") }
            }
        }
    } ?: run {
        Button(onClick = onScan, modifier = Modifier.fillMaxWidth()) { Text("Escanear código QR") }
        ManualImport(onManual)
    }
    StatusMessage(state.message)
}

@Composable
private fun Connected(
    state: MainUiState,
    onTest: () -> Unit,
    onSync: () -> Unit,
    onRequestBasePermissions: () -> Unit,
    onEnableAuto: () -> Unit,
    onDisableAuto: () -> Unit,
    onInterval: (Long) -> Unit,
    onDays: (Int) -> Unit,
    onManual: (String) -> Unit,
    onDisconnect: () -> Unit,
) {
    val context = LocalContext.current
    Text("EnfermiCambio Salud", style = MaterialTheme.typography.headlineMedium)
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            val status = when {
                state.healthStatus != HealthConnectClient.SDK_AVAILABLE -> "Health Connect no disponible"
                !state.hasBasePermissions -> "Falta permiso"
                else -> "Conectado"
            }
            Text(status, style = MaterialTheme.typography.titleLarge)
            Text("Última sincronización: ${state.lastSyncText}")
            Text("Último envío: ${state.lastSentText}")
            Button(onClick = onSync, enabled = !state.busy, modifier = Modifier.fillMaxWidth()) { Text("Sincronizar ahora") }
            OutlinedButton(onClick = onTest, enabled = !state.busy, modifier = Modifier.fillMaxWidth()) { Text("Probar conexión") }
        }
    }

    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Permisos", style = MaterialTheme.typography.titleMedium)
            PermissionLine("Pasos", state.hasBasePermissions)
            PermissionLine("Distancia", state.hasBasePermissions)
            PermissionLine("Calorías activas", state.hasBasePermissions)
            PermissionLine("Entrenamientos", state.hasBasePermissions)
            Text("Ruta GPS: no solicitada en esta versión")
            if (state.healthStatus == HealthConnectClient.SDK_AVAILABLE) {
                OutlinedButton(onClick = onRequestBasePermissions, modifier = Modifier.fillMaxWidth()) { Text("Revisar permisos") }
            } else {
                OutlinedButton(
                    onClick = {
                        val uri = Uri.parse("market://details?id=com.google.android.apps.healthdata&url=healthconnect%3A%2F%2Fonboarding")
                        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, uri)) }
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Instalar/abrir Health Connect") }
            }
        }
    }

    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Column { Text("Sincronización automática"); Text("Android puede retrasarla", style = MaterialTheme.typography.bodySmall) }
        Switch(
            checked = state.automaticSync,
            onCheckedChange = { if (it) onEnableAuto() else onDisableAuto() },
        )
    }

    AdvancedSettings(state, onInterval, onDays, onManual, onDisconnect)
    if (state.healthStatus == HealthConnectClient.SDK_AVAILABLE) {
        OutlinedButton(
            onClick = { context.startActivity(Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)) },
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Abrir Health Connect") }
    }
    OutlinedButton(
        onClick = { context.startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) },
        modifier = Modifier.fillMaxWidth(),
    ) { Text("Abrir ajustes de batería") }
    StatusMessage(state.message)
}

@Composable
private fun PermissionLine(label: String, granted: Boolean) {
    Text("${if (granted) "✓" else "•"} $label")
}

@Composable
private fun AdvancedSettings(
    state: MainUiState,
    onInterval: (Long) -> Unit,
    onDays: (Int) -> Unit,
    onManual: (String) -> Unit,
    onDisconnect: () -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    TextButton(onClick = { expanded = !expanded }) { Text(if (expanded) "Ocultar configuración avanzada" else "Configuración avanzada") }
    if (!expanded) return
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Intervalo", style = MaterialTheme.typography.titleMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf(15L, 30L, 60L, 180L).forEach { value ->
                    OutlinedButton(onClick = { onInterval(value) }, enabled = state.intervalMinutes != value) { Text("$value m") }
                }
            }
            Text("Período de lectura", style = MaterialTheme.typography.titleMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf(1, 3, 7, 14).forEach { value ->
                    OutlinedButton(onClick = { onDays(value) }, enabled = state.syncDays != value) { Text("$value d") }
                }
            }
            state.paired?.let {
                Text("Endpoint: ${it.truncatedEndpoint}")
                Text("Token: ${it.tokenPrefix}…")
            }
            ManualImport(onManual)
            OutlinedButton(onClick = onDisconnect, modifier = Modifier.fillMaxWidth()) { Text("Desconectar este Android") }
        }
    }
}

@Composable
private fun ManualImport(onManual: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    var value by remember { mutableStateOf("") }
    TextButton(onClick = { expanded = !expanded }) { Text("Pegar código manual") }
    if (expanded) {
        OutlinedTextField(
            value = value,
            onValueChange = { value = it },
            label = { Text("JSON, enlace, endpoint + token o token") },
            minLines = 3,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(6.dp))
        OutlinedButton(onClick = { onManual(value) }, enabled = value.isNotBlank(), modifier = Modifier.fillMaxWidth()) { Text("Importar código") }
    }
}

@Composable
private fun StatusMessage(message: String) {
    if (message.isNotBlank()) Text(message, style = MaterialTheme.typography.bodyMedium)
}
