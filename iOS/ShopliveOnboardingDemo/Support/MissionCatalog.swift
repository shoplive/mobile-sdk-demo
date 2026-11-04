//
//  MissionCatalog.swift
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  The 9 cards of the S2 feature list, in the order of the integration guide's mission map
//  (https://sdk.shoplive.cloud). A card's number is its position — MissionID's declaration order —
//  and comes from here only (SMV-1922 §1 ①). Branching and completion use MissionID, never the number.
//
//  ⚠️ sourceFiles is the only bridge between the app and the project's source (prototype S2 rule).
//     If you move a file, fix this table too.
//

import Foundation

struct Mission {

    enum Run {
        case player         // S3 · full-screen player (host VC)
        case nudge          // product screen → nudge preview over it
        case deeplink       // fake push banner → deep link playback
        case auth           // auth-mode action sheet → playback
        case inline         // choose native (feed embed) or hybrid (web list)
        case studio         // S3 · studio (broadcasting)
    }

    /// The developer-sheet tab to open automatically right after launching (nil for none).
    enum AutoSheet { case log, options }

    let id: MissionID
    let sourceFiles: [String]
    let run: Run
    let autoSheet: AutoSheet?
    let needsStreamToken: Bool

    fileprivate let titleKey: String
    fileprivate let summaryKey: String
    fileprivate let checkKey: String

    // Looked up when drawn, not when the catalog is built — the app language can change at runtime
    // (DemoLanguage.current), and a value captured once would stay in the old language (U12).
    var title: String { L(titleKey) }
    var summary: String { L(summaryKey) }
    var check: String { L(checkKey) }

    /// The number shown on the card (catalog position, 1-based).
    var number: Int { MissionCatalog.number(of: id) }
}

enum MissionCatalog {

    /// Cards in display order. Built from `MissionID.allCases`, so a new identifier that is not
    /// described in `mission(for:)` does not compile.
    static var all: [Mission] { MissionID.allCases.map(mission(for:)) }

    /// The total shown as "n / count".
    static var count: Int { MissionID.allCases.count }

    /// The number of `id` in the catalog (1-based) — for every string that names a mission number.
    static func number(of id: MissionID) -> Int {
        (MissionID.allCases.firstIndex(of: id) ?? MissionID.allCases.endIndex) + 1
    }

    static func mission(for id: MissionID) -> Mission {
        switch id {
        case .player:
            return Mission(id: id, sourceFiles: ["ShopliveIntegration/PlayerLauncher.swift"],
                           run: .player, autoSheet: nil, needsStreamToken: false,
                           titleKey: "mission.player.title", summaryKey: "mission.player.summary",
                           checkKey: "mission.player.check")
        case .nudge:
            return Mission(id: id, sourceFiles: ["ShopliveIntegration/NudgePreview.swift"],
                           run: .nudge, autoSheet: nil, needsStreamToken: false,
                           titleKey: "mission.nudge.title", summaryKey: "mission.nudge.summary",
                           checkKey: "mission.nudge.check")
        case .pip:
            return Mission(id: id, sourceFiles: ["ShopliveIntegration/PipOptions.swift"],
                           run: .player, autoSheet: nil, needsStreamToken: false,
                           titleKey: "mission.pip.title", summaryKey: "mission.pip.summary",
                           checkKey: "mission.pip.check")
        case .deeplink:
            return Mission(id: id, sourceFiles: ["ShopliveIntegration/DeepLinkRouter.swift"],
                           run: .deeplink, autoSheet: .log, needsStreamToken: false,
                           titleKey: "mission.deeplink.title", summaryKey: "mission.deeplink.summary",
                           checkKey: "mission.deeplink.check")
        case .user:
            return Mission(id: id, sourceFiles: ["ShopliveIntegration/UserSetup.swift"],
                           run: .auth, autoSheet: nil, needsStreamToken: false,
                           titleKey: "mission.user.title", summaryKey: "mission.user.summary",
                           checkKey: "mission.user.check")
        case .events:
            return Mission(id: id, sourceFiles: ["ShopliveIntegration/DemoPlayerDelegate.swift"],
                           run: .player, autoSheet: .log, needsStreamToken: false,
                           titleKey: "mission.events.title", summaryKey: "mission.events.summary",
                           checkKey: "mission.events.check")
        case .inline:
            // E3: one card, two ways — the tap asks native or hybrid, so the card names both files.
            return Mission(id: id, sourceFiles: ["ShopliveIntegration/EmbeddedPlayerView.swift",
                                                 "ShopliveIntegration/WebBridge.swift"],
                           run: .inline, autoSheet: nil, needsStreamToken: false,
                           titleKey: "mission.inline.title", summaryKey: "mission.inline.summary",
                           checkKey: "mission.inline.check")
        case .ui:
            return Mission(id: id, sourceFiles: ["ShopliveIntegration/PlayerConfigurationFactory.swift"],
                           run: .player, autoSheet: .options, needsStreamToken: false,
                           titleKey: "mission.ui.title", summaryKey: "mission.ui.summary",
                           checkKey: "mission.ui.check")
        case .studio:
            return Mission(id: id, sourceFiles: ["ShopliveIntegration/StudioLauncher.swift"],
                           run: .studio, autoSheet: nil, needsStreamToken: true,
                           titleKey: "mission.studio.title", summaryKey: "mission.studio.summary",
                           checkKey: "mission.studio.check")
        }
    }
}

