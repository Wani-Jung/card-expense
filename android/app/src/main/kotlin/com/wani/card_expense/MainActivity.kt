package com.wani.card_expense

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    // 메시지 앱에서 공유받은 문자. Flutter 가 takeShared 로 가져간다.
    private val shared = ArrayList<String>()

    // 미분류 알림을 눌러 열 화면. Flutter 가 takeOpenTarget 으로 가져간다.
    private var openTarget: String? = null

    // 알림 권한 요청 결과를 기다리는 Flutter 쪽 응답
    private var notificationResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        collectShared(intent)
        collectOpenTarget(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (collectShared(intent)) channel?.invokeMethod("onShared", null)
        if (collectOpenTarget(intent)) channel?.invokeMethod("openTarget", null)
    }

    private fun collectOpenTarget(intent: Intent?): Boolean {
        // 최근 앱 목록에서 다시 열 때는 예전 인텐트가 그대로 오므로 무시한다
        if (intent == null || intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return false
        val target = intent.getStringExtra(UnclassifiedReminder.EXTRA_OPEN) ?: return false
        intent.removeExtra(UnclassifiedReminder.EXTRA_OPEN)
        openTarget = target
        return true
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
                "setUsage" -> {
                    CardSms.setUsage(this, call.argument<Boolean>("listener") ?: true, call.argument<Boolean>("sms") ?: true)
                    result.success(null)
                }
                "drainInbox" -> result.success(CardSms.drain(this))
                "takeShared" -> {
                    result.success(ArrayList(shared))
                    shared.clear()
                }
                "permissionStatus" -> {
                    val status = mutableMapOf<String, Boolean>(
                        "listener" to listenerEnabled(),
                    )
                    // 문자 권한은 전용판에만 있다. 일반판은 키 자체를 넣지 않는다.
                    if (Flavor.smsPermissions.isNotEmpty()) {
                        val granted = Flavor.smsPermissions.all {
                            checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
                        }
                        status["sms"] = granted
                        // 요청한 적이 있는데 다시 물을 수 없으면 영구 거부 → 앱 정보 화면에서 켜야 한다
                        status["smsBlocked"] = !granted && CardSms.smsRequested(this) &&
                            Flavor.smsPermissions.none { shouldShowRequestPermissionRationale(it) }
                    }
                    result.success(status)
                }
                "requestSmsPermission" -> {
                    if (Flavor.smsPermissions.isNotEmpty()) {
                        CardSms.markSmsRequested(this)
                        requestPermissions(Flavor.smsPermissions, 1)
                    }
                    result.success(null)
                }
                "readSmsInbox" -> {
                    val days = call.argument<Int>("days") ?: 365
                    thread {
                        try {
                            val map = Flavor.readInbox(this, days)
                            runOnUiThread {
                                if (map == null) result.error("UNSUPPORTED", "일반판에는 없는 기능", null)
                                else result.success(map)
                            }
                        } catch (e: SecurityException) {
                            runOnUiThread { result.error("NO_PERMISSION", e.message, null) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("FAILED", e.message, null) }
                        }
                    }
                }
                "sliceImage" -> {
                    val path = call.argument<String>("path")!!
                    thread {
                        try {
                            val slices = ImageSlicer.slice(path, cacheDir)
                            runOnUiThread { result.success(slices) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("FAILED", e.message, null) }
                        }
                    }
                }
                "openNotificationAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "openAppSettings" -> {
                    openAppSettings()
                    result.success(null)
                }
                "cacheDir" -> result.success(cacheDir.absolutePath)
                "syncReminder" -> {
                    val times = call.argument<List<Number>>("times").orEmpty().map { it.toLong() }
                    UnclassifiedReminder.sync(this, times, call.argument<Boolean>("enabled") ?: true)
                    result.success(null)
                }
                "takeOpenTarget" -> {
                    result.success(openTarget)
                    openTarget = null
                }
                "notificationsEnabled" -> result.success(UnclassifiedReminder.canNotify(this))
                "requestNotificationPermission" -> {
                    // 안드로이드 13 미만은 권한 창이 없다. 이미 허용됐으면 바로 답한다
                    if (Build.VERSION.SDK_INT < 33 ||
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(UnclassifiedReminder.canNotify(this))
                    } else {
                        notificationResult?.success(false)
                        notificationResult = result
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
                    }
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
        if (requestCode == REQUEST_NOTIFICATIONS) {
            notificationResult?.success(UnclassifiedReminder.canNotify(this))
            notificationResult = null
            return
        }
        channel?.invokeMethod("permissionsChanged", null)
    }

    private fun listenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        return flat.split(":").any { it.startsWith("$packageName/") }
    }

    private companion object {
        const val REQUEST_NOTIFICATIONS = 2
    }

    private fun openAppSettings() {
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        )
    }
}
