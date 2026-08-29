package com.enfermicambio.healthbridge.pairing

import org.json.JSONObject
import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.time.Clock
import java.time.Instant

class PairingParser(
    private val clock: Clock = Clock.systemUTC(),
    private val allowDebugEndpoint: Boolean = false,
) {
    fun parse(input: String): PairingParseResult {
        val raw = input.trim()
        return try {
            when {
                raw.startsWith("enfermicambio://", ignoreCase = true) -> parseDeepLink(raw)
                raw.startsWith("{") -> parseJson(raw)
                raw.contains('\n') -> parseEndpointAndToken(raw)
                TOKEN.matches(raw) -> validate(PRODUCTION_ENDPOINT, raw, null)
                else -> PairingParseResult.Invalid("El código de emparejamiento no tiene un formato válido.")
            }
        } catch (_: Exception) {
            PairingParseResult.Invalid("El código de emparejamiento no tiene un formato válido.")
        }
    }

    private fun parseJson(raw: String): PairingParseResult {
        val json = JSONObject(raw)
        if (json.optString("app") != "enfermicambio") return invalid("app")
        if (json.optInt("v", -1) != 1) return invalid("versión")
        if (json.optString("platform") != "android") return invalid("plataforma")
        val expires = json.optString("expires_at").takeIf { it.isNotBlank() }?.let(Instant::parse)
        return validate(json.optString("endpoint"), json.optString("token"), expires)
    }

    private fun parseDeepLink(raw: String): PairingParseResult {
        val uri = URI(raw)
        if (!uri.scheme.equals("enfermicambio", true) || uri.host != "health" || uri.path != "/pair") {
            return PairingParseResult.Invalid("El enlace de emparejamiento no es válido.")
        }
        val query = queryMap(uri.rawQuery.orEmpty())
        if (query["v"] != "1") return invalid("versión")
        if (query["platform"] != "android") return invalid("plataforma")
        val expires = query["expires_at"]?.takeIf { it.isNotBlank() }?.let(Instant::parse)
        return validate(query["endpoint"].orEmpty(), query["token"].orEmpty(), expires)
    }

    private fun parseEndpointAndToken(raw: String): PairingParseResult {
        val lines = raw.lines().map(String::trim).filter(String::isNotBlank)
        if (lines.size < 2) return PairingParseResult.Invalid("Faltan el endpoint o el token.")
        return validate(lines[0], lines[1], null)
    }

    private fun validate(endpoint: String, token: String, expiresAt: Instant?): PairingParseResult {
        if (!TOKEN.matches(token)) return PairingParseResult.Invalid("El token del código no tiene un formato válido.")
        if (expiresAt != null && !expiresAt.isAfter(clock.instant())) {
            return PairingParseResult.Invalid("Este código expiró. Genera un código nuevo en EnfermiCambio.")
        }
        val uri = runCatching { URI(endpoint) }.getOrNull()
            ?: return PairingParseResult.Invalid("El endpoint no tiene un formato válido.")
        if (uri.scheme != "https") return PairingParseResult.Invalid("El endpoint debe usar HTTPS.")
        val production = uri.host == PRODUCTION_HOST && uri.path == PRODUCTION_PATH && uri.port == -1
        if (!production && !allowDebugEndpoint) {
            return PairingParseResult.Invalid("El endpoint no corresponde al servidor permitido de EnfermiCambio.")
        }
        return PairingParseResult.Valid(PairingPayload(endpoint, token.lowercase(), expiresAt))
    }

    private fun invalid(field: String) = PairingParseResult.Invalid("El código contiene una $field no válida.")

    private fun queryMap(rawQuery: String): Map<String, String> = rawQuery
        .split('&')
        .filter { it.isNotBlank() }
        .associate { part ->
            val pair = part.split('=', limit = 2)
            decode(pair[0]) to decode(pair.getOrElse(1) { "" })
        }

    private fun decode(value: String): String = URLDecoder.decode(value, StandardCharsets.UTF_8.name())

    companion object {
        const val PRODUCTION_HOST = "bweynxdzovnbcjwgddar.supabase.co"
        const val PRODUCTION_PATH = "/functions/v1/ingest_health"
        const val PRODUCTION_ENDPOINT = "https://$PRODUCTION_HOST$PRODUCTION_PATH"
        private val TOKEN = Regex("^[0-9a-fA-F]{64,256}$")
    }
}
