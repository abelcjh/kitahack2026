package com.mayashield.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.telecom.TelecomManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.mayashield.app.overlay.ScamAlertOverlay
import com.mayashield.app.services.CallRecordingService
import com.mayashield.app.utils.ScamNumberCache

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "com.mayashield/call"
        const val EVENT_CHANNEL = "com.mayashield/audio_stream"

        // Static EventSink so CallRecordingService can push events from background
        @Volatile
        var eventSink: EventChannel.EventSink? = null
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── EventChannel: Kotlin → Flutter (audio chunks + call state) ──
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        // ── MethodChannel: Flutter ↔ Kotlin ──
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {

                "scamDetected" -> {
                    val reason = call.argument<String>("reason") ?: "Scam detected"
                    val number = call.argument<String>("number") ?: ""
                    ScamAlertOverlay.showMidCallScam(this, number, reason)
                    ScamNumberCache.addNumber(this, number)
                    result.success(null)
                }

                "updateScamCache" -> {
                    val numbers = call.argument<List<String>>("numbers") ?: emptyList()
                    ScamNumberCache.updateCache(this, numbers)
                    result.success(null)
                }

                "addScamNumber" -> {
                    val number = call.argument<String>("number") ?: ""
                    ScamNumberCache.addNumber(this, number)
                    result.success(null)
                }

                "getCachedCount" -> {
                    result.success(ScamNumberCache.getCachedCount(this))
                }

                "requestCallScreeningRole" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val telecomManager = getSystemService(TelecomManager::class.java)
                        val intent = telecomManager.createManageDefaultDialerIntent()
                        startActivity(intent)
                    }
                    result.success(null)
                }

                "requestOverlayPermission" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(Settings.canDrawOverlays(this))
                }

                "hasOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }

                "isCallScreeningRoleActive" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val tm = getSystemService(TelecomManager::class.java)
                        result.success(tm.defaultDialerPackage == packageName)
                    } else {
                        result.success(false)
                    }
                }

                "dismissOverlay" -> {
                    ScamAlertOverlay.dismiss()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Notify Flutter about current permission states when app resumes
        methodChannel.invokeMethod("onPermissionsUpdate", mapOf(
            "hasOverlay" to Settings.canDrawOverlays(this)
        ))
    }
}
