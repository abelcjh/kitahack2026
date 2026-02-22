package com.mayashield.app.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import androidx.core.app.NotificationCompat
import com.mayashield.app.MainActivity
import com.mayashield.app.utils.WavHeaderUtil
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import java.util.Timer
import java.util.TimerTask

class CallRecordingService : Service() {

    companion object {
        const val EXTRA_CALLER_NUMBER = "caller_number"
        const val CHANNEL_ID = "maya_recording_channel"
        const val NOTIFICATION_ID = 1001
        const val CHUNK_INTERVAL_MS = 15_000L
        const val SAMPLE_RATE = 16000
    }

    private var audioRecord: AudioRecord? = null
    private val accumulatedBuffer = ByteArrayOutputStream()
    private var recordingJob: Job? = null
    private var chunkTimer: Timer? = null
    private var isRecording = false
    private var callerNumber = ""

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        callerNumber = intent?.getStringExtra(EXTRA_CALLER_NUMBER) ?: ""

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())

        registerCallStateListener()
        startRecording()

        return START_NOT_STICKY
    }

    private fun startRecording() {
        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufferSize = maxOf(minBuffer, 8192)

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )

        if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
            stopSelf()
            return
        }

        isRecording = true
        audioRecord?.startRecording()

        recordingJob = serviceScope.launch {
            val readBuffer = ByteArray(bufferSize)
            while (isActive && isRecording) {
                val bytesRead = audioRecord?.read(readBuffer, 0, readBuffer.size) ?: break
                if (bytesRead > 0) {
                    synchronized(accumulatedBuffer) {
                        accumulatedBuffer.write(readBuffer, 0, bytesRead)
                    }
                }
            }
        }

        chunkTimer = Timer()
        chunkTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                sendChunkToFlutter(isFinal = false)
            }
        }, CHUNK_INTERVAL_MS, CHUNK_INTERVAL_MS)
    }

    private fun sendChunkToFlutter(isFinal: Boolean) {
        val pcmBytes: ByteArray
        synchronized(accumulatedBuffer) {
            if (accumulatedBuffer.size() == 0) return
            pcmBytes = accumulatedBuffer.toByteArray()
            if (!isFinal) accumulatedBuffer.reset()
        }

        val wavBytes = WavHeaderUtil.prependWavHeader(pcmBytes)

        val eventData = mapOf(
            "type" to if (isFinal) "callEnded" else "audioChunk",
            "data" to wavBytes,
            "callerNumber" to callerNumber
        )
        MainActivity.eventSink?.success(eventData)
    }

    /** Called from MainActivity MethodChannel when Flutter detects a scam. */
    fun onScamDetected(reason: String) {
        com.mayashield.app.overlay.ScamAlertOverlay.showMidCallScam(this, callerNumber, reason)
    }

    private fun stopRecording() {
        isRecording = false
        chunkTimer?.cancel()
        chunkTimer = null
        recordingJob?.cancel()
        sendChunkToFlutter(isFinal = true)
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun registerCallStateListener() {
        val telephony = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephony.registerTelephonyCallback(
                mainExecutor,
                object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                    override fun onCallStateChanged(state: Int) {
                        if (state == TelephonyManager.CALL_STATE_IDLE) stopRecording()
                    }
                }
            )
        } else {
            @Suppress("DEPRECATION")
            telephony.listen(object : PhoneStateListener() {
                @Deprecated("Deprecated in Java")
                override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                    if (state == TelephonyManager.CALL_STATE_IDLE) stopRecording()
                }
            }, PhoneStateListener.LISTEN_CALL_STATE)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "MayaShield Call Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "MayaShield is monitoring this call for scams"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("MayaShield Active")
            .setContentText("Monitoring call from $callerNumber for scam activity")
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode_off)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        serviceScope.cancel()
        super.onDestroy()
    }
}
