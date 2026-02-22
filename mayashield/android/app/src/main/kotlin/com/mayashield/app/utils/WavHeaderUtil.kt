package com.mayashield.app.utils

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

object WavHeaderUtil {
    private const val SAMPLE_RATE = 16000
    private const val CHANNELS = 1
    private const val BITS_PER_SAMPLE = 16

    fun prependWavHeader(pcmData: ByteArray): ByteArray {
        val dataSize = pcmData.size
        val totalSize = dataSize + 44

        val buffer = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)

        // RIFF chunk
        buffer.put("RIFF".toByteArray(Charsets.US_ASCII))
        buffer.putInt(totalSize - 8)
        buffer.put("WAVE".toByteArray(Charsets.US_ASCII))

        // fmt sub-chunk
        buffer.put("fmt ".toByteArray(Charsets.US_ASCII))
        buffer.putInt(16)                                         // PCM sub-chunk size
        buffer.putShort(1)                                        // PCM format
        buffer.putShort(CHANNELS.toShort())
        buffer.putInt(SAMPLE_RATE)
        buffer.putInt(SAMPLE_RATE * CHANNELS * BITS_PER_SAMPLE / 8) // byte rate
        buffer.putShort((CHANNELS * BITS_PER_SAMPLE / 8).toShort())  // block align
        buffer.putShort(BITS_PER_SAMPLE.toShort())

        // data sub-chunk
        buffer.put("data".toByteArray(Charsets.US_ASCII))
        buffer.putInt(dataSize)

        val out = ByteArrayOutputStream(totalSize)
        out.write(buffer.array())
        out.write(pcmData)
        return out.toByteArray()
    }
}
