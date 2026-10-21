package com.example.intellispace

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SMS_CHANNEL = "com.example.intellispace/sms"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendDirectSms" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    if (phone.isEmpty() || message.isEmpty()) {
                        result.error("INVALID_ARGS", "Phone and message must not be empty", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            applicationContext.getSystemService(SmsManager::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            SmsManager.getDefault()
                        }

                        val parts = smsManager.divideMessage(message)
                        smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SMS_SEND_FAILED", e.localizedMessage, null)
                    }
                }
                "openSmsApp" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    try {
                        val uri = Uri.parse("smsto:$phone")
                        val intent = Intent(Intent.ACTION_SENDTO, uri).apply {
                            putExtra("sms_body", message)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_FAILED", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
