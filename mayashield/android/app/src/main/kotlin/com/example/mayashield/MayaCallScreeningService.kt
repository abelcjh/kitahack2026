package com.example.mayashield

import android.content.Intent
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService

class MayaCallScreeningService : CallScreeningService() {
    override fun onScreenCall(callDetails: Call.Details) {
        val callerNumber = callDetails.handle?.schemeSpecificPart ?: "Unknown"

        val response = CallResponse.Builder()
            .setDisallowCall(false)
            .setRejectCall(false)
            .setSkipCallLog(false)
            .setSkipNotification(false)
            .build()
        respondToCall(callDetails, response)

        // START THE HACKATHON AUDIO SERVICE!
        val intent = Intent(applicationContext, MayaAudioService::class.java)
        intent.putExtra("incoming_number", callerNumber)
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            // Failsafe catch to prevent telecom crash
            startService(intent) 
        }
    }
}