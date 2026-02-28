package com.example.mayashield

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mayashield/call" 
    private val AUDIO_CHANNEL = "com.mayashield/audio_stream"
    private val REQUEST_CODE_CALL_SCREENING = 1001

    // This allows the background service to send audio bytes directly to Flutter
    companion object {
        var eventSink: EventChannel.EventSink? = null
        fun sendFlutterEvent(event: Map<String, Any>) {
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(event)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestCallScreeningRole" -> {
                    requestCallScreeningRole()
                    result.success(true)
                }
                "isCallScreeningRoleActive" -> {
                    result.success(isCallScreeningRoleActive())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Connect the Flutter audio stream!
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun requestCallScreeningRole() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            if (!roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
                startActivityForResult(intent, REQUEST_CODE_CALL_SCREENING)
            }
        }
    }

    private fun isCallScreeningRoleActive(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            return roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
        }
        return false
    }
}