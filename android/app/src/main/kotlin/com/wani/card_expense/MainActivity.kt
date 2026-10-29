package com.wani.card_expense

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
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
                "shareText" -> {
                    val send = Intent(Intent.ACTION_SEND)
                        .setType("text/plain")
                        .putExtra(Intent.EXTRA_TEXT, call.argument<String>("text") ?: "")
                    startActivity(Intent.createChooser(send, null))
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
