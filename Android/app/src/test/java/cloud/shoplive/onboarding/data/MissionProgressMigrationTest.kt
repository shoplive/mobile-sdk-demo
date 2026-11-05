package cloud.shoplive.onboarding.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Old progress (mission numbers under "doneMissions") moves to identifiers under
 * "demo.completedMissionIds" (SMV-1922 contract 2, cases S01 / S02 / U02 / U04).
 */
class MissionProgressMigrationTest {

    private fun ids(vararg raw: String): Set<MissionId> = raw.map { MissionId.fromRaw(it)!! }.toSet()

    @Test
    fun legacyTableMapsEveryOldNumberToTheSameFeature() {
        val result = MissionProgress.migrate(
            legacy = setOf("1", "2", "3", "4", "5", "6", "7", "8"),
            stored = null,
        )
        assertEquals(
            ids("player", "deeplink", "user", "inline", "pip", "events", "ui", "studio"),
            result.ids,
        )
        assertTrue(result.dropped.isEmpty())
        assertTrue(result.needsWrite)
    }

    /** The user-approved old -> new display-number table, composed through the catalog. */
    @Test
    fun oldNumbersLandOnTheApprovedNewNumbers() {
        val expected = mapOf(1 to 1, 2 to 4, 3 to 5, 4 to 7, 5 to 3, 6 to 6, 7 to 8, 8 to 9)
        val actual = expected.keys.associateWith { old ->
            MissionProgress.migrate(legacy = setOf(old.toString()), stored = null)
                .ids.single().displayNumber
        }
        assertEquals(expected, actual)
    }

    @Test
    fun nudgeIsNeverMigratedAndStartsUndone() {
        val result = MissionProgress.migrate(
            legacy = (0..20).map(Int::toString).toSet(),
            stored = null,
        )
        assertFalse(MissionId.NUDGE in result.ids)
    }

    /** Running it again over its own output changes nothing (structurally idempotent). */
    @Test
    fun rerunIsANoOp() {
        val first = MissionProgress.migrate(legacy = setOf("2", "5", "8"), stored = null)
        val second = MissionProgress.migrate(legacy = null, stored = first.storedValues)
        assertEquals(first.ids, second.ids)
        assertFalse(second.needsWrite)
    }

    /** Killed after writing the new key but before deleting the old one: same result. */
    @Test
    fun oldAndNewKeysTogetherConvergeToTheUnion() {
        val interrupted = MissionProgress.migrate(legacy = setOf("1", "5"), stored = setOf("player", "pip"))
        assertEquals(ids("player", "pip"), interrupted.ids)

        val mixed = MissionProgress.migrate(legacy = setOf("3"), stored = setOf("nudge"))
        assertEquals(ids("user", "nudge"), mixed.ids)
    }

    @Test
    fun unknownOldNumbersAreDroppedNotGuessed() {
        val result = MissionProgress.migrate(
            legacy = setOf("0", "-1", "9", "abc", "", "2"),
            stored = null,
        )
        assertEquals(ids("deeplink"), result.ids)
        assertEquals(listOf("", "-1", "0", "9", "abc"), result.dropped.sorted())
        assertTrue(result.needsWrite)
    }

    @Test
    fun unknownRawValuesInTheNewKeyAreDropped() {
        val result = MissionProgress.migrate(legacy = null, stored = setOf("player", "bogus", "PLAYER"))
        assertEquals(ids("player"), result.ids)
        assertEquals(listOf("PLAYER", "bogus"), result.dropped.sorted())
        assertTrue(result.needsWrite)
    }

    @Test
    fun freshInstallIsANoOp() {
        val result = MissionProgress.migrate(legacy = null, stored = null)
        assertTrue(result.ids.isEmpty())
        assertFalse(result.needsWrite)
    }

    /** Duplicates and order do not matter — it is a set. */
    @Test
    fun duplicatesCollapse() {
        val result = MissionProgress.migrate(legacy = setOf("1", "01"), stored = setOf("player"))
        assertEquals(ids("player"), result.ids)
    }
}
