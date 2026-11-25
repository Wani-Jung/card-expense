package com.wani.card_expense

import java.util.Calendar
import java.util.TimeZone

/**
 * 미분류 알림 판정 (안드로이드 의존 없음, JVM 단위 테스트: src/test/.../ReminderRuleTest.kt).
 * - 대상(2.0.3): 승인 날짜가 이번 달인 미분류 + 지난달 미분류(오늘이 1~15일일 때만). 그보다 오래된 건 알림에서만 뺀다
 * - 조건: 대상 중 미분류로 7일 넘게 남은 내역이 1건 이상
 * - 시각: 평일 오후 5시. 주말에 걸리면 다음 월요일
 * - 빈도: 보낸 뒤 최소 7일은 다시 안 보냄
 */
object ReminderRule {
    const val WEEK_MS = 7L * 24 * 60 * 60 * 1000
    private const val HOUR_START = 17

    /** 기기가 꺼져 있거나 절전으로 늦어져도 이 시각(21시) 전이면 보낸다. 그 뒤면 다음 평일로 넘긴다 (밤에 안 울리게) */
    private const val HOUR_END = 21

    /** 지난달 미분류는 오늘이 이 날까지일 때만 알림 대상 */
    private const val LAST_MONTH_UNTIL_DAY = 15

    /** 미분류 한 건: [date] 승인 일시(어느 달 건지), [pendingFrom] 미분류가 된 때(7일 계산) */
    data class Item(val date: Long, val pendingFrom: Long)

    /** 이번 달 대상 n건 · 지난달 대상 n건 */
    data class Scope(val thisMonth: Int, val lastMonth: Int)

    /** 0 = 이번 달, 1 = 지난달(1~15일일 때만), null = 대상 아님 */
    fun monthOf(date: Long, now: Long, tz: TimeZone = TimeZone.getDefault()): Int? {
        val n = Calendar.getInstance(tz).apply { timeInMillis = now }
        val d = Calendar.getInstance(tz).apply { timeInMillis = date }
        val diff = (n.get(Calendar.YEAR) - d.get(Calendar.YEAR)) * 12 + n.get(Calendar.MONTH) - d.get(Calendar.MONTH)
        return when {
            diff == 0 -> 0
            diff == 1 && n.get(Calendar.DAY_OF_MONTH) <= LAST_MONTH_UNTIL_DAY -> 1
            else -> null
        }
    }

    fun inScope(items: List<Item>, now: Long, tz: TimeZone = TimeZone.getDefault()): List<Item> =
        items.filter { monthOf(it.date, now, tz) != null }

    /** 대상 중 7일 "초과" 미분류 건수. 딱 7일은 아직 아니다. */
    fun overdueCount(items: List<Item>, now: Long, tz: TimeZone = TimeZone.getDefault()): Int =
        inScope(items, now, tz).count { now - it.pendingFrom > WEEK_MS }

    /** 알림 문구에 쓸 대상 건수 (7일 안 된 것도 포함, 달별) */
    fun scope(items: List<Item>, now: Long, tz: TimeZone = TimeZone.getDefault()): Scope {
        val m = items.mapNotNull { monthOf(it.date, now, tz) }
        return Scope(m.count { it == 0 }, m.count { it == 1 })
    }

    fun message(s: Scope): String = when {
        s.thisMonth > 0 && s.lastMonth > 0 -> "이번 달 ${s.thisMonth}건 · 지난달 ${s.lastMonth}건 미분류가 남아 있어요"
        s.lastMonth > 0 -> "지난달 미분류 ${s.lastMonth}건이 남아 있어요"
        else -> "이번 달 미분류 ${s.thisMonth}건이 남아 있어요"
    }

    /** 평일 17:00 ~ 21:00 안인지 */
    fun inWindow(t: Long, tz: TimeZone = TimeZone.getDefault()): Boolean {
        val c = Calendar.getInstance(tz).apply { timeInMillis = t }
        val hour = c.get(Calendar.HOUR_OF_DAY)
        return isWeekday(c) && hour >= HOUR_START && hour < HOUR_END
    }

    /** 지금 알림을 보낼지 */
    fun shouldSend(
        enabled: Boolean,
        items: List<Item>,
        lastSent: Long,
        now: Long,
        tz: TimeZone = TimeZone.getDefault(),
    ): Boolean =
        enabled && overdueCount(items, now, tz) > 0 && inWindow(now, tz) && (lastSent <= 0 || now - lastSent >= WEEK_MS)

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
