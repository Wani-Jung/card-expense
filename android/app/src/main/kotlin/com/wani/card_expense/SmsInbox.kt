package com.wani.card_expense

import android.Manifest
import android.content.Context
import android.net.Uri

/** 문자 권한으로 실시간 수신(SmsReceiver)과 지난 문자 불러오기를 한다. */
object SmsInbox {
    private const val MMS_FROM = 137 // content://mms/{id}/addr 의 type: 보낸 사람

    val smsPermissions = arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS)

    /**
     * 문자함에서 [fromMs, toMs) 기간의 카드 승인·취소 후보 문자를 읽는다. READ_SMS 권한 필요.
     * SMS·MMS·RCS 후보 저장소 모두 같은 조건(REQ-66, 실시간 수신 CardSms.handle 과 같음):
     * 본문에 '승인'·'취소'가 있고 (발신번호 일치 **또는** 본문에 카드번호+승인·취소). 최종 판정(끝 4자리)은 Dart parseSms.
     * [Web발신] 장문(LMS)은 MMS 테이블, 삼성 RCS 기업메시지는 SMS/MMS 밖 저장소(im/chat 등)에 있다.
     * 문자함 전체를 몇 건 봤는지는 돌려주지 않는다(REQ-66 B: 어디에도 표시 금지). 진단은 찾은 문자의 발신번호 일치 여부·주소 형식만.
     */
    fun readInbox(ctx: Context, fromMs: Long, toMs: Long): Map<String, Any> {
        val sender = CardSms.sender(ctx)
        val digits = CardSms.digits(ctx)
        val items = ArrayList<Map<String, Any>>()
        val cr = ctx.contentResolver
        val addrSamples = LinkedHashSet<String>()

        /** 후보면 item 을 돌려준다 (bySender = 발신번호로 맞았는지, 진단용) */
        fun candidate(store: String, address: String?, body: String, ts: Long): Map<String, Any>? {
            if (!CardSms.isApprovalText(body)) return null
            val bySender = CardSms.senderMatches(address, sender)
            if (!bySender && !CardSms.hasCardApproval(body, digits)) return null
            if (addrSamples.size < MAX_SAMPLES) addrSamples.add("$store: ${address ?: "(없음)"}")
            return mapOf("body" to body, "ts" to ts, "bySender" to bySender)
        }

        cr.query(
            Uri.parse("content://sms"),
            arrayOf("address", "body", "date"),
            "date >= ? AND date < ?",
            arrayOf(fromMs.toString(), toMs.toString()),
            "date ASC",
        )?.use { c ->
            while (c.moveToNext()) {
                val body = c.getString(1) ?: continue
                candidate("sms", c.getString(0), body, c.getLong(2))?.let { items.add(it) }
            }
        }

        cr.query(
            Uri.parse("content://mms"),
            arrayOf("_id", "date"),
            "date >= ? AND date < ?",
            arrayOf((fromMs / 1000).toString(), (toMs / 1000).toString()), // MMS date 는 초 단위
            "date ASC",
        )?.use { c ->
            while (c.moveToNext()) {
                val id = c.getLong(0)
                val body = mmsText(ctx, id)
                if (body.isEmpty()) continue
                candidate("mms", mmsFrom(ctx, id), body, c.getLong(1) * 1000)?.let { items.add(it) }
            }
        }

        // 삼성 RCS 기업메시지는 SMS/MMS 테이블에 없을 수 있다. 열리는 저장소가 있으면 거기서도 같은 조건으로 찾는다.
        for (uri in OTHER_STORES) scanOther(ctx, uri, fromMs, toMs) { address, body, ts ->
            candidate(uri.removePrefix("content://").substringBefore('?'), address, body, ts)?.let { items.add(it) }
        }

        return mapOf("items" to items, "addrSamples" to addrSamples.toList())
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

    /** 열리는 저장소면 기간 안의 행마다 (주소, 본문, 시각)을 [each] 로 넘긴다. 막혀 있거나 본문 컬럼이 없으면 아무것도 안 함. 예외는 삼킨다. */
    private fun scanOther(ctx: Context, uri: String, fromMs: Long, toMs: Long, each: (String?, String, Long) -> Unit) {
        try {
            ctx.contentResolver.query(Uri.parse(uri), null, null, null, null)?.use { c ->
                val bodyIdx = BODY_COLUMNS.map { c.getColumnIndex(it) }.firstOrNull { it >= 0 } ?: return
                // 날짜 칸이 없는 저장소는 기간을 걸 수 없으니 통째로 건너뛴다 (REQ-69: 예전엔 '지금'으로 쳐서 기간과 상관없이 다 읽었다)
                val dateIdx = DATE_COLUMNS.map { c.getColumnIndex(it) }.firstOrNull { it >= 0 } ?: return
                val addrIdx = ADDRESS_COLUMNS.map { c.getColumnIndex(it) }.firstOrNull { it >= 0 }
                var rows = 0
                while (c.moveToNext() && rows < MAX_ROWS) {
                    rows++
                    val body = try { c.getString(bodyIdx) } catch (_: Exception) { null } ?: continue
                    val ts = InboxDate.toMillis(try { c.getLong(dateIdx) } catch (_: Exception) { null })
                    if (ts == null || !InboxDate.inRange(ts, fromMs, toMs)) continue
                    val address = addrIdx?.let { try { c.getString(it) } catch (_: Exception) { null } }
                    each(address, body, ts)
                }
            }
        } catch (_: Exception) {
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
