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

        // 삼성 RCS 기업메시지는 SMS/MMS 테이블에 없을 수 있다. 열리는 저장소가 있으면 거기서도 찾는다.
        var otherScanned = 0
        var otherMatched = 0
        for (uri in OTHER_STORES) {
            val r = scanOther(ctx, uri, sinceMs, CardSms.digits(ctx)) ?: continue
            otherScanned += r.scanned
            otherMatched += r.items.size
            items.addAll(r.items)
        }

        return mapOf(
            "items" to items,
            "smsScanned" to smsScanned,
            "mmsScanned" to mmsScanned,
            "otherScanned" to otherScanned,
            "otherMatched" to otherMatched,
        )
    }

    /** 삼성 RCS 등 SMS/MMS 밖의 저장소 후보. 기기마다 열리는 곳이 다르고 대부분 막혀 있다. */
    private val OTHER_STORES = listOf(
        "content://im/chat",
        "content://im/ft",
        "content://im/session",
        "content://mms-sms/complete-conversations",
        "content://mms-sms/conversations?simple=true",
        "content://com.samsung.rcs.im/chat",
        "content://rcs/message",
    )
    private val BODY_COLUMNS = listOf("body", "text", "content", "message", "msg_body", "snippet")
    private val DATE_COLUMNS = listOf("date", "timestamp", "inserted_timestamp", "sent_timestamp", "date_sent")
    private const val MAX_ROWS = 50000

    private class OtherScan(val scanned: Int, val items: List<Map<String, Any>>)

    /** 열리면 카드번호+승인 문자를 찾아 돌려준다. 막혀 있거나 본문 컬럼이 없으면 null. 예외는 삼킨다. */
    private fun scanOther(ctx: Context, uri: String, sinceMs: Long, digits: String?): OtherScan? = try {
        ctx.contentResolver.query(Uri.parse(uri), null, null, null, null)?.use { c ->
            val bodyIdx = BODY_COLUMNS.map { c.getColumnIndex(it) }.firstOrNull { it >= 0 } ?: return@use null
            val dateIdx = DATE_COLUMNS.map { c.getColumnIndex(it) }.firstOrNull { it >= 0 }
            var scanned = 0
            val items = ArrayList<Map<String, Any>>()
            while (c.moveToNext() && scanned < MAX_ROWS) {
                scanned++
                val body = try { c.getString(bodyIdx) } catch (_: Exception) { null } ?: continue
                if (!CardSms.hasCardApproval(body, digits)) continue
                val ts = dateIdx?.let { toMillis(c.getLong(it)) } ?: System.currentTimeMillis()
                if (ts < sinceMs) continue
                items.add(mapOf("body" to body, "ts" to ts))
            }
            OtherScan(scanned, items)
        }
    } catch (_: Exception) {
        null
    }

    /** 날짜 컬럼이 초 단위면 밀리초로. (2001년 이후 밀리초 값은 1e12 이상) */
    private fun toMillis(v: Long) = if (v in 1 until 100_000_000_000L) v * 1000 else v

    /** 메뉴 '문자 저장소 진단': 저장소마다 접근 가능 여부·행 수·컬럼·카드번호 일치 건수. */
    fun diagnoseStores(ctx: Context): List<Map<String, Any?>> {
        val digits = CardSms.digits(ctx)
        val uris = listOf("content://sms", "content://mms") + OTHER_STORES
        return uris.map { uri ->
            try {
                val cursor = ctx.contentResolver.query(Uri.parse(uri), null, null, null, null)
                if (cursor == null) {
                    mapOf("uri" to uri, "ok" to false, "error" to "null cursor (제공자 없음)")
                } else cursor.use { c ->
                    val bodyIdx = BODY_COLUMNS.map { c.getColumnIndex(it) }.firstOrNull { it >= 0 }
                    var matched = 0
                    if (bodyIdx != null) {
                        var n = 0
                        while (c.moveToNext() && n < MAX_ROWS) {
                            n++
                            val body = try { c.getString(bodyIdx) } catch (_: Exception) { null } ?: continue
                            if (CardSms.hasCardApproval(body, digits)) matched++
                        }
                    }
                    mapOf(
                        "uri" to uri,
                        "ok" to true,
                        "count" to c.count,
                        "columns" to c.columnNames.toList(),
                        "bodyColumn" to bodyIdx?.let { c.getColumnName(it) },
                        "cardMatched" to matched,
                    )
                }
            } catch (e: Exception) {
                mapOf("uri" to uri, "ok" to false, "error" to "${e.javaClass.simpleName}: ${e.message}")
            }
        }
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
