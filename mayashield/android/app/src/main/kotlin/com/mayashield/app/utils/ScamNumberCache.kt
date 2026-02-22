package com.mayashield.app.utils

import android.content.Context
import android.content.SharedPreferences
import java.security.MessageDigest

/**
 * Local cache of known scam phone numbers synced from Firestore.
 * Uses SharedPreferences to store SHA-256 hashes for instant O(1) lookup.
 * The CallScreeningService uses this to avoid network calls during screening.
 */
object ScamNumberCache {

    private const val PREFS_NAME = "maya_scam_cache"
    private const val KEY_HASHES = "scam_hashes"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun isKnownScam(context: Context, phoneNumber: String): Boolean {
        val hash = hashNumber(normalizeNumber(phoneNumber))
        val hashes = prefs(context).getStringSet(KEY_HASHES, emptySet()) ?: emptySet()
        return hashes.contains(hash)
    }

    /** Called from Flutter via MethodChannel to replace the full cache. */
    fun updateCache(context: Context, phoneNumbers: List<String>) {
        val hashes = phoneNumbers.map { hashNumber(normalizeNumber(it)) }.toSet()
        prefs(context).edit().putStringSet(KEY_HASHES, hashes).apply()
    }

    /** Called immediately when a new scam is detected mid-call. */
    fun addNumber(context: Context, phoneNumber: String) {
        val prefs = prefs(context)
        val current = prefs.getStringSet(KEY_HASHES, emptySet())?.toMutableSet() ?: mutableSetOf()
        current.add(hashNumber(normalizeNumber(phoneNumber)))
        prefs.edit().putStringSet(KEY_HASHES, current).apply()
    }

    fun getCachedCount(context: Context): Int {
        return prefs(context).getStringSet(KEY_HASHES, emptySet())?.size ?: 0
    }

    private fun normalizeNumber(number: String): String =
        number.replace(Regex("[^+0-9]"), "")

    private fun hashNumber(number: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val bytes = digest.digest(number.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }
}
