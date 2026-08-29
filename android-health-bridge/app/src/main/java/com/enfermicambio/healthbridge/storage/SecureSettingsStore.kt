package com.enfermicambio.healthbridge.storage

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.enfermicambio.healthbridge.pairing.PairingPayload
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

interface TokenCipher {
    fun encrypt(plainText: String): String
    fun decrypt(cipherText: String): String
    fun clearKey()
}

class AndroidKeystoreTokenCipher(
    private val alias: String = "enfermicambio_healthbridge_token_v1",
) : TokenCipher {
    override fun encrypt(plainText: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val encrypted = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))
        val packed = ByteArray(cipher.iv.size + encrypted.size)
        System.arraycopy(cipher.iv, 0, packed, 0, cipher.iv.size)
        System.arraycopy(encrypted, 0, packed, cipher.iv.size, encrypted.size)
        return Base64.encodeToString(packed, Base64.NO_WRAP)
    }

    override fun decrypt(cipherText: String): String {
        val packed = Base64.decode(cipherText, Base64.NO_WRAP)
        require(packed.size > IV_BYTES)
        val iv = packed.copyOfRange(0, IV_BYTES)
        val encrypted = packed.copyOfRange(IV_BYTES, packed.size)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, getExistingKey(), GCMParameterSpec(128, iv))
        return cipher.doFinal(encrypted).toString(Charsets.UTF_8)
    }

    override fun clearKey() {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        if (keyStore.containsAlias(alias)) keyStore.deleteEntry(alias)
    }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (keyStore.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE).run {
            init(
                KeyGenParameterSpec.Builder(
                    alias,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build()
            )
            generateKey()
        }
    }

    private fun getExistingKey(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        return keyStore.getKey(alias, null) as? SecretKey
            ?: error("No existe la clave local para descifrar el token")
    }

    companion object {
        private const val KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val IV_BYTES = 12
    }
}

data class SyncStatus(
    val lastSyncEpochMillis: Long = 0,
    val lastHttpCode: Int = 0,
    val lastDaysSent: Int = 0,
    val lastExerciseSent: Int = 0,
    val lastMessage: String = "",
)

class SecureSettingsStore(
    context: Context,
    private val tokenCipher: TokenCipher = AndroidKeystoreTokenCipher(),
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE),
) {
    fun savePairing(payload: PairingPayload) {
        val encrypted = tokenCipher.encrypt(payload.token)
        prefs.edit()
            .putString(KEY_ENDPOINT, payload.endpoint)
            .putString(KEY_TOKEN_CIPHER, encrypted)
            .apply()
    }

    fun loadPairing(): PairingPayload? {
        val endpoint = prefs.getString(KEY_ENDPOINT, null) ?: return null
        val encrypted = prefs.getString(KEY_TOKEN_CIPHER, null) ?: return null
        val token = runCatching { tokenCipher.decrypt(encrypted) }.getOrNull() ?: return null
        return PairingPayload(endpoint = endpoint, token = token)
    }

    fun disconnect() {
        prefs.edit().clear().apply()
        runCatching { tokenCipher.clearKey() }
    }

    var syncDays: Int
        get() = prefs.getInt(KEY_DAYS, 7)
        set(value) { prefs.edit().putInt(KEY_DAYS, value.coerceIn(1, 31)).apply() }

    var intervalMinutes: Long
        get() = prefs.getLong(KEY_INTERVAL, 60L)
        set(value) { prefs.edit().putLong(KEY_INTERVAL, value.coerceAtLeast(15L)).apply() }

    var automaticSync: Boolean
        get() = prefs.getBoolean(KEY_AUTO, false)
        set(value) { prefs.edit().putBoolean(KEY_AUTO, value).apply() }

    fun saveStatus(status: SyncStatus) {
        prefs.edit()
            .putLong(KEY_LAST_SYNC, status.lastSyncEpochMillis)
            .putInt(KEY_LAST_HTTP, status.lastHttpCode)
            .putInt(KEY_LAST_DAYS, status.lastDaysSent)
            .putInt(KEY_LAST_EXERCISE, status.lastExerciseSent)
            .putString(KEY_LAST_MESSAGE, status.lastMessage.take(220))
            .apply()
    }

    fun loadStatus() = SyncStatus(
        lastSyncEpochMillis = prefs.getLong(KEY_LAST_SYNC, 0),
        lastHttpCode = prefs.getInt(KEY_LAST_HTTP, 0),
        lastDaysSent = prefs.getInt(KEY_LAST_DAYS, 0),
        lastExerciseSent = prefs.getInt(KEY_LAST_EXERCISE, 0),
        lastMessage = prefs.getString(KEY_LAST_MESSAGE, "").orEmpty(),
    )

    fun getOrCreatePendingBatchId(factory: () -> String): String {
        prefs.getString(KEY_PENDING_BATCH, null)?.let { return it }
        return factory().also { prefs.edit().putString(KEY_PENDING_BATCH, it).apply() }
    }

    fun clearPendingBatch() {
        prefs.edit().remove(KEY_PENDING_BATCH).apply()
    }

    fun encryptedTokenForTestOnly(): String? = prefs.getString(KEY_TOKEN_CIPHER, null)

    companion object {
        private const val PREFS = "enfermicambio_healthbridge_settings"
        private const val KEY_ENDPOINT = "endpoint"
        private const val KEY_TOKEN_CIPHER = "token_cipher"
        private const val KEY_DAYS = "days"
        private const val KEY_INTERVAL = "interval"
        private const val KEY_AUTO = "auto"
        private const val KEY_LAST_SYNC = "last_sync"
        private const val KEY_LAST_HTTP = "last_http"
        private const val KEY_LAST_DAYS = "last_days"
        private const val KEY_LAST_EXERCISE = "last_exercise"
        private const val KEY_LAST_MESSAGE = "last_message"
        private const val KEY_PENDING_BATCH = "pending_batch"
    }
}
