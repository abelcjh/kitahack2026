package com.mayashield.app.services

import android.telecom.Call
import android.telecom.CallScreeningService
import android.content.Intent
import com.mayashield.app.overlay.ScamAlertOverlay
import com.mayashield.app.utils.ContactUtils
import com.mayashield.app.utils.ScamNumberCache

class MayaCallScreeningService : CallScreeningService() {

    override fun onScreenCall(callDetails: Call.Details) {
        if (callDetails.callDirection != Call.Details.DIRECTION_INCOMING) {
            respondToCall(callDetails, CallResponse.Builder().build())
            return
        }

        val rawNumber = callDetails.handle?.schemeSpecificPart ?: run {
            respondToCall(callDetails, CallResponse.Builder().build())
            return
        }

        // Path 1: Number is saved in contacts -- allow, do nothing
        if (ContactUtils.isNumberSaved(this, rawNumber)) {
            respondToCall(callDetails, CallResponse.Builder().build())
            return
        }

        // Path 2: Known scam number in community cache -- auto-reject
        if (ScamNumberCache.isKnownScam(this, rawNumber)) {
            respondToCall(
                callDetails,
                CallResponse.Builder()
                    .setDisallowCall(true)
                    .setRejectCall(true)
                    .setSilenceCall(false)
                    .build()
            )
            val reportCount = 0 // overlay shows "community reported" label
            ScamAlertOverlay.showKnownScam(this, rawNumber, reportCount)
            return
        }

        // Path 3: Unknown unsaved number -- allow call but start recording
        respondToCall(callDetails, CallResponse.Builder().build())
        val serviceIntent = Intent(this, CallRecordingService::class.java).apply {
            putExtra(CallRecordingService.EXTRA_CALLER_NUMBER, rawNumber)
        }
        startForegroundService(serviceIntent)
    }
}
