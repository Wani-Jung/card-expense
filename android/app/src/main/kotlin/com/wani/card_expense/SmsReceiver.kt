package com.wani.card_expense

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/** 일반 SMS 수신. 앱이 꺼져 있어도 시스템이 깨워서 호출한다. */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (parts.isEmpty()) return
        if (!CardSms.senderMatches(context, parts[0].originatingAddress)) return
        // 긴 문자는 여러 조각으로 오므로 이어 붙인다.
        val body = parts.joinToString("") { it.messageBody ?: "" }
        CardSms.handle(context, body, parts[0].timestampMillis)
    }
}