/// The "verified" marker. Prototype S2 rule: completion is decided automatically from events —
/// there is nothing for the user to check off.
///
/// SMV-1922 §1 ⑤ — the decision lives here and only here (CG-3): which mission is running
/// (`activeMission`) and which player that mission started (`owner`). A playback signal from any other
/// player is ignored, so a feed embed still playing behind a deep-link player cannot complete the
/// deep-link mission (S47).
final class MissionProgress {

    static let shared = MissionProgress()
    static let didChange = Notification.Name("MissionProgress.didChange")

    // MARK: Storage — identifier strings; the same key and values as Android (§1 ②)

    private static let key = "demo.completedMissionIds"
    /// Before SMV-1922: mission numbers [Int]. Folded into `key` once, then deleted.
    private static let legacyKey = "demo.completedMissions"
    /// Missions that complete when their own player reaches playback (H1 — same as Android).
    private static let completesOnPlayback: Set<MissionID> = [.player, .nudge, .deeplink, .user, .inline, .ui]

    private let defaults = UserDefaults.standard
    private var completed: Set<MissionID> = []

    // MARK: Decision state

    private(set) var activeMission: MissionID?
    private weak var owner: AnyObject?
    /// The last nudge's player. Its PIP entries are never "keep watching in PIP", even after another
    /// mission started (X4 — §1 ⑤ is about the session, not the running mission).
    private weak var nudgePlayer: AnyObject?
    /// One "ignored" line per started mission — playback signals repeat (rendering), the log must not.
    private var didLogIgnoredSignal = false
    private var milestoneObserver: NSObjectProtocol?

    private init() {
        completed = loadMigratingLegacyRecord()
    }

    /// Subscribes to every player's milestones for the app's lifetime. Called once at startup.
    func startObserving() {
        guard milestoneObserver == nil else { return }
        milestoneObserver = DemoPlayerDelegate.observeMilestones(of: nil) { [weak self] player, milestone in
            self?.record(milestone, from: player)
        }
    }

    // MARK: Reading

    func isDone(_ id: MissionID) -> Bool { completed.contains(id) }

    var doneCount: Int { completed.count }

    // MARK: Deciding

    /// Every start path calls this right before playback can begin (U07): the card host, the deep link,
    /// the nudge, the hybrid list and the feed. `owner` is the player that path created.
    func startMission(_ id: MissionID, owner: AnyObject?) {
        activeMission = id
        self.owner = owner
        if id == .nudge, let owner { nudgePlayer = owner }
        didLogIgnoredSignal = false
        log("mission \(id.rawValue) started — owner: \(owner.map { "\(type(of: $0))" } ?? "none")")
    }

