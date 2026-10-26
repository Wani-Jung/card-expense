package com.wani.card_expense

import android.app.Notification
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * 메시지 앱 알림 감지. 갤럭시에서 RCS/LMS 로 오는 문자는 SMS_RECEIVED 가 안 오기 때문에
 * 알림 내용으로 한 번 더 잡는다. 중복은 CardSms.handle 에서 걸러진다.
 */
class CardNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return
        val extras = sbn.notification?.extras ?: return
        val texts = mutableListOf<Pair<String, Long>>()

        // MessagingStyle: 대화방 알림에 여러 문자가 묶여 있으면 하나씩 따로 본다.
        @Suppress("DEPRECATION")
        val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
        messages?.forEach { m ->
            val b = m as? Bundle ?: return@forEach
            val t = b.getCharSequence("text")?.toString() ?: return@forEach
            texts += t to b.getLong("time", sbn.postTime)
        }
        if (texts.isEmpty()) {
            extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.forEach {
                texts += it.toString() to sbn.postTime
            }
        }
        if (texts.isEmpty()) {
            val t = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT)
            if (t != null) texts += t.toString() to sbn.postTime
        }
        for ((t, ts) in texts) CardSms.handle(this, t, ts)
    }
}
