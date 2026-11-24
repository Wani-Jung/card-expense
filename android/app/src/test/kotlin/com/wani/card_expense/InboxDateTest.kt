package com.wani.card_expense

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** REQ-69: 저장소마다 다른 날짜 단위를 밀리초로, 날짜가 없거나 기간 밖이면 불러오지 않음 */
class InboxDateTest {
    private val ms = 1_795_400_000_000L // 2026-11 무렵

    @Test
    fun unitsBecomeMillis() {
        assertEquals(ms, InboxDate.toMillis(ms))
        assertEquals(ms, InboxDate.toMillis(ms / 1000)) // MMS 초
        assertEquals(ms, InboxDate.toMillis(ms * 1000)) // 마이크로초
        assertEquals(ms, InboxDate.toMillis(ms * 1_000_000)) // 나노초
        assertNull(InboxDate.toMillis(null))
        assertNull(InboxDate.toMillis(0))
        assertNull(InboxDate.toMillis(-5))
    }

    @Test
    fun rangeIsHalfOpenAndMissingDateIsOutside() {
        val from = ms - 1000
        val to = ms + 1000
        assertTrue(InboxDate.inRange(ms, from, to))
        assertTrue(InboxDate.inRange(from, from, to))
        assertFalse(InboxDate.inRange(to, from, to))
        assertFalse(InboxDate.inRange(ms - 400L * 86_400_000, from, to)) // 400일 전
        assertFalse(InboxDate.inRange(null, from, to)) // 날짜 없는 저장소 행은 '지금'으로 치지 않는다
    }
}
