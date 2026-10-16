package cloud.shoplive.onboarding.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The same cases as Flutter `test/qr_credentials_test.dart`. */
class QrCredentialsTest {

    @Test
    fun nativeTestAppQr() {
        val qr = QrCredentials.parse("https://dev.shoplive.cloud/qr?ak=AK123&ck=CK456&title=My%20Live")!!
        assertEquals("AK123", qr.accessKey)
        assertEquals("CK456", qr.campaignKey)
        assertEquals("My Live", qr.title)
        assertEquals(listOf("accessKey", "campaignKey"), qr.filledFields)
    }

    @Test
    fun schemeHostAndPathAreIgnored() {
        assertTrue(QrCredentials.parse("shoplive://x/y?ck=C&ak=A")!!.hasKeyPair)
    }

    @Test
    fun halfPairIsNotUsed() {
        assertNull(QrCredentials.parse("https://a.b/?ak=A"))
        val qr = QrCredentials.parse("https://a.b/?ck=C&st=TOKEN")!!
        assertFalse(qr.hasKeyPair)
        assertEquals("TOKEN", qr.streamToken)
    }

    @Test
    fun userJwtAlone() {
        assertEquals("eyJ.x.y", QrCredentials.parse("https://a.b/?userjwt=eyJ.x.y")!!.userJwt)
    }

    @Test
    fun streamTokenKey() {
        val qr = QrCredentials.parse("https://a.b/?ak=A&ck=C&st=eyJst")!!
        assertEquals(listOf("accessKey", "campaignKey", "streamToken"), qr.filledFields)
    }

    @Test
    fun rejectsBlankNonUrlAndKeyless() {
        listOf(null, "", "   ", "hello world", "https://a.b/", "https://a.b/?ak=&ck=", "https://a.b/?x=1")
            .forEach { assertNull(it, QrCredentials.parse(it)) }
    }

    @Test
    fun trimsAndDecodes() {
        assertEquals("A", QrCredentials.parse(" https://a.b/?ak=%20A%20&ck=C ")!!.accessKey)
    }
}
