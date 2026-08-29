package com.enfermicambio.healthbridge.pairing

import java.time.Instant

data class PairingPayload(
    val endpoint: String,
    val token: String,
    val expiresAt: Instant? = null,
) {
    val tokenPrefix: String get() = token.take(10)
    val truncatedEndpoint: String
        get() = endpoint.replace("https://", "").let { if (it.length <= 48) it else it.take(45) + "…" }
}

sealed class PairingParseResult {
    data class Valid(val payload: PairingPayload) : PairingParseResult()
    data class Invalid(val message: String) : PairingParseResult()
}
