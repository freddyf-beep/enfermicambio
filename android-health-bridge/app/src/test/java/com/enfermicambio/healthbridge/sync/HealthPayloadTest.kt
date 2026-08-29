package com.enfermicambio.healthbridge.sync

import com.enfermicambio.healthbridge.health.HealthConnectReader
import com.enfermicambio.healthbridge.health.HealthValueConverters
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.ZonedDateTime

class HealthPayloadTest {
    @Test fun serializesOneAndManyDaysAndZeroData() {
        val one = HealthPayload("Pixel", "b1", listOf(DailyTotal(LocalDate.parse("2026-08-29"), 100, 12.5, 3.2)), emptyList())
        val obj = JSONObject(one.toJson())
        assertEquals("health_connect", obj.getString("source"))
        assertEquals("android", obj.getString("source_platform"))
        assertEquals("2026-08-29", obj.getJSONArray("daily_totals").getJSONObject(0).getString("date"))
        val many = HealthPayload("Pixel", "b2", listOf(DailyTotal(LocalDate.parse("2026-08-28"), 1), DailyTotal(LocalDate.parse("2026-08-29"), 2)), emptyList())
        assertEquals(2, JSONObject(many.toJson()).getJSONArray("daily_totals").length())
        assertEquals(0, JSONObject(HealthPayload("Pixel", "b3", emptyList(), emptyList()).toJson()).getJSONArray("daily_totals").length())
    }

    @Test fun santiagoDateIsExactAcrossInstantConversion() {
        val date = ZonedDateTime.ofInstant(Instant.parse("2026-08-29T03:30:00Z"), HealthConnectReader.SANTIAGO).toLocalDate()
        assertEquals("2026-08-28", date.toString())
    }

    @Test fun convertsMetersKcalAndSecondsWithoutNegatives() {
        assertEquals(123.4, HealthValueConverters.meters(123.4)!!, 0.0)
        assertEquals(45.6, HealthValueConverters.kilocalories(45.6)!!, 0.0)
        assertEquals(0.0, HealthValueConverters.meters(-4.0)!!, 0.0)
        assertEquals(60, HealthValueConverters.seconds(Instant.parse("2026-08-29T10:00:00Z"), Instant.parse("2026-08-29T10:01:00Z")))
    }

    @Test fun fallbackWorkoutIdIsStable() {
        val start = Instant.parse("2026-08-29T10:00:00Z")
        val end = Instant.parse("2026-08-29T10:30:00Z")
        val a = StableIds.exerciseId(null, 56, start, end)
        val b = StableIds.exerciseId(null, 56, start, end)
        val c = StableIds.exerciseId(null, 79, start, end)
        assertEquals(a, b)
        assertNotEquals(a, c)
        assertEquals(64, a.length)
    }
}
