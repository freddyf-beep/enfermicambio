package com.enfermicambio.healthbridge.storage

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.enfermicambio.healthbridge.pairing.PairingParser
import com.enfermicambio.healthbridge.pairing.PairingPayload
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class SecureSettingsStoreTest {
    private lateinit var context: Context
    private lateinit var prefs: android.content.SharedPreferences

    @Before fun setup() {
        context = ApplicationProvider.getApplicationContext()
        prefs = context.getSharedPreferences("secure-test", Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
    }

    @Test fun encryptedPersistenceAndDisconnectCleanup() {
        val cipher = FakeCipher()
        val store = SecureSettingsStore(context, cipher, prefs)
        val token = "b".repeat(64)
        store.savePairing(PairingPayload(PairingParser.PRODUCTION_ENDPOINT, token))
        assertFalse(store.encryptedTokenForTestOnly().orEmpty().contains(token))
        assertEquals(token, store.loadPairing()?.token)
        store.disconnect()
        assertNull(store.loadPairing())
        assertEquals(true, cipher.cleared)
    }

    private class FakeCipher : TokenCipher {
        var cleared = false
        override fun encrypt(plainText: String) = "cipher:" + plainText.reversed()
        override fun decrypt(cipherText: String) = cipherText.removePrefix("cipher:").reversed()
        override fun clearKey() { cleared = true }
    }
}
