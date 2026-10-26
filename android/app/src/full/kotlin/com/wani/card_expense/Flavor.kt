package com.wani.card_expense

import android.Manifest
import android.content.Context
import android.net.Uri

/** 전용판: 문자 권한으로 실시간 수신(SmsReceiver)과 지난 문자 불러오기를 한다. */
object Flavor {
    private const val MMS_FROM = 137 // content://mms/{id}/addr 의 type: 보낸 사람

    val smsPermissions = arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS)

    /**
     * 문자함에서 최근 days 일 동안 발신번호가 일치하는 문자를 읽는다. READ_SMS 권한 필요.
     * [Web발신] 장문(LMS)은 MMS 테이블에 저장되므로 SMS·MMS 를 둘 다 본다.
     * 카드번호 확인은 Dart 쪽 parseSms 가 한다. (건수 통계를 내기 위해)
     */
    fun readInbox(ctx: Context, days: Int): Map<String, Any>? {
        val sender = CardSms.sender(ctx)
        val sinceMs = System.currentTimeMillis() - days * 24L * 60 * 60 * 1000
        val items = ArrayList<Map<String, Any>>()
        val cr = ctx.contentResolver

        var smsScanned = 0
        cr.query(
            Uri.parse("content://sms"),
            arrayOf("address", "body", "date"),
            "date >= ?",
            arrayOf(sinceMs.toString()),
            "date ASC",
        )?.use { c ->
            while (c.moveToNext()) {
                smsScanned++
                if (!CardSms.senderMatches(c.getString(0), sender)) continue
                val body = c.getString(1) ?: continue
                items.add(mapOf("body" to body, "ts" to c.getLong(2)))
            }
        }

        var mmsScanned = 0
        cr.query(
            Uri.parse("content://mms"),
            arrayOf("_id", "date"),
            "date >= ?",
            arrayOf((sinceMs / 1000).toString()), // MMS date 는 초 단위
            "date ASC",
        )?.use { c ->
            while (c.moveToNext()) {
                mmsScanned++
                val id = c.getLong(0)
                if (!CardSms.senderMatches(mmsFrom(ctx, id), sender)) continue
                val body = mmsText(ctx, id)
                if (body.isEmpty()) continue
                items.add(mapOf("body" to body, "ts" to c.getLong(1) * 1000))
            }
        }

        return mapOf("items" to items, "smsScanned" to smsScanned, "mmsScanned" to mmsScanned)
    }

    private fun mmsFrom(ctx: Context, id: Long): String? =
        ctx.contentResolver.query(
            Uri.parse("content://mms/$id/addr"),
            arrayOf("address"),
            "type = $MMS_FROM",
            null,
            null,
        )?.use { c -> if (c.moveToFirst()) c.getString(0) else null }

    private fun mmsText(ctx: Context, id: Long): String {
        val sb = StringBuilder()
        ctx.contentResolver.query(
            Uri.parse("content://mms/part"),
            arrayOf("_id", "ct", "text"),
            "mid = ?",
            arrayOf(id.toString()),
            null,
        )?.use { c ->
            while (c.moveToNext()) {
                if (c.getString(1) != "text/plain") continue
                val text = c.getString(2) ?: try {
                    ctx.contentResolver.openInputStream(Uri.parse("content://mms/part/${c.getLong(0)}"))
                        ?.use { it.readBytes().toString(Charsets.UTF_8) }
                } catch (_: Exception) {
                    null
                }
                if (text != null) {
                    if (sb.isNotEmpty()) sb.append('\n')
                    sb.append(text)
                }
            }
        }
        return sb.toString()
    }
}
