package com.wani.card_expense

import java.util.Calendar
import java.util.TimeZone

/**
 * 미분류 알림 판정 (안드로이드 의존 없음, JVM 단위 테스트: src/test/.../ReminderRuleTest.kt).
 * - 조건: 미분류로 7일 넘게 남은 내역이 1건 이상
 * - 시각: 평일 오후 5시. 주말에 걸리면 다음 월요일
 * - 빈도: 보낸 뒤 최소 7일은 다시 안 보냄
 */
object ReminderRule {
    const val WEEK_MS = 7L * 24 * 60 * 60 * 1000
    private const val HOUR_START = 17

    /** 기기가 꺼져 있거나 절전으로 늦어져도 이 시각(21시) 전이면 보낸다. 그 뒤면 다음 평일로 넘긴다 (밤에 안 울리게) */
    private const val HOUR_END = 21

    fun message(n: Int) = "미분류 내역 ${n}건이 일주일 넘게 남아 있어요"

    /** 7일 "초과" 미분류 건수. 딱 7일은 아직 아니다. */
    fun overdueCount(times: List<Long>, now: Long): Int = times.count { now - it > WEEK_MS }

    /** 평일 17:00 ~ 21:00 안인지 */
    fun inWindow(t: Long, tz: TimeZone = TimeZone.getDefault()): Boolean {
        val c = Calendar.getInstance(tz).apply { timeInMillis = t }
        val hour = c.get(Calendar.HOUR_OF_DAY)
        return isWeekday(c) && hour >= HOUR_START && hour < HOUR_END
    }

    /** 지금 알림을 보낼지 */
    fun shouldSend(
        enabled: Boolean,
        times: List<Long>,
        lastSent: Long,
        now: Long,
        tz: TimeZone = TimeZone.getDefault(),
    ): Boolean =
        enabled && overdueCount(times, now) > 0 && inWindow(now, tz) && (lastSent <= 0 || now - lastSent >= WEEK_MS)

    /** 다음에 확인할 시각. 보통 다음 평일 17:00, 보낸 지 7일이 안 됐으면 7일이 차는 때(창 밖이면 그 뒤 첫 평일 17:00) */
    fun nextCheck(now: Long, lastSent: Long, tz: TimeZone = TimeZone.getDefault()): Long {
        val due = if (lastSent > 0) lastSent + WEEK_MS else 0
        if (due > now) return if (inWindow(due, tz)) due else nextStart(due, tz)
        return nextStart(now, tz)
    }

    /** [t] 보다 뒤의 첫 평일 17:00 */
    private fun nextStart(t: Long, tz: TimeZone): Long {
        val c = Calendar.getInstance(tz).apply {
            timeInMillis = t
            set(Calendar.HOUR_OF_DAY, HOUR_START)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        while (c.timeInMillis <= t || !isWeekday(c)) c.add(Calendar.DAY_OF_MONTH, 1)
        return c.timeInMillis
    }

    private fun isWeekday(c: Calendar): Boolean {
        val d = c.get(Calendar.DAY_OF_WEEK)
        return d != Calendar.SATURDAY && d != Calendar.SUNDAY
    }
}
