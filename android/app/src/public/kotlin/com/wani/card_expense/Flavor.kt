package com.wani.card_expense

import android.content.Context

/** 일반판: 문자 권한을 쓰지 않는다. (Play Protect 차단 회피) */
object Flavor {
    val smsPermissions: Array<String> = emptyArray()

    fun readInbox(ctx: Context, days: Int): Map<String, Any>? = null

    fun diagnoseStores(ctx: Context): List<Map<String, Any?>>? = null
}
