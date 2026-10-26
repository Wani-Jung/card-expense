package com.wani.card_expense

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject

/**
 * 알림 리스너가 잡은 승인 문자를 처리하는 곳.
 *
 * 앱이 꺼져 있어도 동작해야 하므로 Flutter 쪽 저장소를 쓰지 않고
 * 네이티브 SharedPreferences 에 "받은 편지함(inbox)"을 쌓아 둔다.
 * Flutter 가 켜지면 drainInbox 로 가져가서 자기 저장소로 옮긴다.
 */
object CardSms {
    private const val PREFS = "card_expense_native"
    private const val KEY_DIGITS = "card_digits"
    private const val KEY_SENDER = "sender_number"
    private const val KEY_INBOX = "inbox"
    private const val KEY_SEEN = "seen"
    private const val MAX_SEEN = 300
    private const val CHANNEL_ID = "card_approval"

    // 앱이 떠 있을 때 MainActivity 가 채워 둔다. 새 문자가 오면 바로 화면을 갱신한다.
    var onNew: (() -> Unit)? = null

    private val amountRe = Regex("""(\d{1,3}(?:,\d{3})+|\d+)\s*원""")
    private val dateTimeRe = Regex("""(\d{1,2})/(\d{1,2})\s*(\d{1,2}):(\d{2})""")

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun digits(ctx: Context): String? = prefs(ctx).getString(KEY_DIGITS, null)
    fun sender(ctx: Context): String? = prefs(ctx).getString(KEY_SENDER, null)

    fun setSettings(ctx: Context, digits: String?, sender: String?) {
        prefs(ctx).edit().putString(KEY_DIGITS, digits).putString(KEY_SENDER, sender).apply()
    }

    private fun compact(text: String) = text.replace(Regex("""\s+"""), "")

    /** 본문에 "카드번호4자리+승인"(또는 취소)이 있는지. (Dart hasCardApproval 과 같게) */
    private fun hasCardApproval(text: String, digits: String?): Boolean {
        if (digits.isNullOrEmpty()) return false
        val c = compact(text)
        return c.contains("${digits}승인") || c.contains("${digits}취소")
    }

    /** 숫자만 남기고 국가번호 82, 앞자리 0 을 뗀다. (Dart normalizeNumber 와 같게) */
    private fun normalizeNumber(s: String): String {
        var d = s.filter { it.isDigit() }
        if (d.startsWith("82") && d.length >= 10) d = d.substring(2)
        return d.trimStart('0')
    }

    /** 발신번호 끝자리 일치 비교. (Dart senderMatches 와 같게) */
    fun senderMatches(address: String?, configured: String?): Boolean {
        if (address == null || configured == null) return false
        val a = normalizeNumber(address)
        val b = normalizeNumber(configured)
        if (a.length < 7 || b.length < 7) return false
        return a.endsWith(b) || b.endsWith(a)
    }

    /** 같은 승인 건을 문자/알림 양쪽에서 잡아도 한 번만 처리하기 위한 키. 금액·일시를 못 읽으면 null. */
    private fun dedupeKey(text: String): String? {
        val amount = amountRe.find(text)?.groupValues?.get(1)?.replace(",", "") ?: return null
        val dt = dateTimeRe.find(text) ?: return null
        val (mo, d, h, mi) = dt.destructured
        val cancel = if (compact(text).contains("취소")) "C" else "A"
        return "${mo.toInt()}/${d.toInt()} ${h.toInt()}:$mi|$amount|$cancel"
    }

    private fun merchant(text: String): String {
        val dt = dateTimeRe.find(text) ?: return ""
        val rest = text.substring(dt.range.last + 1)
        val line = rest.split(Regex("""[\r\n]+""")).map { it.trim() }.firstOrNull { it.isNotEmpty() } ?: ""
        return line.substringBefore("누적").trim()
    }

    /**
     * 승인 문자면 inbox 에 쌓고 알림을 띄운다.
     * 알림 제목(보낸 사람)이 설정한 발신번호이거나, 본문에 카드번호+승인이 있으면 대상이다.
     * 어느 쪽이든 승인/취소 + 금액 + 일시는 있어야 한다.
     */
    @Synchronized
    fun handle(ctx: Context, body: String, timestamp: Long, sender: String?) {
        val c = compact(body)
        if (!c.contains("승인") && !c.contains("취소")) return
        if (!senderMatches(sender, sender(ctx)) && !hasCardApproval(body, digits(ctx))) return
        val key = dedupeKey(body) ?: return

        val p = prefs(ctx)
        val seen = JSONArray(p.getString(KEY_SEEN, "[]"))
        for (i in 0 until seen.length()) {
            if (seen.getString(i) == key) return
        }
        seen.put(key)
        while (seen.length() > MAX_SEEN) seen.remove(0)

        val inbox = JSONArray(p.getString(KEY_INBOX, "[]"))
        inbox.put(JSONObject().put("body", body).put("ts", timestamp))
        p.edit().putString(KEY_SEEN, seen.toString()).putString(KEY_INBOX, inbox.toString()).commit()

        showNotification(ctx, body, key)
        Handler(Looper.getMainLooper()).post { onNew?.invoke() }
    }

    @Synchronized
    fun drain(ctx: Context): List<Map<String, Any>> {
        val p = prefs(ctx)
        val inbox = JSONArray(p.getString(KEY_INBOX, "[]"))
        val out = ArrayList<Map<String, Any>>()
        for (i in 0 until inbox.length()) {
            val o = inbox.getJSONObject(i)
            out.add(mapOf("body" to o.getString("body"), "ts" to o.getLong("ts")))
        }
        p.edit().putString(KEY_INBOX, "[]").commit()
        return out
    }

    private fun formatWon(text: String): String {
        val n = amountRe.find(text)?.groupValues?.get(1)?.replace(",", "")?.toLongOrNull() ?: return ""
        return "%,d원".format(n)
    }

    private fun showNotification(ctx: Context, body: String, key: String) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "법카 승인 문자", NotificationManager.IMPORTANCE_HIGH)
            )
        }
        val open = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pi = PendingIntent.getActivity(
            ctx, 0, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val kind = if (compact(body).contains("취소")) "법카 승인취소" else "법카 승인"
        val shop = merchant(body).ifEmpty { "가맹점 미상" }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(ctx, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(ctx)
        }
        val n = builder
            .setSmallIcon(R.drawable.ic_stat_card)
            .setContentTitle("$kind ${formatWon(body)}")
            .setContentText("$shop · 눌러서 분류")
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(key.hashCode(), n)
        } catch (_: SecurityException) {
            // 알림 권한이 없으면 조용히 넘어간다. 내역은 inbox 에 이미 쌓였다.
        }
    }

    fun cancelAll(ctx: Context) {
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancelAll()
    }
}
