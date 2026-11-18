package cloud.shoplive.onboarding.data

import cloud.shoplive.onboarding.integration.ShopliveWebBridge
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * What the hybrid bridge accepts from the web page (SMV-1922 contract 3, cases S09 /
 * S10): one campaignKey string. Null, empty and whitespace-only are ignored. The same
 * vectors run against the iOS WebBridgeInput.
 */
class WebBridgeInputTest {

    @Test
    fun nullIsIgnored() {
        assertNull(ShopliveWebBridge.campaignKeyFrom(null))
    }

    @Test
    fun emptyIsIgnored() {
        assertNull(ShopliveWebBridge.campaignKeyFrom(""))
    }

    @Test
    fun whitespaceOnlyIsIgnored() {
        listOf(" ", "   ", "\t", "\n", " \t\r\n ").forEach { blank ->
            assertNull("\"$blank\" must be ignored", ShopliveWebBridge.campaignKeyFrom(blank))
        }
    }

    @Test
    fun aKeyIsPassedOnTrimmed() {
        assertEquals("abc123", ShopliveWebBridge.campaignKeyFrom("abc123"))
        assertEquals("abc123", ShopliveWebBridge.campaignKeyFrom("  abc123\n"))
    }

    /**
     * Android's JS -> Java conversion turns some non-strings into strings before they
     * reach us. There is no key-format rule to reject them by, so they are passed on
     * and a bad key ends in the SDK's error path (S10 — measured, not decided here).
     */
    @Test
    fun convertedNonStringsArePassedOnAsText() {
        assertEquals("123", ShopliveWebBridge.campaignKeyFrom("123"))
        assertEquals("[object Object]", ShopliveWebBridge.campaignKeyFrom("[object Object]"))
    }

    @Test
    fun interfaceNameMatchesTheGuide() {
        assertEquals("ShopLiveAppInterface", ShopliveWebBridge.NAME)
    }
}
