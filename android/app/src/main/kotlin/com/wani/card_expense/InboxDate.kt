package com.wani.card_expense

/**
 * 문자 저장소 날짜 → 밀리초 (순수 Kotlin, 단위 테스트 InboxDateTest, REQ-69).
 * SMS 는 밀리초, MMS 는 초, RCS 후보 저장소는 기기마다 초·밀리초·마이크로초·나노초가 섞여 있다.
 * 날짜를 못 읽으면 null → 그 문자는 기간 불러오기에서 뺀다 (예전엔 '지금'으로 쳐서 기간과 상관없이 다 들어왔다).
 */
object InboxDate {
    private const val SEC_MAX = 100_000_000_000L          // 이보다 작으면 초 (밀리초라면 1973년 이전)
    private const val MICRO_MIN = 100_000_000_000_000L    // 이보다 크면 마이크로초 (밀리초라면 5138년 이후)
    private const val NANO_MIN = 100_000_000_000_000_000L // 이보다 크면 나노초

    fun toMillis(v: Long?): Long? = when {
        v == null || v <= 0 -> null
        v < SEC_MAX -> v * 1000
        v >= NANO_MIN -> v / 1_000_000
        v >= MICRO_MIN -> v / 1000
        else -> v
    }

    /** [fromMs, toMs) 안인지. 날짜가 없으면 밖으로 친다 */
    fun inRange(ms: Long?, fromMs: Long, toMs: Long): Boolean = ms != null && ms >= fromMs && ms < toMs
}
