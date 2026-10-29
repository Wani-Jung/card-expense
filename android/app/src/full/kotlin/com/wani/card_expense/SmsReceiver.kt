package com.wani.card_expense

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * (전용판) 일반 SMS 수신. 앱이 꺼져 있어도 시스템이 깨워서 호출한다.
 * 발신번호 + 카드번호가 모두 맞아야 대상이다. 알림 감지와 겹친 건은 CardSms.handle 에서 걸러진다.
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (!CardSms.useSms(context)) return // 권한 설정에서 '앱에서 사용'을 끈 상태
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (parts.isEmpty()) return
        val address = parts[0].originatingAddress
        if (!CardSms.senderMatches(address, CardSms.sender(context))) return
        // 긴 문자는 여러 조각으로 오므로 이어 붙인다.
        val body = parts.joinToString("") { it.messageBody ?: "" }
        if (!CardSms.hasCardApproval(body, CardSms.digits(context))) return
        CardSms.handle(context, body, parts[0].timestampMillis, address)
    }
}
