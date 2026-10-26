package com.wani.card_expense

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    // 메시지 앱에서 공유받은 문자. Flutter 가 takeShared 로 가져간다.
    private val shared = ArrayList<String>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        collectShared(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (collectShared(intent)) channel?.invokeMethod("onShared", null)
    }

    private fun collectShared(intent: Intent?): Boolean {
        val texts = when (intent?.action) {
            Intent.ACTION_SEND -> listOfNotNull(intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString())
            Intent.ACTION_SEND_MULTIPLE ->
                intent.getCharSequenceArrayListExtra(Intent.EXTRA_TEXT)?.map { it.toString() }
                    ?: listOfNotNull(intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString())
            else -> emptyList()
        }
        // 같은 인텐트를 두 번 처리하지 않도록 비워 둔다. (화면 회전 등으로 다시 만들어질 때)
        intent?.action = null
        shared.addAll(texts.filter { it.isNotBlank() })
        return texts.isNotEmpty()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "card_expense/native")
        channel = ch
        CardSms.onNew = { ch.invokeMethod("onNewSms", null) }

        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "setSettings" -> {
                    CardSms.setSettings(this, call.argument<String>("digits"), call.argument<String>("sender"))
                    result.success(null)
                }
                "drainInbox" -> result.success(CardSms.drain(this))
                "takeShared" -> {
                    result.success(ArrayList(shared))
                    shared.clear()
                }
                "permissionStatus" -> result.success(
                    mapOf(
                        "notification" to notificationsAllowed(),
                        "listener" to listenerEnabled(),
                    )
                )
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 2)
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
