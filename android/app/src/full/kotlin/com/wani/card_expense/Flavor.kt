package com.wani.card_expense

import android.Manifest
import android.content.Context
import android.net.Uri

/** 전용판: 문자 권한으로 실시간 수신(SmsReceiver)과 지난 문자 불러오기를 한다. */
object Flavor {
    private const val MMS_FROM = 137 // content://mms/{id}/addr 의 type: 보낸 사람

    val smsPermissions = arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS)

    /**
     * 문자함에서 [fromMs, toMs) 기간에 발신번호가 일치하거나 본문에 카드번호+승인(취소)이 있는 문자를 읽는다.
     * (실시간 수신 CardSms.handle 과 같은 조건, REQ-61) READ_SMS 권한 필요.
     * [Web발신] 장문(LMS)은 MMS 테이블에 저장되므로 SMS·MMS 를 둘 다 본다.
     * 최종 판정(카드번호 끝 4자리)은 Dart 쪽 parseSms 가 한다.
     * 진단용(기본 화면엔 안 보임): 발신번호 일치 건수, 카드 승인 문자의 저장소별 주소 형식 몇 개.
     */
    fun readInbox(ctx: Context, fromMs: Long, toMs: Long): Map<String, Any>? {
        val sender = CardSms.sender(ctx)
        val digits = CardSms.digits(ctx)
        val items = ArrayList<Map<String, Any>>()
        val cr = ctx.contentResolver
        var senderMatched = 0
        val addrSamples = LinkedHashSet<String>()
        fun keep(store: String, address: String?, body: String): Boolean {
            val bySender = CardSms.senderMatches(address, sender)
            val byCard = CardSms.hasCardApproval(body, digits)
            if (bySender) senderMatched++
            if (byCard && addrSamples.size < MAX_SAMPLES) addrSamples.add("$store: ${address ?: "(없음)"}")
            return bySender || byCard
        }

        var smsScanned = 0
        cr.query(
            Uri.parse("content://sms"),
            arrayOf("address", "body", "date"),
            "date >= ? AND date < ?",
            arrayOf(fromMs.toString(), toMs.toString()),
            "date ASC",
        )?.use { c ->
            while (c.moveToNext()) {
                smsScanned++
                val body = c.getString(1) ?: continue
                if (!keep("sms", c.getString(0), body)) continue
                items.add(mapOf("body" to body, "ts" to c.getLong(2)))
            }
        }

        var mmsScanned = 0
        cr.query(
            Uri.parse("content://mms"),
            arrayOf("_id", "date"),
            "date >= ? AND date < ?",
            arrayOf((fromMs / 1000).toString(), (toMs / 1000).toString()), // MMS date 는 초 단위
            "date ASC",
        )?.use { c ->
            while (c.moveToNext()) {
                mmsScanned++
                val id = c.getLong(0)
                val body = mmsText(ctx, id)
                if (body.isEmpty()) continue
                if (!keep("mms", mmsFrom(ctx, id), body)) continue
                items.add(mapOf("body" to body, "ts" to c.getLong(1) * 1000))
            }
        }

        // 삼성 RCS 기업메시지는 SMS/MMS 테이블에 없을 수 있다. 열리는 저장소가 있으면 거기서도 찾는다.
        var otherScanned = 0
        var otherMatched = 0
        for (uri in OTHER_STORES) {
            val r = scanOther(ctx, uri, fromMs, toMs, digits) ?: continue
            otherScanned += r.scanned
            otherMatched += r.items.size
            items.addAll(r.items)
            for (a in r.addresses) if (addrSamples.size < MAX_SAMPLES) addrSamples.add("${uri.removePrefix("content://")}: $a")
        }

        return mapOf(
            "items" to items,
            "smsScanned" to smsScanned,
            "mmsScanned" to mmsScanned,
            "otherScanned" to otherScanned,
            "otherMatched" to otherMatched,
            "senderMatched" to senderMatched,
            "addrSamples" to addrSamples.toList(),
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
    private val ADDRESS_COLUMNS = listOf("address", "sender", "from_address", "remote_uri", "recipient_ids", "conversation_id")
    private const val MAX_ROWS = 50000
    private const val MAX_SAMPLES = 8

    private class OtherScan(val scanned: Int, val items: List<Map<String, Any>>, val addresses: Set<String>)

    /** 열리면 카드번호+승인 문자를 찾아 돌려준다. 막혀 있거나 본문 컬럼이 없으면 null. 예외는 삼킨다. */
    private fun scanOther(ctx: Context, uri: String, fromMs: Long, toMs: Long, digits: String?): OtherScan? = try {
        ctx.contentResolver.query(Uri.parse(uri), null, null, null, null)?.use { c ->
            val bodyIdx = BODY_COLUMNS.map { c.getColumnIndex(it) }.firstOrNull { it >= 0 } ?: return@use null
            val dateIdx = DATE_COLUMNS.map { c.getColumnIndex(it) }.firstOrNull { it >= 0 }
            val addrIdx = ADDRESS_COLUMNS.map { c.getColumnIndex(it) }.firstOrNull { it >= 0 }
            var scanned = 0
            val items = ArrayList<Map<String, Any>>()
            val addresses = LinkedHashSet<String>()
            while (c.moveToNext() && scanned < MAX_ROWS) {
                scanned++
                val body = try { c.getString(bodyIdx) } catch (_: Exception) { null } ?: continue
                if (!CardSms.hasCardApproval(body, digits)) continue
                val ts = dateIdx?.let { toMillis(c.getLong(it)) } ?: System.currentTimeMillis()
                if (ts < fromMs || ts >= toMs) continue
                items.add(mapOf("body" to body, "ts" to ts))
                if (addresses.size < MAX_SAMPLES) {
                    val a = addrIdx?.let { try { c.getString(it) } catch (_: Exception) { null } }
                    addresses.add(a ?: "(주소 칸 없음)")
                }
            }
            OtherScan(scanned, items, addresses)
        }
    } catch (_: Exception) {
        null
    }

    /** 날짜 컬럼이 초 단위면 밀리초로. (2001년 이후 밀리초 값은 1e12 이상) */
    private fun toMillis(v: Long) = if (v in 1 until 100_000_000_000L) v * 1000 else v

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
