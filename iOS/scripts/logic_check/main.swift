//
//  logic_check/main.swift — host-side checks for the Foundation-only logic (SMV-1922 S37 · M6)
//
//  The iOS project has no XCTest target, so the pure parts are kept in files that import only
//  Foundation and are compiled here with swiftc on the Mac:
//    · ShopliveOnboardingDemo/Support/MissionID.swift        — identifiers · legacy record migration
//    · ShopliveIntegration/WebBridgeInput.swift              — hybrid bridge input · JS literal
//  The vectors mirror the Android JVM tests (MissionProgressMigrationTest · WebBridgeInputTest).
//  Run through scripts/logic_check.sh. Exit 0 = all pass.
//

import Foundation

var failures = 0
var passes = 0

func check(_ condition: Bool, _ name: String, _ detail: @autoclosure () -> String = "") {
    if condition {
        passes += 1
        print("PASS  \(name)")
    } else {
        failures += 1
        print("FAIL  \(name) \(detail())")
    }
}

// MARK: - MissionID · stored identifiers

check(MissionID.allCases.map(\.rawValue) == ["player", "preview", "pip", "deeplink", "user", "events", "inline", "ui", "studio"],
      "raw values fixed and in guide order (S01 · L1)",
      "\(MissionID.allCases.map(\.rawValue))")

let expectedLegacy: [Int: MissionID] = [1: .player, 2: .deeplink, 3: .user, 4: .inline, 5: .pip, 6: .events, 7: .ui, 8: .studio]
check(MissionID.legacyNumbers == expectedLegacy, "legacy number table matches §1 ②")

// Composed result the user decided: old number → new display number (display number = declaration index + 1).
let expectedDisplay: [Int: Int] = [1: 1, 2: 4, 3: 5, 4: 7, 5: 3, 6: 6, 7: 8, 8: 9]
for (old, newNumber) in expectedDisplay.sorted(by: { $0.key < $1.key }) {
    let id = MissionID.legacyNumbers[old]
    let display = id.flatMap { MissionID.allCases.firstIndex(of: $0) }.map { $0 + 1 }
    check(display == newNumber, "old \(old) → display \(newNumber)", "got \(String(describing: display))")
}
check(!MissionID.legacyNumbers.values.contains(.preview), "preview has no legacy number (AC-3 — starts not done)")

let decodedNil = MissionID.decodeStored(nil)
check(decodedNil.ids.isEmpty && decodedNil.dropped.isEmpty, "decode: nothing stored → empty, nothing dropped")

let decodedMixed = MissionID.decodeStored(["pip", "future_mission", "player", 7] as [Any])
check(decodedMixed.ids == [.pip, .player], "decode: unknown raw dropped, known kept (U02)", "\(decodedMixed)")
check(decodedMixed.dropped.count == 2, "decode: dropped values reported for the log", "\(decodedMixed.dropped)")

let decodedWrongType = MissionID.decodeStored("player")
check(decodedWrongType.ids.isEmpty && decodedWrongType.dropped.count == 1, "decode: non-array stored value dropped, not crashed")

// MARK: - MissionID · legacy migration

check(MissionID.migrateLegacy(nil, into: []) == .absent, "migrate: fresh install (no legacy key) → no-op")

if case .unreadable = MissionID.migrateLegacy("1,2,3", into: []) {
    check(true, "migrate: legacy key that is not an array → unreadable (keep key, retry next launch)")
} else {
    check(false, "migrate: legacy key that is not an array → unreadable (keep key, retry next launch)")
}

let all8 = MissionID.migrateLegacy([1, 2, 3, 4, 5, 6, 7, 8] as [Any], into: [])
check(all8 == .migrated(merged: Set(MissionID.allCases).subtracting([.preview]), dropped: []),
      "migrate: 1…8 → every mission except preview", "\(all8)")

let partial = MissionID.migrateLegacy([2, 5] as [Any], into: [])
check(partial == .migrated(merged: [.deeplink, .pip], dropped: []),
      "migrate: old 2 (deep link) · old 5 (PIP) → deeplink · pip (manual scenario 12)", "\(partial)")

