package com.wani.card_expense

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** REQ-61: 저장소마다 다른 발신번호 형식이 모두 일치로 판정되는지 */
class SenderMatchTest {
    private val conf = "1588-1600"

    @Test
    fun sameNumberInEveryFormat() {
        for (a in listOf(
            "1588-1600", "15881600", " 1588-1600 ", "+8215881600", "+82 1588-1600", "82-1588-1600",
            "0015881600", "008215881600", "015881600", "#15881600", "tel:+82-1588-1600",
            "sip:+8215881600@ims.mnc008.mcc450.3gppnetwork.org;user=phone", "15881600;phone-context=x1",
        )) {
            assertTrue(a, SenderMatch.matches(a, conf))
            assertTrue(a, SenderMatch.matches(conf, a))
        }
        assertTrue(SenderMatch.matches("+821012345678", "010-1234-5678"))
    }

    @Test
    fun otherNumbersDoNotMatch() {
        for (a in listOf("15881688", "1588-1601", "NH농협카드", "", "1600", "sip:bot@rcs.mnc008.mcc450.15881600.org")) {
            assertFalse(a, SenderMatch.matches(a, conf))
        }
        assertFalse(SenderMatch.matches(null, conf))
        assertFalse(SenderMatch.matches("15881600", null))
    }
}
