package com.wani.card_expense

import android.app.Notification
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * 메시지 앱 알림 감지. 문자 권한 없이 실시간으로 승인 문자를 잡는 유일한 통로다.
 * 알림 제목(발신자 번호)이나 본문 카드번호로 대상인지 판정한다. 중복은 CardSms.handle 에서 걸러진다.
 */
class CardNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return
        if (!CardSms.useListener(this)) return // 권한 설정에서 '앱에서 사용'을 끈 상태
        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        // (본문, 받은 시각, 보낸 사람)
        val texts = mutableListOf<Triple<String, Long, String?>>()

        // MessagingStyle: 대화방 알림에 여러 문자가 묶여 있으면 하나씩 따로 본다.
        @Suppress("DEPRECATION")
        val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
        messages?.forEach { m ->
            val b = m as? Bundle ?: return@forEach
            val t = b.getCharSequence("text")?.toString() ?: return@forEach
            val sender = b.getCharSequence("sender")?.toString() ?: title
            texts += Triple(t, b.getLong("time", sbn.postTime), sender)
        }
        if (texts.isEmpty()) {
            extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.forEach {
                texts += Triple(it.toString(), sbn.postTime, title)
            }
        }
        if (texts.isEmpty()) {
            val t = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT)
            if (t != null) texts += Triple(t.toString(), sbn.postTime, title)
        }
        for ((t, ts, sender) in texts) CardSms.handle(this, t, ts, sender)
    }
}
