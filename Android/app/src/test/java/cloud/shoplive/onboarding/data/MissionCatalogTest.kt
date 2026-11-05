package cloud.shoplive.onboarding.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * The catalog is the only source of card order, display numbers and the total
 * (SMV-1922 contract 1). The order has to match the integration guide's mission map.
 */
class MissionCatalogTest {

    @Test
    fun orderMatchesTheGuideMissionMap() {
        assertEquals(
            listOf(
                MissionId.PLAYER,
                MissionId.NUDGE,
                MissionId.PIP,
                MissionId.DEEPLINK,
                MissionId.USER,
                MissionId.EVENTS,
                MissionId.INLINE,
                MissionId.UI,
                MissionId.STUDIO,
            ),
            MISSIONS.map { it.id },
        )
    }

    @Test
    fun everyIdentifierHasExactlyOneCard() {
        assertEquals(MissionId.entries.size, MISSIONS.size)
        assertEquals(MissionId.entries.toSet(), MISSIONS.map { it.id }.toSet())
    }

    /** Shared with iOS and stored on disk — renaming one silently drops progress. */
    @Test
    fun rawValuesAreFixed() {
        assertEquals(
            listOf("player", "nudge", "pip", "deeplink", "user", "events", "inline", "ui", "studio"),
            MissionId.entries.map { it.raw },
        )
    }

    @Test
    fun displayNumberIsCatalogPositionPlusOne() {
        assertEquals(1, MissionId.PLAYER.displayNumber)
        assertEquals(2, MissionId.NUDGE.displayNumber)
        assertEquals(3, MissionId.PIP.displayNumber)
        assertEquals(4, MissionId.DEEPLINK.displayNumber)
        assertEquals(5, MissionId.USER.displayNumber)
        assertEquals(6, MissionId.EVENTS.displayNumber)
        assertEquals(7, MissionId.INLINE.displayNumber)
        assertEquals(8, MissionId.UI.displayNumber)
        assertEquals(9, MissionId.STUDIO.displayNumber)
    }

    @Test
    fun inlineCardNamesBothWays() {
        val inline = MISSIONS.single { it.id == MissionId.INLINE }
        assertEquals(2, inline.sourcePaths.size)
    }

    /** The path on a card is the only bridge to the sources, so it must exist. */
    @Test
    fun everySourcePathExists() {
        // Unit tests run with the module directory (Android/app) as working dir;
        // card paths are relative to the Android/ project root.
        val projectRoot = File("..").canonicalFile
        val missing = MISSIONS.flatMap { it.sourcePaths }
            .filterNot { File(projectRoot, it).isFile }
        assertTrue("missing source files: $missing", missing.isEmpty())
        assertTrue(MISSIONS.all { it.sourcePaths.isNotEmpty() })
    }
}
