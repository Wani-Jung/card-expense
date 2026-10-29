package com.wani.card_expense

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject

/**
 * 알림 리스너(두 판 공통)와 SMS 리시버(전용판)가 잡은 승인 문자를 처리하는 곳.
 *
 * 앱이 꺼져 있어도 동작해야 하므로 Flutter 쪽 저장소를 쓰지 않고
 * 네이티브 SharedPreferences 에 "받은 편지함(inbox)"을 쌓아 둔다.
 * Flutter 가 켜지면 drainInbox 로 가져가서 분류 대기에 넣는다.
 * 이 앱은 상태바 알림을 띄우지 않는다. 조용히 쌓아 두고 앱을 열면 보이게 한다.
 */
object CardSms {
    private const val PREFS = "card_expense_native"
    private const val KEY_DIGITS = "card_digits"
    private const val KEY_SENDER = "sender_number"
    private const val KEY_INBOX = "inbox"
    private const val KEY_SEEN = "seen"
    private const val MAX_SEEN = 300
    private const val KEY_USE_LISTENER = "use_listener"
    private const val KEY_USE_SMS = "use_sms"
    private const val KEY_SMS_REQUESTED = "sms_requested"

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

    /** 권한 설정 > '앱에서 사용' 스위치. 꺼져 있으면 알림 감지·SMS 수신이 문자를 받아도 버린다. 기본 켜짐 */
    fun useListener(ctx: Context) = prefs(ctx).getBoolean(KEY_USE_LISTENER, true)
    fun useSms(ctx: Context) = prefs(ctx).getBoolean(KEY_USE_SMS, true)
    fun setUsage(ctx: Context, listener: Boolean, sms: Boolean) {
        prefs(ctx).edit().putBoolean(KEY_USE_LISTENER, listener).putBoolean(KEY_USE_SMS, sms).apply()
    }

    /** 문자 권한을 한 번이라도 요청했는지 (영구 거부 판별용) */
    fun smsRequested(ctx: Context) = prefs(ctx).getBoolean(KEY_SMS_REQUESTED, false)
    fun markSmsRequested(ctx: Context) = prefs(ctx).edit().putBoolean(KEY_SMS_REQUESTED, true).apply()

    private fun compact(text: String) = text.replace(Regex("""\s+"""), "")

    /** 본문에 "카드번호4자리+승인"(또는 취소)이 있는지. (Dart hasCardApproval 과 같게) */
    fun hasCardApproval(text: String, digits: String?): Boolean {
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

    /**
     * 승인 문자면 inbox 에 쌓는다.
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
}
