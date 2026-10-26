package com.wani.card_expense

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "card_expense/native")
        channel = ch
        CardSms.onNew = { ch.invokeMethod("onNewSms", null) }

        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "setCardDigits" -> {
                    CardSms.setDigits(this, call.argument<String>("digits"))
                    result.success(null)
                }
                "drainInbox" -> result.success(CardSms.drain(this))
                "readSmsInbox" -> {
                    val days = call.argument<Int>("days") ?: 120
                    thread {
                        try {
                            val list = CardSms.readInbox(this, days)
                            runOnUiThread { result.success(list) }
                        } catch (e: SecurityException) {
                            runOnUiThread { result.error("NO_PERMISSION", e.message, null) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("FAILED", e.message, null) }
                        }
                    }
                }
                "permissionStatus" -> result.success(
                    mapOf(
                        "sms" to (granted(Manifest.permission.RECEIVE_SMS) && granted(Manifest.permission.READ_SMS)),
                        "notification" to notificationsAllowed(),
                        "listener" to listenerEnabled(),
                    )
                )
                "requestSmsPermission" -> {
                    requestPermissions(arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS), 1)
                    result.success(null)
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 2)
                    } else {
                        openAppSettings()
                    }
                    result.success(null)
                }
                "openNotificationAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "openAppSettings" -> {
                    openAppSettings()
                    result.success(null)
                }
                "cancelNotifications" -> {
                    CardSms.cancelAll(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        CardSms.onNew = null
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        channel?.invokeMethod("permissionsChanged", null)
    }

    private fun granted(p: String) = checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    private fun notificationsAllowed(): Boolean {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.areNotificationsEnabled()
    }

    private fun listenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        return flat.split(":").any { it.startsWith("$packageName/") }
    }

    private fun openAppSettings() {
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        )
    }
}
