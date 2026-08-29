package com.enfermicambio.healthbridge.health

import java.time.Duration
import java.time.Instant

object HealthValueConverters {
    fun meters(value: Double?): Double? = value?.takeIf { it.isFinite() }?.coerceAtLeast(0.0)
    fun kilocalories(value: Double?): Double? = value?.takeIf { it.isFinite() }?.coerceAtLeast(0.0)
    fun seconds(start: Instant, end: Instant): Long = Duration.between(start, end).seconds.coerceAtLeast(0)
}
