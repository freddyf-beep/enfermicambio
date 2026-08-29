package com.enfermicambio.healthbridge.sync

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

class HealthSyncWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        return when (val result = HealthSyncRepository(applicationContext).syncOnce()) {
            is SyncRunResult.Success -> Result.success()
            is SyncRunResult.Failure -> if (result.retryable) Result.retry() else Result.failure()
        }
    }
}
