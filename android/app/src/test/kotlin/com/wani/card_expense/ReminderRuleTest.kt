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

    /** 기존 규칙 테스트용: 승인 일시는 지금(이번 달), 미분류 시작만 [times] */
    private fun send(times: List<Long>, now: Long, lastSent: Long = 0, enabled: Boolean = true) =
        ReminderRule.shouldSend(enabled, times.map { ReminderRule.Item(now, it) }, lastSent, now, tz)

    private fun item(date: Long, pending: Long = date) = ReminderRule.Item(date, pending)
    private fun sendItems(items: List<ReminderRule.Item>, now: Long) = ReminderRule.shouldSend(true, items, 0, now, tz)

    @Test fun `7일 경계 - 6일 23시간은 미발송, 딱 7일도 미발송, 7일 초과는 발송`() {
        assertFalse(send(listOf(mon - (6 * 24 + 23) * hour), mon))
        assertFalse(send(listOf(mon - week), mon))
        assertTrue(send(listOf(mon - week - 1), mon))
    }

    @Test fun `건수는 7일 초과만 센다`() {
        val items = listOf(mon - week - 1, mon - 8 * 24 * hour, mon - hour, mon - week).map { item(mon, it) }
        assertEquals(2, ReminderRule.overdueCount(items, mon, tz))
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

    @Test fun `대상 - 이번 달은 늘, 지난달은 1~15일만, 그보다 오래된 건 빠짐`() {
        fun m(date: Long, now: Long) = ReminderRule.monthOf(date, now, tz)
        val oct = at(2026, 10, 20, 12)
        assertEquals(0, m(at(2026, 11, 1, 0), at(2026, 11, 1, 17)))
        assertEquals(1, m(oct, at(2026, 11, 1))) // 1일
        assertEquals(1, m(oct, at(2026, 11, 15, 20, 59))) // 15일
        assertEquals(null, m(oct, at(2026, 11, 16))) // 16일부터 지난달 제외
        assertEquals(null, m(oct, at(2026, 11, 30))) // 월말
        assertEquals(0, m(at(2026, 11, 2), at(2026, 11, 30)))
        assertEquals(null, m(at(2026, 9, 30), at(2026, 11, 1))) // 두 달 전
        assertEquals(null, m(at(2026, 12, 1), at(2026, 11, 30))) // 다음 달(미래)
        // 연말 → 연초
        assertEquals(1, m(at(2026, 12, 31, 23, 59), at(2027, 1, 4)))
        assertEquals(null, m(at(2026, 12, 31), at(2027, 1, 18)))
        assertEquals(null, m(at(2026, 1, 10), at(2027, 1, 4))) // 1년 전 같은 달
        assertEquals(0, m(at(2027, 1, 1, 0), at(2027, 1, 4)))
    }

    @Test fun `지난달 건 - 15일까지는 발송, 16일부터는 미발송`() {
        val oct = item(at(2026, 10, 20, 12))
        assertTrue(sendItems(listOf(oct), at(2026, 11, 13))) // 금 13일
        assertFalse(sendItems(listOf(oct), at(2026, 11, 16))) // 월 16일
        // 이번 달 건이 7일 안 됐으면 지난달 건이 빠진 16일엔 미발송
        assertFalse(sendItems(listOf(oct, item(at(2026, 11, 12))), at(2026, 11, 16)))
        assertTrue(sendItems(listOf(oct, item(at(2026, 11, 2, 9))), at(2026, 11, 16)))
    }

    @Test fun `1년치 불러온 경우 - 오래된 건 때문에 알림이 가지 않음`() {
        val now = at(2026, 11, 24) // 화
        val importedAt = now - 10 * 24 * hour // 열흘 전에 1~10월·작년 12월 문자를 불러옴 → 미분류 10일
        val old = (1..10).map { item(at(2026, it, 10, 12), importedAt) } + item(at(2025, 12, 10), importedAt)
        assertEquals(0, ReminderRule.overdueCount(old, now, tz))
        assertFalse(sendItems(old, now))
        // 이번 달 건이 하나라도 7일 넘으면 그때만 발송, 문구 숫자도 이번 달만
        val withThis = old + item(at(2026, 11, 3, 12))
        assertTrue(sendItems(withThis, now))
        assertEquals("이번 달 미분류 1건이 남아 있어요", ReminderRule.message(ReminderRule.scope(withThis, now, tz)))
    }

    @Test fun `연말에서 연초 - 12월 건은 1월 15일까지 대상`() {
        val dec = item(at(2026, 12, 20, 12))
        assertTrue(sendItems(listOf(dec), at(2027, 1, 15))) // 금
        assertFalse(sendItems(listOf(dec), at(2027, 1, 18))) // 월
    }

    @Test fun `문구 - 이번 달만, 지난달만, 둘 다`() {
        assertEquals("이번 달 미분류 3건이 남아 있어요", ReminderRule.message(ReminderRule.Scope(3, 0)))
        assertEquals("지난달 미분류 2건이 남아 있어요", ReminderRule.message(ReminderRule.Scope(0, 2)))
        assertEquals("이번 달 3건 · 지난달 2건 미분류가 남아 있어요", ReminderRule.message(ReminderRule.Scope(3, 2)))
        val now = at(2026, 11, 10)
        val s = ReminderRule.scope(
            listOf(item(at(2026, 11, 1)), item(at(2026, 10, 3)), item(at(2026, 10, 31)), item(at(2026, 8, 1))),
            now,
            tz,
        )
        assertEquals(ReminderRule.Scope(1, 2), s)
    }
}
