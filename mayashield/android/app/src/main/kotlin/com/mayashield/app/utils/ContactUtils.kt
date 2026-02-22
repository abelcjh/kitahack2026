package com.mayashield.app.utils

import android.content.Context
import android.net.Uri
import android.provider.ContactsContract

object ContactUtils {
    fun isNumberSaved(context: Context, rawNumber: String): Boolean {
        return try {
            val uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(rawNumber)
            )
            val cursor = context.contentResolver.query(
                uri,
                arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME),
                null, null, null
            )
            val found = cursor?.use { it.count > 0 } ?: false
            found
        } catch (e: Exception) {
            false
        }
    }
}