let unknown = MissionID.migrateLegacy([0, -1, 9, 42, "3", 3] as [Any], into: [])
if case .migrated(let merged, let dropped) = unknown {
    check(merged == [.user], "migrate: values outside the table attach to no mission (S02)", "\(merged)")
    check(dropped.count == 5, "migrate: every unknown value reported for the log (S02)", "\(dropped)")
} else {
    check(false, "migrate: values outside the table", "\(unknown)")
}

let union = MissionID.migrateLegacy([1] as [Any], into: [.preview, .studio])
check(union == .migrated(merged: [.player, .preview, .studio], dropped: []),
      "migrate: union with records already under the new key", "\(union)")

// Idempotence — simulate the store the way MissionProgress applies the outcome:
// write merged to the new key, THEN delete the legacy key.
func apply(_ store: inout [String: Any]) {
    let current = MissionID.decodeStored(store["new"]).ids
    switch MissionID.migrateLegacy(store["legacy"], into: current) {
    case .absent, .unreadable:
        break
    case .migrated(let merged, _):
        store["new"] = merged.map(\.rawValue).sorted()
        store["legacy"] = nil
    }
}
var store: [String: Any] = ["legacy": [2, 5, 9]]
apply(&store)
let first = MissionID.decodeStored(store["new"]).ids
apply(&store)
let second = MissionID.decodeStored(store["new"]).ids
check(first == [.deeplink, .pip] && first == second && store["legacy"] == nil,
      "migrate: second run is a no-op (S01)", "\(first) / \(second)")

// Killed between "write new key" and "delete legacy key": the next launch re-runs and converges.
var crashed: [String: Any] = ["legacy": [2, 5], "new": ["deeplink", "pip", "preview"]]
apply(&crashed)
check(MissionID.decodeStored(crashed["new"]).ids == [.deeplink, .pip, .preview] && crashed["legacy"] == nil,
      "migrate: interrupted run converges to the same result (U04 ①)")

// MARK: - MissionID · renamed raw value (mission 2, SMV-1922 2026-11-17 · same as Android MissionProgressMigrationTest)

let renamedRecord = MissionID.decodeStored([MissionID.legacyPreviewRawValue, "pip"] as [Any])
check(renamedRecord.ids == [.preview, .pip] && renamedRecord.dropped.isEmpty
        && renamedRecord.renamed == [MissionID.legacyPreviewRawValue],
      "renamed: old mission 2 raw value carries over to .preview", "\(renamedRecord)")
let rewritten = MissionID.decodeStored(renamedRecord.ids.map(\.rawValue).sorted())
check(rewritten.ids == renamedRecord.ids && rewritten.renamed.isEmpty && rewritten.dropped.isEmpty,
      "renamed: the rewritten record reads back the same, nothing left to rename", "\(rewritten)")
let renamedWithCurrent = MissionID.decodeStored([MissionID.legacyPreviewRawValue, "preview"] as [Any])
check(renamedWithCurrent.ids == [.preview] && renamedWithCurrent.dropped.isEmpty,
      "renamed: old and current raw value together → one .preview", "\(renamedWithCurrent)")

// MARK: - MissionID · PIP entry vs. the preview's own small window (S26 · same as Android creditFor)

let previewPlayer = NSObject()
let otherPlayer = NSObject()
check(MissionID.pipEntryCompletesPip(activeMission: nil, owner: nil, player: otherPlayer, isPreviewPlayer: false),
      "pip rule: no mission running → PIP entry completes pip")
check(MissionID.pipEntryCompletesPip(activeMission: .player, owner: otherPlayer, player: otherPlayer, isPreviewPlayer: false),
      "pip rule: card player entering PIP → completes pip")
check(MissionID.pipEntryCompletesPip(activeMission: .player, owner: nil, player: otherPlayer, isPreviewPlayer: false),
      "pip rule: non-preview mission without owner → completes pip")
check(!MissionID.pipEntryCompletesPip(activeMission: .preview, owner: previewPlayer, player: previewPlayer, isPreviewPlayer: false),
      "pip rule: the preview's own small window → not pip (E1)")
check(!MissionID.pipEntryCompletesPip(activeMission: .preview, owner: nil, player: otherPlayer, isPreviewPlayer: false),
      "pip rule: preview running, owner not registered yet → not pip (signal during play())")
check(MissionID.pipEntryCompletesPip(activeMission: .preview, owner: previewPlayer, player: otherPlayer, isPreviewPlayer: false),
      "pip rule: another player entering PIP while the preview runs → completes pip")

