package com.example.linkride

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.SmsManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.linkride/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")

                    if (phoneNumber != null && message != null) {
                        try {
                            sendSmsViaManager(phoneNumber, message)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("SmsError", "Failed to send SMS: ${e.message}")
                            result.error("SMS_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Phone number or message is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun sendSmsViaManager(phoneNumber: String, message: String) {
        try {
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                this.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            // Split message if too long (SMS limit is 160 characters)
            val parts = smsManager.divideMessage(message)
            val sentIntents = ArrayList<PendingIntent>()
            val deliveredIntents = ArrayList<PendingIntent>()

            for (i in parts.indices) {
                val sentIntent = PendingIntent.getBroadcast(
                    this,
                    i,
                    Intent("SMS_SENT").putExtra("partIndex", i),
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    else
                        PendingIntent.FLAG_UPDATE_CURRENT
                )

                val deliveryIntent = PendingIntent.getBroadcast(
                    this,
                    i,
                    Intent("SMS_DELIVERED").putExtra("partIndex", i),
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    else
                        PendingIntent.FLAG_UPDATE_CURRENT
                )

                sentIntents.add(sentIntent)
                deliveredIntents.add(deliveryIntent)
            }

            // Register broadcast receivers
            registerBroadcastReceivers()

            // Send SMS parts
            smsManager.sendMultipartTextMessage(
                phoneNumber,
                null,
                parts,
                sentIntents,
                deliveredIntents
            )

            Log.d("SmsManager", "SMS sent to $phoneNumber with ${parts.size} part(s)")
        } catch (e: Exception) {
            Log.e("SmsError", "SMS Manager Error: ${e.message}")
            throw e
        }
    }

    private fun registerBroadcastReceivers() {
        val filter = IntentFilter().apply {
            addAction("SMS_SENT")
            addAction("SMS_DELIVERED")
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    "SMS_SENT" -> {
                        val resultCode = resultCode
                        Log.d("SmsBroadcast", "SMS sent with result: $resultCode")
                    }
                    "SMS_DELIVERED" -> {
                        val resultCode = resultCode
                        Log.d("SmsBroadcast", "SMS delivered with result: $resultCode")
                    }
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
    }
}
