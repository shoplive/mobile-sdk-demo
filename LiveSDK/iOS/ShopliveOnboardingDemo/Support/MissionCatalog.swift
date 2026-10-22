//
//  MissionCatalog.swift
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  The 8 cards of the S2 feature list. The numbers match the mission numbers in the integration
//  guide (https://sdk.shoplive.cloud).
//
//  ⚠️ sourceFile is the only bridge between the app and the project's source (prototype S2 rule).
//     If you move a file, fix this table too.
//

import Foundation

struct Mission {

    enum Run {
        case player         // S3 · full-screen player
        case deeplink       // fake push banner → deep link playback
        case auth           // auth-mode action sheet → playback
        case feed           // S3 · home feed (embedded View)
        case studio         // S3 · studio (broadcasting)
    }

    /// The developer-sheet tab to open automatically right after launching (nil for none).
    enum AutoSheet { case log, options }

    let number: Int
    let title: String
    let summary: String
    let sourceFile: String
    let check: String
    let run: Run
    let autoSheet: AutoSheet?
    let needsStreamToken: Bool
}

enum MissionCatalog {

    static let all: [Mission] = [
        Mission(number: 1,
                title: L("mission.1.title"),
                summary: L("mission.1.summary"),
                sourceFile: "ShopliveIntegration/PlayerLauncher.swift",
                check: L("mission.1.check"),
                run: .player, autoSheet: nil, needsStreamToken: false),

        Mission(number: 2,
                title: L("mission.2.title"),
                summary: L("mission.2.summary"),
                sourceFile: "ShopliveIntegration/DeepLinkRouter.swift",
                check: L("mission.2.check"),
                run: .deeplink, autoSheet: .log, needsStreamToken: false),

        Mission(number: 3,
                title: L("mission.3.title"),
                summary: L("mission.3.summary"),
                sourceFile: "ShopliveIntegration/UserSetup.swift",
                check: L("mission.3.check"),
                run: .auth, autoSheet: nil, needsStreamToken: false),

        Mission(number: 4,
                title: L("mission.4.title"),
                summary: L("mission.4.summary"),
                sourceFile: "ShopliveIntegration/EmbeddedPlayerView.swift",
                check: L("mission.4.check"),
                run: .feed, autoSheet: nil, needsStreamToken: false),

        Mission(number: 5,
                title: L("mission.5.title"),
                summary: L("mission.5.summary"),
                sourceFile: "ShopliveIntegration/PipOptions.swift",
                check: L("mission.5.check"),
                run: .player, autoSheet: nil, needsStreamToken: false),

        Mission(number: 6,
                title: L("mission.6.title"),
                summary: L("mission.6.summary"),
                sourceFile: "ShopliveIntegration/DemoPlayerDelegate.swift",
                check: L("mission.6.check"),
                run: .player, autoSheet: .log, needsStreamToken: false),

        Mission(number: 7,
                title: L("mission.7.title"),
                summary: L("mission.7.summary"),
                sourceFile: "ShopliveIntegration/PlayerConfigurationFactory.swift",
                check: L("mission.7.check"),
                run: .player, autoSheet: .options, needsStreamToken: false),

        Mission(number: 8,
                title: L("mission.8.title"),
                summary: L("mission.8.summary"),
                sourceFile: "ShopliveIntegration/StudioLauncher.swift",
                check: L("mission.8.check"),
                run: .studio, autoSheet: nil, needsStreamToken: true),
    ]

    static func mission(_ number: Int) -> Mission? {
        all.first { $0.number == number }
    }
}

/// The "verified" marker. Prototype S2 rule: completion is decided automatically from events —
/// there is nothing for the user to check off.
final class MissionProgress {

    static let shared = MissionProgress()
    static let didChange = Notification.Name("MissionProgress.didChange")

    private let key = "demo.completedMissions"
    private let defaults = UserDefaults.standard

    private init() {}

    private var completed: Set<Int> {
        get { Set(defaults.array(forKey: key) as? [Int] ?? []) }
        set { defaults.set(Array(newValue), forKey: key) }
    }

    func isDone(_ number: Int) -> Bool { completed.contains(number) }

    var doneCount: Int { completed.count }

    /// Call this only when an event confirms playback/broadcasting actually started.
    func markDone(_ number: Int) {
        guard !completed.contains(number) else { return }
        var next = completed
        next.insert(number)
        completed = next
        NotificationCenter.default.post(name: MissionProgress.didChange, object: nil)
    }
}