check(!MissionID.pipEntryCompletesPip(activeMission: .player, owner: otherPlayer, player: previewPlayer, isPreviewPlayer: true),
      "pip rule: a preview player entering PIP after another mission started → not pip (X4)")
check(!MissionID.pipEntryCompletesPip(activeMission: nil, owner: nil, player: previewPlayer, isPreviewPlayer: true),
      "pip rule: a preview player with no mission running → not pip (X4)")

// MARK: - Preview re-show vs. a session in progress (Android X2)

check(MissionID.previewMayStart(isFirstAppearance: true, otherSessionInProgress: true),
      "preview: first appearance (card tap) with a session in progress → start (replaces it)")
check(!MissionID.previewMayStart(isFirstAppearance: false, otherSessionInProgress: true),
      "preview: later appearance with a session in progress → skipped")
check(MissionID.previewMayStart(isFirstAppearance: false, otherSessionInProgress: false),
      "preview: later appearance with nothing in progress → start")

// MARK: - MissionID · legacy values that only look like numbers (F6)

let nsVectors = MissionID.migrateLegacy([NSNumber(value: true), NSNumber(value: 2.0), NSNumber(value: 2.5)] as [Any], into: [])
if case .migrated(let merged, let dropped) = nsVectors {
    check(merged == [.deeplink], "migrate: NSNumber 2.0 → deeplink (an integral value)", "\(merged)")
    check(dropped.count == 2, "migrate: NSNumber Bool (true) and 2.5 dropped, not attached", "\(dropped)")
} else {
    check(false, "migrate: NSNumber vectors", "\(nsVectors)")
}
let swiftBool = MissionID.migrateLegacy([true, 3] as [Any], into: [])
check(swiftBool == .migrated(merged: [.user], dropped: ["true"]), "migrate: Swift Bool dropped, 3 kept", "\(swiftBool)")

// MARK: - WebBridgeInput · campaignKey from the web

func accepted(_ body: Any?) -> String? {
    if case .accepted(let key) = WebBridgeInput.campaignKey(from: body) { return key }
    return nil
}

check(accepted(nil) == nil, "bridge: nil body ignored (S09)")
check(accepted(NSNull()) == nil, "bridge: JS null (NSNull) ignored (S09)")
check(accepted("") == nil, "bridge: empty string ignored (S09)")
check(accepted("   \n\t ") == nil, "bridge: whitespace-only ignored (S09)")
check(accepted("ABC123") == "ABC123", "bridge: plain key accepted")
check(accepted("  ABC123 \n") == "ABC123", "bridge: surrounding whitespace trimmed")
check(accepted(NSNumber(value: 123)) == nil, "bridge: number ignored (S10)")
check(accepted(["campaignKey": "ABC"] as NSDictionary) == nil, "bridge: object ignored (S10)")
check(accepted(["ABC"] as NSArray) == nil, "bridge: array ignored (S10)")
if case .rejected(let reason) = WebBridgeInput.campaignKey(from: NSNumber(value: 1)) {
    check(!reason.isEmpty, "bridge: rejection carries a reason for the log", reason)
} else {
    check(false, "bridge: rejection carries a reason for the log")
}

// MARK: - WebBridgeInput · JS string literal for the injected key (L7)

check(WebBridgeInput.javaScriptStringLiteral("abc") == "\"abc\"", "literal: plain")
let tricky = WebBridgeInput.javaScriptStringLiteral("a\"b\\c</script>\u{2028}\u{2029}\n") ?? ""
check(tricky.hasPrefix("\"") && tricky.hasSuffix("\""), "literal: quoted", tricky)
check(!tricky.contains("\u{2028}") && !tricky.contains("\u{2029}") && !tricky.contains("\n"),
      "literal: line terminators escaped", tricky)
check(!tricky.contains("</"), "literal: '</' cannot close a tag", tricky)
let roundTrip = (try? JSONSerialization.jsonObject(with: Data(tricky.utf8), options: .fragmentsAllowed)) as? String
check(roundTrip == "a\"b\\c</script>\u{2028}\u{2029}\n", "literal: decodes back to the same string", "\(String(describing: roundTrip))")

print("")
print("logic_check: \(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
