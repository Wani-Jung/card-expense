package com.wani.card_expense

/**
 * 발신번호 비교 (순수 Kotlin, 단위 테스트 SenderMatchTest). Dart sms_parser.dart normalizeNumber·senderMatches 와 같은 규칙.
 *
 * 문자 저장소마다 주소 형식이 다르다: 1588-1600 / 15881600 / +8215881600 / 82-1588-1600 / 0015881600 /
 * tel:+82-1588-1600 / sip:+8215881600@ims.mnc008.mcc450.3gppnetwork.org;user=phone (RCS) / #15881600 / 앞뒤 공백.
 * '@' 나 ';' 뒤(도메인·옵션)에는 숫자가 섞여 있어 그대로 숫자만 남기면 끝자리 비교가 깨지므로 먼저 잘라낸다.
 */
object SenderMatch {
    fun normalize(s: String): String {
        // 저장소·진단 표시 접두어('im/chat:', 'rcs:', 'tel:', 'sip:' …)는 숫자가 없어 아래에서 자연히 빠지지만,
        // 'im/chat: 15881600' 처럼 콜론 앞에 붙은 이름은 명시적으로 떼어 둔다 (REQ-66)
        var t = s.trim().replace(Regex("^[A-Za-z/._-]+:\\s*"), "")
        val cut = t.indexOfAny(charArrayOf('@', ';'))
        if (cut >= 0) t = t.substring(0, cut)
        var d = t.filter { it in '0'..'9' }
        if (d.startsWith("0082")) d = d.substring(2) // 국제전화 접두어 00 + 82
        if (d.startsWith("82") && d.length >= 10) d = d.substring(2)
        return d.trimStart('0')
    }

    /** 끝자리 일치 비교. 7자리 미만(빈 값·문자 발신자 이름 등)은 불일치 */
    fun matches(address: String?, configured: String?): Boolean {
        if (address == null || configured == null) return false
        val a = normalize(address)
        val b = normalize(configured)
        if (a.length < 7 || b.length < 7) return false
        return a.endsWith(b) || b.endsWith(a)
    }
}