    /// Registers the player of a mission that was started before its player existed (the nudge:
    /// active → start → owner, the same order as Android).
    func attachOwner(_ owner: AnyObject, to id: MissionID) {
        guard activeMission == id else {
            log("owner for \(id.rawValue) ignored — \(activeMission?.rawValue ?? "no mission") is running")
            return
        }
        self.owner = owner
        if id == .nudge { nudgePlayer = owner }
        log("mission \(id.rawValue) owner: \(type(of: owner))")
    }

    /// One player signal → at most one completion (§1 ⑤). Repeats are no-ops.
    func record(_ milestone: PlayerMilestone, from player: AnyObject) {
        switch milestone {
        case .playbackReached:
            guard let active = activeMission, Self.completesOnPlayback.contains(active) else { return }
            guard let owner else {
                // A start path that never registered its player — better not done than done wrongly (AC-2).
                logIgnoredOnce("playback reached, but \(active.rawValue) has no owner player — not recorded")
                return
            }
            guard player === owner else {
                logIgnoredOnce("playback from a player that did not start \(active.rawValue) — ignored")
                return
            }
            complete(active, because: "playback reached")

        case .pipStateChanged(let isActive):
            guard isActive else { return }
            // E1: the nudge's own small window is the nudge, not "keep watching in PIP" (S26).
            guard MissionID.pipEntryCompletesPip(activeMission: activeMission, owner: owner, player: player,
                                                 isNudgePlayer: nudgePlayer.map { $0 === player } ?? false) else { return }
            complete(.pip, because: "in-App PIP entered")

        case .requestReceived:
            complete(.events, because: "request received")      // session-independent, as on Android

        case .closed, .campaignStatusChanged, .fatalError:
            return
        }
    }

    /// The studio reached LIVE.
    func markBroadcastLive() {
        complete(.studio, because: "broadcast LIVE")
    }

    private func complete(_ id: MissionID, because reason: String) {
        guard !completed.contains(id) else { return }
        completed.insert(id)
        defaults.set(completed.map(\.rawValue).sorted(), forKey: Self.key)
        log("mission \(id.rawValue) verified — \(reason)")
        NotificationCenter.default.post(name: MissionProgress.didChange, object: nil)
    }

    // MARK: Loading · legacy migration (the rules are pure functions in MissionID.swift)

    private func loadMigratingLegacyRecord() -> Set<MissionID> {
        let stored = MissionID.decodeStored(defaults.object(forKey: Self.key))
        if !stored.dropped.isEmpty {
            log("stored values \(stored.dropped) name no mission — ignored")
        }

        switch MissionID.migrateLegacy(defaults.object(forKey: Self.legacyKey), into: stored.ids) {
        case .absent:
            return stored.ids

        case .unreadable(let found):
            log("legacy record \(Self.legacyKey) is not a list (\(found)) — kept, retried next launch")
            return stored.ids

        case .migrated(let merged, let dropped):
            if !dropped.isEmpty {
                log("legacy values \(dropped) match no mission — dropped")
            }
            // Order matters: write the new key first, delete the legacy key after. If the app dies in
            // between, the next launch folds the same numbers into the same set (S01).
            defaults.set(merged.map(\.rawValue).sorted(), forKey: Self.key)
            defaults.removeObject(forKey: Self.legacyKey)
            log("legacy record migrated → \(merged.map(\.rawValue).sorted())")
            return merged
        }
    }

    private func logIgnoredOnce(_ message: String) {
        guard !didLogIgnoredSignal else { return }
        didLogIgnoredSignal = true
        log(message)
    }

    private func log(_ message: String) {
        EventLog.shared.log(.sdk, "demo: progress — \(message)")
    }
}
