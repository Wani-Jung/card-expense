package com.wani.card_expense

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

/** 미분류 알림 판정. 실행: android 폴더에서 gradlew :app:testPublicDebugUnitTest (CI 도 돈다) */
class ReminderRuleTest {
    private val tz = TimeZone.getTimeZone("Asia/Seoul")
    private val hour = 60 * 60 * 1000L
    private val week = ReminderRule.WEEK_MS

    private fun at(y: Int, mo: Int, d: Int, h: Int = 17, mi: Int = 0): Long =
        Calendar.getInstance(tz).apply {
            clear()
            set(y, mo - 1, d, h, mi, 0)
        }.timeInMillis

    // 2026-11-02 = 월요일
    private val mon = at(2026, 11, 2)
    private val fri = at(2026, 11, 6)
    private val sat = at(2026, 11, 7)

    private fun send(times: List<Long>, now: Long, lastSent: Long = 0, enabled: Boolean = true) =
        ReminderRule.shouldSend(enabled, times, lastSent, now, tz)

    @Test fun `7일 경계 - 6일 23시간은 미발송, 딱 7일도 미발송, 7일 초과는 발송`() {
        assertFalse(send(listOf(mon - (6 * 24 + 23) * hour), mon))
        assertFalse(send(listOf(mon - week), mon))
        assertTrue(send(listOf(mon - week - 1), mon))
    }

    @Test fun `건수는 7일 초과만 센다`() {
        assertEquals(2, ReminderRule.overdueCount(listOf(mon - week - 1, mon - 8 * 24 * hour, mon - hour, mon - week), mon))
    }

    @Test fun `0건이면 미발송`() {
        assertFalse(send(emptyList(), mon))
        assertFalse(send(listOf(mon - hour), mon))
    }

    @Test fun `스위치 OFF면 미발송`() {
        assertFalse(send(listOf(mon - 30 * 24 * hour), mon, enabled = false))
    }

    @Test fun `시각 - 평일 17시부터 21시 전까지만, 주말은 미발송`() {
        val old = listOf(mon - 30 * 24 * hour)
        assertFalse(send(old, at(2026, 11, 2, 16, 59)))
        assertTrue(send(old, at(2026, 11, 2, 17, 0)))
        assertTrue(send(old, at(2026, 11, 2, 20, 59)))
        assertFalse(send(old, at(2026, 11, 2, 21, 0)))
        assertFalse(send(old, sat))
        assertFalse(send(old, at(2026, 11, 8)))
    }

    @Test fun `주말에 걸리면 다음 월요일 17시로 미룸`() {
        val nextMon = at(2026, 11, 9)
        assertEquals(nextMon, ReminderRule.nextCheck(at(2026, 11, 6, 17, 1), 0, tz)) // 금요일 5시 지남
        assertEquals(nextMon, ReminderRule.nextCheck(sat, 0, tz))
        assertEquals(nextMon, ReminderRule.nextCheck(at(2026, 11, 8, 23, 0), 0, tz)) // 일요일 밤
    }

    @Test fun `평일에는 다음 17시, 17시 전이면 오늘`() {
        assertEquals(mon, ReminderRule.nextCheck(at(2026, 11, 2, 9, 0), 0, tz))
        assertEquals(at(2026, 11, 3), ReminderRule.nextCheck(mon, 0, tz))
        assertEquals(fri, ReminderRule.nextCheck(at(2026, 11, 5, 17, 0), 0, tz))
    }

    @Test fun `재발송 간격 - 보낸 뒤 7일 안에는 미발송, 7일 뒤 조건이 맞으면 발송`() {
        val old = listOf(mon - 30 * 24 * hour)
        assertFalse(send(old, at(2026, 11, 6), lastSent = mon)) // 4일 뒤
        assertFalse(send(old, mon + week - 1, lastSent = mon))
        assertTrue(send(old, mon + week, lastSent = mon))
        assertFalse(send(emptyList(), mon + week, lastSent = mon)) // 7일 뒤에도 0건이면 중단
    }

    @Test fun `재발송 예약 - 7일이 차는 때에 확인해서 한 주를 건너뛰지 않음`() {
        // 월 17:00:12 에 보냄 → 다음 월 17:00 에 깨면 12초 모자라 한 주 밀리면 안 된다
        val sent = mon + 12_000
        assertEquals(sent + week, ReminderRule.nextCheck(sent, sent, tz))
        assertEquals(sent + week, ReminderRule.nextCheck(mon + week, sent, tz))
        assertTrue(send(listOf(mon - 30 * 24 * hour), sent + week, lastSent = sent))
    }

    @Test fun `7일 차는 때가 창 밖이면 그 뒤 첫 평일 17시`() {
        // 금 20:30 에 보냄 → 7일 뒤 금 20:30 은 창 안
        val friLate = at(2026, 11, 6, 20, 30)
        assertEquals(friLate + week, ReminderRule.nextCheck(friLate, friLate, tz))
        // 일요일에 7일이 차도록 시계가 바뀌어 있었으면(예: 지난 일요일 기록) 월요일로
        val sunday = at(2026, 11, 1)
        assertEquals(at(2026, 11, 9), ReminderRule.nextCheck(sunday + 1, sunday, tz))
    }

    @Test fun `문구`() {
        assertEquals("미분류 내역 3건이 일주일 넘게 남아 있어요", ReminderRule.message(3))
    }
}
