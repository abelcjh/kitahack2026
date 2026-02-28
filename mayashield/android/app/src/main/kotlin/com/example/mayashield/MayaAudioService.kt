package com.example.mayashield

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

class MayaAudioService : Service() {
    private var isRecording = false
    private var audioRecord: AudioRecord? = null
    private var telephonyManager: TelephonyManager? = null

    companion object {
        private const val SAMPLE_RATE = 16000
        private const val CHANNELS = 1
        private const val BITS_PER_SAMPLE = 16
        private const val CHUNK_DURATION_MS = 5000L
    }

    private val pcmBuffer = ByteArrayOutputStream()
    private val pcmBufferLock = Any()

    private val phoneStateListener = object : PhoneStateListener() {
        @Deprecated("Deprecated in Java")
        override fun onCallStateChanged(state: Int, phoneNumber: String?) {
            if (state == TelephonyManager.CALL_STATE_IDLE) {
                stopSelf()
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val callerNumber = intent?.getStringExtra("incoming_number") ?: "Unknown"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("maya_audio", "Call Screening", NotificationManager.IMPORTANCE_LOW)
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }
        val notification = NotificationCompat.Builder(this, "maya_audio")
            .setContentTitle("MayaShield Active")
            .setContentText("Listening for scams...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(1, notification)
            }
        } catch (e: Exception) {
            startForeground(1, notification)
        }

        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)

        MainActivity.sendFlutterEvent(mapOf("type" to "callStarted", "callerNumber" to callerNumber))

        startRecording()

        return START_NOT_STICKY
    }

    private fun flushBuffer(): ByteArray? {
        synchronized(pcmBufferLock) {
            if (pcmBuffer.size() == 0) return null
            val pcmData = pcmBuffer.toByteArray()
            pcmBuffer.reset()
            return wrapWithWavHeader(pcmData)
        }
    }

    private fun wrapWithWavHeader(pcmData: ByteArray): ByteArray {
        val dataSize = pcmData.size
        val byteRate = SAMPLE_RATE * CHANNELS * BITS_PER_SAMPLE / 8
        val blockAlign = CHANNELS * BITS_PER_SAMPLE / 8

        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        header.put("RIFF".toByteArray(Charsets.US_ASCII))
        header.putInt(dataSize + 36)
        header.put("WAVE".toByteArray(Charsets.US_ASCII))
        header.put("fmt ".toByteArray(Charsets.US_ASCII))
        header.putInt(16)
        header.putShort(1)
        header.putShort(CHANNELS.toShort())
        header.putInt(SAMPLE_RATE)
        header.putInt(byteRate)
        header.putShort(blockAlign.toShort())
        header.putShort(BITS_PER_SAMPLE.toShort())
        header.put("data".toByteArray(Charsets.US_ASCII))
        header.putInt(dataSize)

        return header.array() + pcmData
    }

    private fun startRecording() {
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            stopSelf()
            return
        }

        val bufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        audioRecord = AudioRecord(MediaRecorder.AudioSource.MIC, SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, bufferSize)

        try {
            audioRecord?.startRecording()
            isRecording = true

            Thread {
                val buffer = ByteArray(bufferSize)
                var lastFlushTime = System.currentTimeMillis()

                while (isRecording) {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    if (read > 0) {
                        synchronized(pcmBufferLock) {
                            pcmBuffer.write(buffer, 0, read)
                        }

                        val now = System.currentTimeMillis()
                        if (now - lastFlushTime >= CHUNK_DURATION_MS) {
                            val wavChunk = flushBuffer()
                            if (wavChunk != null) {
                                MainActivity.sendFlutterEvent(mapOf("type" to "audioChunk", "data" to wavChunk))
                            }
                            lastFlushTime = now
                        }
                    } else {
                        Thread.sleep(100)
                    }
                }
            }.start()
        } catch (e: Exception) {
            stopSelf()
        }
    }

    override fun onDestroy() {
        isRecording = false
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {}

        telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)

        val finalWav = flushBuffer()
        val event = mutableMapOf<String, Any>("type" to "callEnded")
        if (finalWav != null) {
            event["data"] = finalWav
        }
        MainActivity.sendFlutterEvent(event)

        super.onDestroy()
    }
}
