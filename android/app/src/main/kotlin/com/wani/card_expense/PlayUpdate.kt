package com.wani.card_expense

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability

/**
 * 스토어판 '버전 정보' (REQ-64): Google Play 인앱 업데이트로 확인·업데이트. 누를 때만 부른다(앱 시작 때 자동 확인 없음).
 * Play 에서 설치하지 않은 앱(깃허브 APK·에뮬레이터 등)은 확인이 실패한다 → Dart 가 '지금은 확인할 수 없어요'.
 * 업데이트는 Play 경로만 쓴다(유연한 업데이트 → 내려받기가 끝나면 바로 설치·재시작, 안 되면 Play 스토어 앱 페이지).
 */
object PlayUpdate {
    const val REQUEST_UPDATE = 4202

    /** {status: available|latest|error, versionCode?, flexible?, message?} */
    fun check(activity: Activity, done: (Map<String, Any?>) -> Unit) {
        try {
            AppUpdateManagerFactory.create(activity).appUpdateInfo
                .addOnSuccessListener { info ->
                    val available = info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE ||
                        info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                    done(
                        mapOf(
                            "status" to if (available) "available" else "latest",
                            "versionCode" to info.availableVersionCode(),
                            "flexible" to info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE),
                        ),
                    )
                }
                .addOnFailureListener { e -> done(mapOf("status" to "error", "message" to (e.message ?: ""))) }
        } catch (e: Exception) {
            done(mapOf("status" to "error", "message" to (e.message ?: "")))
        }
    }

    /** 유연한 업데이트 흐름을 시작한다. 시작 못 하면 false (Dart 가 Play 스토어 페이지를 연다) */
    fun start(activity: Activity, done: (Boolean) -> Unit) {
        try {
            val manager = AppUpdateManagerFactory.create(activity)
            manager.appUpdateInfo
                .addOnSuccessListener { info ->
                    val ok = info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                        info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)
                    if (!ok) {
                        done(false)
                        return@addOnSuccessListener
                    }
                    // 내려받기가 끝나면 바로 설치(앱이 다시 시작됨). 사용자가 [업데이트]를 눌러 시작한 흐름이라 따로 묻지 않는다
                    lateinit var listener: InstallStateUpdatedListener
                    listener = InstallStateUpdatedListener { state ->
                        when (state.installStatus()) {
                            InstallStatus.DOWNLOADED -> {
                                manager.unregisterListener(listener)
                                manager.completeUpdate()
                            }
                            InstallStatus.FAILED, InstallStatus.CANCELED -> manager.unregisterListener(listener)
                            else -> {}
                        }
                    }
                    manager.registerListener(listener)
                    val started = try {
                        manager.startUpdateFlowForResult(
                            info,
                            activity,
                            AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE).build(),
                            REQUEST_UPDATE,
                        )
                    } catch (_: Exception) {
                        false
                    }
                    if (!started) manager.unregisterListener(listener)
                    done(started)
                }
                .addOnFailureListener { done(false) }
        } catch (_: Exception) {
            done(false)
        }
    }

    /** Play 스토어 앱의 이 앱 페이지 (없으면 웹) */
    fun openStore(activity: Activity) {
        val pkg = activity.packageName
        try {
            activity.startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pkg")).setPackage("com.android.vending"),
            )
        } catch (_: ActivityNotFoundException) {
            activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$pkg")))
        }
    }
}
