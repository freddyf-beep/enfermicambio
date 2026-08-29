package com.enfermicambio.healthbridge.network

import com.enfermicambio.healthbridge.pairing.PairingPayload
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.CacheControl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

sealed class IngestResult {
    data class Success(
        val httpCode: Int,
        val validated: Boolean = false,
        val accepted: Int = 0,
        val deduped: Int = 0,
        val warning: String? = null,
    ) : IngestResult()
    data class Failure(
        val httpCode: Int?,
        val userMessage: String,
        val retryable: Boolean,
        val requiresRepairing: Boolean = false,
    ) : IngestResult()
}

class IngestHealthClient(
    private val http: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(25, TimeUnit.SECONDS)
        .readTimeout(25, TimeUnit.SECONDS)
        .writeTimeout(25, TimeUnit.SECONDS)
        .callTimeout(30, TimeUnit.SECONDS)
        .build(),
) {
    suspend fun validate(pairing: PairingPayload): IngestResult = post(
        pairing,
        JSONObject()
            .put("source_platform", "android")
            .put("validate_only", true)
            .toString(),
        validateOnly = true,
    )

    suspend fun ingest(pairing: PairingPayload, payloadJson: String): IngestResult =
        post(pairing, payloadJson, validateOnly = false)

    private suspend fun post(pairing: PairingPayload, json: String, validateOnly: Boolean): IngestResult =
        withContext(Dispatchers.IO) {
            val request = Request.Builder()
                .url(pairing.endpoint)
                .post(json.toRequestBody(JSON))
                .header("Authorization", "Bearer ${pairing.token}")
                .header("Content-Type", "application/json")
                .cacheControl(CacheControl.FORCE_NETWORK)
                .build()
            try {
                http.newCall(request).execute().use { response ->
                    val body = response.body?.string().orEmpty()
                    if (response.code == 200) {
                        val obj = runCatching { JSONObject(body) }.getOrNull()
                        val validated = obj?.optBoolean("validated", false) ?: false
                        if (validateOnly && !validated) {
                            return@withContext IngestResult.Failure(
                                200,
                                "El servidor respondió, pero no confirmó la validación.",
                                retryable = false,
                            )
                        }
                        return@withContext IngestResult.Success(
                            httpCode = 200,
                            validated = validated,
                            accepted = obj?.optInt("accepted", 0) ?: 0,
                            deduped = obj?.optInt("deduped", 0) ?: 0,
                            warning = obj?.optString("warning")?.takeIf { it.isNotBlank() }?.take(220),
                        )
                    }
                    classify(response.code)
                }
            } catch (_: IOException) {
                IngestResult.Failure(
                    null,
                    "Sin conexión. Los datos quedarán pendientes para reintento.",
                    retryable = true,
                )
            }
        }

    companion object {
        private val JSON = "application/json; charset=utf-8".toMediaType()

        fun classify(code: Int): IngestResult.Failure = when (code) {
            400 -> IngestResult.Failure(code, "Los datos no tienen un formato válido; intenta sincronizar otra vez.", false)
            401 -> IngestResult.Failure(code, "Este código ya no es válido. Genera un código nuevo en EnfermiCambio.", false, true)
            403 -> IngestResult.Failure(code, "Este código no corresponde a Android.", false, true)
            413 -> IngestResult.Failure(code, "Reduce el período de sincronización e inténtalo nuevamente.", false)
            503 -> IngestResult.Failure(code, "Servidor ocupado. Reintentaremos automáticamente.", true)
            in 500..599 -> IngestResult.Failure(code, "Servidor ocupado. Reintentaremos automáticamente.", true)
            else -> IngestResult.Failure(code, "No se pudo completar la sincronización (HTTP $code).", false)
        }
    }
}
