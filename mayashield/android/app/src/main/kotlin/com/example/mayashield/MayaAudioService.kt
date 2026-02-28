package com.example.mayashield

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class MayaAudioService : Service() {
    private var isRecording = false
    private var audioRecord: AudioRecord? = null
    private var telephonyManager: TelephonyManager? = null

    // This listens for the moment you hang up the phone
    private val phoneStateListener = object : PhoneStateListener() {
        override fun onCallStateChanged(state: Int, phoneNumber: String?) {
            if (state == TelephonyManager.CALL_STATE_IDLE) {
                stopSelf() // Kills the recording when the call ends
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val callerNumber = intent?.getStringExtra("incoming_number") ?: "Unknown"

        // 1. Create the persistent background notification (Required by Android)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("maya_audio", "Call Screening", NotificationManager.IMPORTANCE_LOW)
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }
        val notification = NotificationCompat.Builder(this, "maya_audio")
            .setContentTitle("MayaShield Active")
            .setContentText("Listening for scams...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .build()
        startForeground(1, notification)

        // 2. Listen for call end
        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)

        // 3. Tell Flutter the call started
        MainActivity.sendFlutterEvent(mapOf("type" to "callStarted", "callerNumber" to callerNumber))

        // 4. Start grabbing microphone audio
        startRecording()

        return START_NOT_STICKY
    }

    private fun startRecording() {
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            stopSelf()
            return
        }

        val sampleRate = 16000
        val bufferSize = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        audioRecord = AudioRecord(MediaRecorder.AudioSource.MIC, sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, bufferSize)

        audioRecord?.startRecording()
        isRecording = true

        Thread {
            val buffer = ByteArray(bufferSize)
            while (isRecording) {
                val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                if (read > 0) {
                    val chunk = buffer.copyOf(read)
                    MainActivity.sendFlutterEvent(mapOf("type" to "audioChunk", "data" to chunk))
                }
            }
        }.start()
    }

    override fun onDestroy() {
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)
        MainActivity.sendFlutterEvent(mapOf("type" to "callEnded"))
        super.onDestroy()
    }
}