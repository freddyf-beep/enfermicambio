package com.enfermicambio.healthbridge.health

import android.content.Context
import android.os.Build
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.aggregate.AggregationResult
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.enfermicambio.healthbridge.sync.DailyTotal
import com.enfermicambio.healthbridge.sync.ExerciseItem
import com.enfermicambio.healthbridge.sync.StableIds
import java.time.Duration
import java.time.LocalDate
import java.time.ZoneId

class HealthConnectReader(
    private val context: Context,
    private val client: HealthConnectClient = HealthConnectClient.getOrCreate(context),
) {
    suspend fun hasBasePermissions(): Boolean {
        val granted = client.permissionController.getGrantedPermissions()
        return granted.containsAll(HealthPermissions.baseReadPermissions)
    }

    suspend fun read(days: Int): HealthSnapshot {
        val safeDays = days.coerceIn(1, 31)
        val today = LocalDate.now(SANTIAGO)
        val startDate = today.minusDays((safeDays - 1).toLong())
        val daily = mutableListOf<DailyTotal>()
        var date = startDate
        while (!date.isAfter(today)) {
            val start = date.atStartOfDay(SANTIAGO).toInstant()
            val end = date.plusDays(1).atStartOfDay(SANTIAGO).toInstant()
            val aggregation = aggregate(start, end)
            val steps = aggregation[StepsRecord.COUNT_TOTAL]?.coerceAtLeast(0)
            val distance = aggregation[DistanceRecord.DISTANCE_TOTAL]?.inMeters?.coerceAtLeast(0.0)
            val calories = aggregation[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]
                ?.inKilocalories?.coerceAtLeast(0.0)
            if ((steps ?: 0L) > 0L || (distance ?: 0.0) > 0.0 || (calories ?: 0.0) > 0.0) {
                daily += DailyTotal(date, steps, distance, calories)
            }
            date = date.plusDays(1)
        }

        val rangeStart = startDate.atStartOfDay(SANTIAGO).toInstant()
        val rangeEnd = today.plusDays(1).atStartOfDay(SANTIAGO).toInstant()
        val exerciseResponse = client.readRecords(
            ReadRecordsRequest(
                ExerciseSessionRecord::class,
                timeRangeFilter = TimeRangeFilter.between(rangeStart, rangeEnd),
                ascendingOrder = true,
                pageSize = 500,
            )
        )
        val exercise = exerciseResponse.records.take(500).mapNotNull { record ->
            val duration = Duration.between(record.startTime, record.endTime).seconds
            if (duration <= 0L) return@mapNotNull null
            ExerciseItem(
                uuid = StableIds.exerciseId(record.metadata.id, record.exerciseType, record.startTime, record.endTime),
                type = exerciseTypeName(record.exerciseType),
                startTime = record.startTime,
                endTime = record.endTime,
                durationSeconds = duration,
            )
        }
        return HealthSnapshot(daily, exercise)
    }

    private suspend fun aggregate(start: java.time.Instant, end: java.time.Instant): AggregationResult =
        client.aggregate(
            AggregateRequest(
                metrics = setOf(
                    StepsRecord.COUNT_TOTAL,
                    DistanceRecord.DISTANCE_TOTAL,
                    ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL,
                ),
                timeRangeFilter = TimeRangeFilter.between(start, end),
            )
        )

    fun deviceName(): String = "${Build.MANUFACTURER.replaceFirstChar { it.uppercase() }} ${Build.MODEL} / Android ${Build.VERSION.RELEASE}"

    companion object {
        val SANTIAGO: ZoneId = ZoneId.of("America/Santiago")

        fun exerciseTypeName(type: Int): String = when (type) {
            ExerciseSessionRecord.EXERCISE_TYPE_RUNNING -> "running"
            ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL -> "running_treadmill"
            ExerciseSessionRecord.EXERCISE_TYPE_WALKING -> "walking"
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING -> "biking"
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY -> "biking_stationary"
            ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL -> "swimming_pool"
            ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER -> "swimming_open_water"
            ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING -> "strength_training"
            ExerciseSessionRecord.EXERCISE_TYPE_WEIGHTLIFTING -> "weightlifting"
            ExerciseSessionRecord.EXERCISE_TYPE_YOGA -> "yoga"
            ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT -> "other_workout"
            else -> "health_connect_type_$type"
        }
    }
}

data class HealthSnapshot(
    val dailyTotals: List<DailyTotal>,
    val exercise: List<ExerciseItem>,
)
