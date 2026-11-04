//
//  MissionID.swift
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  The one identifier for a mission (SMV-1922 §1 ① ②). Branching and completion use this — never a
//  number. The number on a card is derived from the order below, in one place.
//
//  ★ Foundation only. iOS/scripts/logic_check.sh compiles this file with swiftc on the Mac to check
//    the migration table — do not import UIKit or the SDK here.
//

import Foundation

/// - `rawValue` is the **stored format**, shared with Android (`demo.completedMissionIds`). Never
///   rename a raw value — a renamed value reads back as unknown and the completion is dropped.
/// - Declaration order **is** the display order: `MissionCatalog` numbers cards `index + 1`, matching
///   the guide's mission map (guide L127-143). To renumber, reorder the cases — nothing else.
enum MissionID: String, CaseIterable {
    case player      // 1 · full-screen player
    case nudge       // 2 · nudge preview
    case pip         // 3 · PIP
    case deeplink    // 4 · deep link
    case user        // 5 · user info
    case events      // 6 · events · products · coupons
    case inline      // 7 · inline preview (native · hybrid)
    case ui          // 8 · UI customization
    case studio      // 9 · broadcasting
}

// MARK: - Stored record (pure — the I/O lives in MissionProgress)

extension MissionID {

    /// Before SMV-1922 the record stored mission **numbers** 1…8. Each maps to the mission with the
    /// same feature. `nudge` is new and has no old number, so it starts not-done (AC-3).
    static let legacyNumbers: [Int: MissionID] = [
        1: .player, 2: .deeplink, 3: .user, 4: .inline, 5: .pip, 6: .events, 7: .ui, 8: .studio,
    ]

    /// Decodes the value stored under the identifier key.
    ///
    /// Anything that names no mission is returned in `dropped` for the caller to log — it is never
    /// attached to a mission (a wrong ✓ is worse than a missing one, AC-2).
    static func decodeStored(_ stored: Any?) -> (ids: Set<MissionID>, dropped: [String]) {
        guard let stored else { return ([], []) }
        guard let values = stored as? [Any] else { return ([], [String(describing: stored)]) }

        var ids = Set<MissionID>()
        var dropped: [String] = []
        for value in values {
            if let raw = value as? String, let id = MissionID(rawValue: raw) {
                ids.insert(id)
            } else {
                dropped.append(String(describing: value))
            }
        }
        return (ids, dropped)
    }

    /// Folds the legacy number record into `current`.
    ///
    /// The caller writes `merged` to the identifier key **first** and deletes the legacy key **after**.
    /// If the app dies in between, the next launch runs this again and reaches the same set — the union
    /// makes a re-run a no-op, so no version flag is needed (S01).
    static func migrateLegacy(_ legacy: Any?, into current: Set<MissionID>) -> LegacyMigration {
        guard let legacy else { return .absent }
        guard let values = legacy as? [Any] else {
            return .unreadable(found: String(describing: legacy))
        }

        var merged = current
        var dropped: [String] = []
        for value in values {
            if let number = legacyNumber(value), let id = legacyNumbers[number] {
                merged.insert(id)
            } else {
                dropped.append(String(describing: value))   // 0, negative, 9+, non-integer (S02)
            }
        }
        return .migrated(merged: merged, dropped: dropped)
    }

    /// A stored value as an old mission number. UserDefaults hands back NSNumber, and `as? Int` alone
    /// would also accept a Bool (CFBoolean → 1) — neither a Bool nor a value with a fractional part is a
    /// mission number (F6).
    private static func legacyNumber(_ value: Any) -> Int? {
        guard let number = value as? NSNumber else { return nil }
        guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return Int(exactly: number.doubleValue)
    }
}

// MARK: - Completion rule for an in-App PIP entry (pure — MissionProgress applies it)

extension MissionID {

    /// Whether an in-App PIP entry from `player` completes the PIP mission (§1 ⑤ · E1 · S26).
    ///
    /// The nudge's own small window is the nudge, not "keep watching in PIP" (§1 ⑤: "a PIP entry that is
    /// not a nudge session"):
    ///   · `isNudgePlayer` — the sender is a nudge player, whatever mission is running now (X4);
    ///   · while the nudge mission runs, an entry from its owner — or before the owner is registered,
    ///     since the mission is recorded before the nudge starts and a signal can arrive during `play()`.
    /// Same condition as Android `MissionProgress.creditFor` (CG-4.4).
    static func pipEntryCompletesPip(activeMission: MissionID?, owner: AnyObject?, player: AnyObject,
                                     isNudgePlayer: Bool) -> Bool {
        if isNudgePlayer { return false }
        guard activeMission == .nudge else { return true }
        guard let owner else { return false }
        return player !== owner
    }
}

// MARK: - Nudge re-show rule (pure — NudgeProductViewController applies it)

extension MissionID {

    /// Whether the nudge screen may start its nudge now. The first appearance follows the viewer's card
    /// tap, so the session on screen is replaced as with any card. A later appearance is automatic and
    /// must not close a session the viewer is still watching (same rule as Android X2).
    static func nudgeMayStart(isFirstAppearance: Bool, otherSessionInProgress: Bool) -> Bool {
        isFirstAppearance || !otherSessionInProgress
    }
}

/// What to do with the legacy record. One case per situation (CG-6.1).
enum LegacyMigration: Equatable {
    /// No legacy key (fresh install, or already migrated).
    case absent
    /// The legacy key holds something that is not a list. Leave it in place and retry next launch.
    case unreadable(found: String)
    /// Write `merged` to the identifier key, then delete the legacy key. `dropped` is for the log.
    case migrated(merged: Set<MissionID>, dropped: [String])
}
