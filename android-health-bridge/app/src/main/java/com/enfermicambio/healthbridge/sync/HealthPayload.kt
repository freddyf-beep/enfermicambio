package com.enfermicambio.healthbridge.sync

import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate

data class DailyTotal(
    val date: LocalDate,
    val steps: Long? = null,
    val distanceMeters: Double? = null,
    val activeCalories: Double? = null,
)

data class ExerciseItem(
    val uuid: String,
    val type: String,
    val startTime: Instant,
    val endTime: Instant,
    val durationSeconds: Long,
    val distanceMeters: Double? = null,
    val activeCalories: Double? = null,
)

data class HealthPayload(
    val device: String,
    val batchId: String,
    val dailyTotals: List<DailyTotal>,
    val exercise: List<ExerciseItem>,
) {
    fun toJson(): String {
        val root = JSONObject()
            .put("source", "health_connect")
            .put("source_platform", "android")
            .put("device", device)
            .put("batch_id", batchId)
        val daily = JSONArray()
        dailyTotals.take(366).forEach { item ->
            val obj = JSONObject().put("date", item.date.toString())
            item.steps?.coerceAtLeast(0)?.let { obj.put("steps", it) }
            item.distanceMeters?.coerceAtLeast(0.0)?.let { obj.put("distance_meters", it) }
            item.activeCalories?.coerceAtLeast(0.0)?.let { obj.put("active_calories", it) }
            daily.put(obj)
        }
        val workouts = JSONArray()
        exercise.take(500).forEach { item ->
            val obj = JSONObject()
                .put("uuid", item.uuid)
                .put("type", item.type)
                .put("start_time", item.startTime.toString())
                .put("end_time", item.endTime.toString())
                .put("duration_seconds", item.durationSeconds.coerceAtLeast(1))
            item.distanceMeters?.coerceAtLeast(0.0)?.let { obj.put("distance_meters", it) }
            item.activeCalories?.coerceAtLeast(0.0)?.let { obj.put("active_calories", it) }
            workouts.put(obj)
        }
        root.put("daily_totals", daily)
        root.put("exercise", workouts)
        return root.toString()
    }
}
