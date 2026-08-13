package com.enfermicambio.enfermicambio

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "enfermicambio/launcher_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "setLauncherIcon") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val logoId = call.argument<String>("logoId") ?: "default"
                val target = when (logoId) {
                    "red-transparent" -> ".LauncherRedTransparent"
                    "red-cropped" -> ".LauncherRedCropped"
                    "medical-cropped" -> ".LauncherMedicalCropped"
                    else -> ".LauncherDefault"
                }
                val aliases = listOf(
                    ".LauncherDefault",
                    ".LauncherRedTransparent",
                    ".LauncherRedCropped",
                    ".LauncherMedicalCropped"
                )
                aliases.forEach { alias ->
                    packageManager.setComponentEnabledSetting(
                        ComponentName(packageName, "$packageName$alias"),
                        if (alias == target) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                }
                result.success(
                    mapOf(
                        "changed" to true,
                        "message" to "El icono de inicio se actualizó."
                    )
                )
            }
    }
}
