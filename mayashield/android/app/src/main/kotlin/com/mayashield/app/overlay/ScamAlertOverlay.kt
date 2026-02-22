package com.mayashield.app.overlay

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telecom.TelecomManager
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import com.mayashield.app.R

object ScamAlertOverlay {

    private var overlayView: View? = null

    /** Mode 1: Called before/during ringing -- known scam number was auto-rejected. */
    fun showKnownScam(context: Context, number: String, reportCount: Int) {
        val message = "Known scam number blocked.\nReported $reportCount time(s) by the community."
        showOverlay(context, number, message, isKnownScam = true)
    }

    /** Mode 2: Called mid-call when Gemini detects a scam during the conversation. */
    fun showMidCallScam(context: Context, number: String, aiReason: String) {
        showOverlay(context, number, aiReason, isKnownScam = false)
    }

    private fun showOverlay(
        context: Context,
        number: String,
        message: String,
        isKnownScam: Boolean
    ) {
        Handler(Looper.getMainLooper()).post {
            dismiss()

            val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val inflater = LayoutInflater.from(context)
            val view = inflater.inflate(R.layout.scam_alert_overlay, null)

            val titleText = view.findViewById<TextView>(R.id.tv_title)
            val numberText = view.findViewById<TextView>(R.id.tv_number)
            val messageText = view.findViewById<TextView>(R.id.tv_message)
            val btnEndCall = view.findViewById<View>(R.id.btn_end_call)
            val btnCallPdrm = view.findViewById<View>(R.id.btn_call_pdrm)
            val btnDismiss = view.findViewById<View>(R.id.btn_dismiss)

            if (isKnownScam) {
                titleText.text = "KNOWN SCAM NUMBER — CALL BLOCKED"
                titleText.setBackgroundColor(Color.parseColor("#E65100"))
                btnEndCall.visibility = View.GONE
            } else {
                titleText.text = "⚠ SCAM DETECTED DURING CALL"
                titleText.setBackgroundColor(Color.parseColor("#B71C1C"))
                btnEndCall.visibility = View.VISIBLE
            }

            numberText.text = number
            messageText.text = message

            btnEndCall.setOnClickListener {
                attemptEndCall(context)
                dismiss()
            }

            btnCallPdrm.setOnClickListener {
                val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:0326101559")).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(dialIntent)
                dismiss()
            }

            btnDismiss.setOnClickListener { dismiss() }

            val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                layoutFlag,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP
            }

            windowManager.addView(view, params)
            overlayView = view

            // Auto-dismiss known scam overlay after 10 seconds
            if (isKnownScam) {
                Handler(Looper.getMainLooper()).postDelayed({ dismiss() }, 10_000L)
            }
        }
    }

    fun dismiss() {
        overlayView?.let { view ->
            try {
                val wm = view.context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                wm.removeViewImmediate(view)
            } catch (_: Exception) {}
            overlayView = null
        }
    }

    @Suppress("DEPRECATION")
    private fun attemptEndCall(context: Context) {
        try {
            val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            telecomManager.endCall()
        } catch (_: Exception) {}
    }
}
