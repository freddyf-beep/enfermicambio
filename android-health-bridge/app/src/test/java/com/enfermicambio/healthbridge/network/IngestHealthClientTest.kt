package com.enfermicambio.healthbridge.network

import com.enfermicambio.healthbridge.pairing.PairingPayload
import com.enfermicambio.healthbridge.sync.DailyTotal
import com.enfermicambio.healthbridge.sync.HealthPayload
import kotlinx.coroutines.runBlocking
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.SocketPolicy
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.util.concurrent.TimeUnit

class IngestHealthClientTest {
    @Test fun postUsesBearerAndHealthConnectEnvelopeOffCallerThread() = runBlocking {
        val server = MockWebServer()
        server.enqueue(MockResponse().setResponseCode(200).setBody("{\"ok\":true}"))
        server.start()
        try {
            val caller = Thread.currentThread().name
            var networkThread = ""
            val http = OkHttpClient.Builder().addInterceptor { chain ->
                networkThread = Thread.currentThread().name
                chain.proceed(chain.request())
            }.build()
            val client = IngestHealthClient(http)
            val token = "c".repeat(64)
            val pairing = PairingPayload(server.url("/functions/v1/ingest_health").toString(), token)
            val body = HealthPayload("test", "batch-1", listOf(DailyTotal(LocalDate.parse("2026-08-29"), 1)), emptyList()).toJson()
            client.ingest(pairing, body)
            val req = server.takeRequest(2, TimeUnit.SECONDS)!!
            assertEquals("POST", req.method)
            assertEquals("Bearer $token", req.getHeader("Authorization"))
            assertEquals("health_connect", JSONObject(req.body.readUtf8()).getString("source"))
            assertNotEquals(caller, networkThread)
        } finally { server.shutdown() }
    }

    @Test fun validate200UpdatesAsValidated() = runBlocking {
        val server = MockWebServer()
        server.enqueue(MockResponse().setResponseCode(200).setBody("{\"ok\":true,\"validated\":true,\"platform\":\"android\",\"accepted\":0,\"deduped\":0}"))
        server.start()
        try {
            val client = IngestHealthClient()
            val result = client.validate(PairingPayload(server.url("/").toString(), "d".repeat(64)))
            assertTrue(result is IngestResult.Success && result.validated)
        } finally { server.shutdown() }
    }

    @Test fun real401RequiresRepairingAndDoesNotRetry() = runBlocking {
        val server = MockWebServer()
        server.enqueue(MockResponse().setResponseCode(401).setBody("{\"error\":\"invalid token\"}"))
        server.start()
        try {
            val result = IngestHealthClient().validate(PairingPayload(server.url("/").toString(), "e".repeat(64)))
            assertTrue(result is IngestResult.Failure)
            result as IngestResult.Failure
            assertEquals(401, result.httpCode)
            assertTrue(result.requiresRepairing)
            assertFalse(result.retryable)
            assertFalse(result.userMessage.contains("e".repeat(64)))
        } finally { server.shutdown() }
    }

    @Test fun timeoutLeavesSyncRetryable() = runBlocking {
        val server = MockWebServer()
        server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
        server.start()
        try {
            val http = OkHttpClient.Builder()
                .connectTimeout(200, TimeUnit.MILLISECONDS)
                .readTimeout(200, TimeUnit.MILLISECONDS)
                .writeTimeout(200, TimeUnit.MILLISECONDS)
                .callTimeout(250, TimeUnit.MILLISECONDS)
                .build()
            val result = IngestHealthClient(http).validate(PairingPayload(server.url("/").toString(), "f".repeat(64)))
            assertTrue(result is IngestResult.Failure)
            result as IngestResult.Failure
            assertTrue(result.retryable)
            assertEquals(null, result.httpCode)
            assertTrue(result.userMessage.contains("Sin conexión"))
        } finally { server.shutdown() }
    }

    @Test fun httpClassificationMatchesContract() {
        assertFalse(IngestHealthClient.classify(400).retryable)
        assertTrue(IngestHealthClient.classify(401).requiresRepairing)
        assertTrue(IngestHealthClient.classify(403).requiresRepairing)
        assertFalse(IngestHealthClient.classify(413).retryable)
        assertTrue(IngestHealthClient.classify(503).retryable)
        assertFalse(IngestHealthClient.classify(401).retryable)
    }
}
