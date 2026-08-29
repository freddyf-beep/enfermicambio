package com.enfermicambio.healthbridge.sync

import java.security.MessageDigest
import java.time.Instant

object StableIds {
    fun exerciseId(metadataId: String?, type: Int, start: Instant, end: Instant): String {
        if (!metadataId.isNullOrBlank()) return metadataId
        val raw = "$type|${start}|${end}"
        return MessageDigest.getInstance("SHA-256")
            .digest(raw.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }
}
