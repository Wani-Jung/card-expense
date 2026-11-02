package com.wani.card_expense

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import java.util.concurrent.TimeUnit

/**
 * 미분류 7일 알림. 이 앱이 띄우는 유일한 상태바 알림이다 (사용자 결정 2026-11). 판정은 [ReminderRule].
 *
 * 앱이 꺼져 있어도 판정해야 하므로 Flutter 가 미분류 내역 시각을 네이티브 저장소에 넣어 두고([sync]),
 * WorkManager 가 평일 오후 5시쯤 깨어나 확인한다. 재부팅해도 WorkManager 가 예약을 되살린다.
 */
object UnclassifiedReminder {
    const val EXTRA_OPEN = "open_target"
    const val OPEN_UNCLASSIFIED = "unclassified"

    private const val WORK_NAME = "unclassified_reminder"
    private const val CHANNEL_ID = "unclassified"
    private const val CHANNEL_NAME = "미분류 알림"
    private const val NOTIFICATION_ID = 1001

    private const val PREFS = "card_expense_reminder"
    private const val KEY_TIMES = "times"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_LAST_SENT = "last_sent"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Flutter → 네이티브: 미분류 내역 시각과 스위치. 켜져 있으면 예약이 살아 있게, 꺼지면 예약 취소 */
    fun sync(ctx: Context, times: List<Long>, enabled: Boolean) {
        prefs(ctx).edit().putString(KEY_TIMES, JSONArray(times).toString()).putBoolean(KEY_ENABLED, enabled).apply()
        val wm = WorkManager.getInstance(ctx)
        if (enabled) schedule(ctx, ExistingWorkPolicy.KEEP) else wm.cancelUniqueWork(WORK_NAME)
    }

    private fun schedule(ctx: Context, policy: ExistingWorkPolicy) {
        val now = System.currentTimeMillis()
        val next = ReminderRule.nextCheck(now, prefs(ctx).getLong(KEY_LAST_SENT, 0))
        val request = OneTimeWorkRequestBuilder<UnclassifiedWorker>()
            .setInitialDelay(next - now, TimeUnit.MILLISECONDS)
            .build()
        WorkManager.getInstance(ctx).enqueueUniqueWork(WORK_NAME, policy, request)
    }

    /** Worker 가 깨어났을 때: 조건이 맞으면 알림 */
    private fun check(ctx: Context) {
        val p = prefs(ctx)
        val saved = JSONArray(p.getString(KEY_TIMES, "[]"))
        // 앱을 안 연 동안 들어온 문자(네이티브 inbox)도 미분류다
        val times = List(saved.length()) { saved.getLong(it) } + CardSms.inboxTimes(ctx)
        val now = System.currentTimeMillis()
        if (!ReminderRule.shouldSend(p.getBoolean(KEY_ENABLED, false), times, p.getLong(KEY_LAST_SENT, 0), now)) return
        if (!canNotify(ctx)) return
        notify(ctx, ReminderRule.overdueCount(times, now))
        p.edit().putLong(KEY_LAST_SENT, now).apply()
    }

    /** 시스템 알림 허용 여부 (안드로이드 13 미만은 권한 없이 앱별 설정만) */
    fun canNotify(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        return ctx.getSystemService(NotificationManager::class.java).areNotificationsEnabled()
    }

    private fun notify(ctx: Context, n: Int) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_DEFAULT))
        }
        val open = PendingIntent.getActivity(
            ctx,
            0,
            Intent(ctx, MainActivity::class.java)
                .putExtra(EXTRA_OPEN, OPEN_UNCLASSIFIED)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, CHANNEL_ID) else Notification.Builder(ctx)
        nm.notify(
            NOTIFICATION_ID,
            builder
                .setSmallIcon(R.drawable.ic_stat_card)
                .setColor(0xFF1F3A68.toInt())
                .setContentTitle(ReminderRule.message(n))
                .setContentIntent(open)
                .setAutoCancel(true)
                .build(),
        )
    }

    /** 한 번 깨어날 때마다 확인하고 다음 확인을 잇는다 (실행 중인 자기 뒤에 붙이므로 APPEND_OR_REPLACE) */
    class UnclassifiedWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
        override fun doWork(): Result {
            // 이번 확인이 실패해도 다음 확인은 이어져야 한다 (실패로 끝나면 뒤에 붙인 작업까지 취소됨)
            try {
                check(applicationContext)
            } catch (_: Exception) {
            }
            schedule(applicationContext, ExistingWorkPolicy.APPEND_OR_REPLACE)
            return Result.success()
        }
    }
}
