package com.enfermicambio.healthbridge.pairing

import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

class PairingParserTest {
    private val now = Instant.parse("2026-08-29T20:00:00Z")
    private val parser = PairingParser(Clock.fixed(now, ZoneOffset.UTC))
    private val token = "a".repeat(64)

    @Test fun parsesJsonQr() {
        val raw = """{"app":"enfermicambio","v":1,"platform":"android","endpoint":"${PairingParser.PRODUCTION_ENDPOINT}","token":"$token","expires_at":"2026-08-29T23:59:59Z"}"""
        val result = parser.parse(raw) as PairingParseResult.Valid
        assertEquals(PairingParser.PRODUCTION_ENDPOINT, result.payload.endpoint)
        assertEquals(token, result.payload.token)
    }

    @Test fun parsesDeepLink() {
        fun enc(v: String) = URLEncoder.encode(v, StandardCharsets.UTF_8.name())
        val raw = "enfermicambio://health/pair?v=1&platform=android&endpoint=${enc(PairingParser.PRODUCTION_ENDPOINT)}&token=$token&expires_at=${enc("2026-08-29T23:59:59Z")}" 
        assertTrue(parser.parse(raw) is PairingParseResult.Valid)
    }

    @Test fun rejectsWrongAppVersionPlatformHostAndToken() {
        val cases = listOf(
            """{"app":"otra","v":1,"platform":"android","endpoint":"${PairingParser.PRODUCTION_ENDPOINT}","token":"$token"}""",
            """{"app":"enfermicambio","v":2,"platform":"android","endpoint":"${PairingParser.PRODUCTION_ENDPOINT}","token":"$token"}""",
            """{"app":"enfermicambio","v":1,"platform":"ios","endpoint":"${PairingParser.PRODUCTION_ENDPOINT}","token":"$token"}""",
            """{"app":"enfermicambio","v":1,"platform":"android","endpoint":"https://example.com/functions/v1/ingest_health","token":"$token"}""",
            """{"app":"enfermicambio","v":1,"platform":"android","endpoint":"${PairingParser.PRODUCTION_ENDPOINT}","token":"abc"}""",
        )
        cases.forEach { assertTrue(parser.parse(it) is PairingParseResult.Invalid) }
    }

    @Test fun rejectsExpiredCodeWithoutNetwork() {
        val raw = """{"app":"enfermicambio","v":1,"platform":"android","endpoint":"${PairingParser.PRODUCTION_ENDPOINT}","token":"$token","expires_at":"2026-08-29T19:59:59Z"}"""
        val result = parser.parse(raw) as PairingParseResult.Invalid
        assertTrue(result.message.contains("expiró"))
    }

    @Test fun errorsNeverExposeToken() {
        val bad = token + "ff"
        val raw = """{"app":"enfermicambio","v":1,"platform":"ios","endpoint":"${PairingParser.PRODUCTION_ENDPOINT}","token":"$bad"}"""
        val result = parser.parse(raw) as PairingParseResult.Invalid
        assertFalse(result.message.contains(bad))
    }
}
