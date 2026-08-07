import ProjectDescription

// ShopLive unified SDK v3 onboarding demo app (iOS · UIKit)
//
// Purpose: help integrators finish their integration by "following the missions and pasting the code
//          from Integration/ straight into their own app". That is why the project has exactly two
//          layers:
//            · Integration/       ← the copy target. SDK calls only, no demo UI dependencies.
//            · Screens/, Support/ ← the demo harness. Not a copy target.
//
// The SDK comes in over SPM, exactly as an integrator gets it — see Tuist/Package.swift.
// Only two products are declared; ShopliveCore, ShopLiveWebRTCHelperSDK and WebRTC are linked
// automatically because the two products carry them.

private let bundleId = "cloud.shoplive.onboarding.demo"

let project = Project(
    name: "ShopliveOnboardingDemo",
    settings: .settings(
        base: [
            "SWIFT_VERSION": "5.0",              // Swift 6 strict concurrency off (the SDK is @preconcurrency)
            "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
        ],
        configurations: [.debug(name: .debug), .release(name: .release)]
    ),
    targets: [
        .target(
            name: "ShopliveOnboardingDemo",
            destinations: .iOS,
            product: .app,
            bundleId: bundleId,
            deploymentTargets: .iOS("15.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "ShopLive Demo",
                "UILaunchScreen": ["UIColorName": ""],
                // Localization — follows the device language, falling back to the development
                // language (en) for anything unsupported.
                "CFBundleDevelopmentRegion": "en",
                "CFBundleLocalizations": ["en", "ko", "ja"],
                "UISupportedInterfaceOrientations": [
                    "UIInterfaceOrientationPortrait",
                ],
                // Mission 8 (broadcasting) — the studio uses the camera and microphone.
                "NSCameraUsageDescription": "The camera is used to broadcast live.",
                "NSMicrophoneUsageDescription": "The microphone is used to broadcast live.",
                // Mission 2 (deep links) — shopliveDemo://live?campaign=...&ref=...
                "CFBundleURLTypes": [
                    [
                        "CFBundleTypeRole": "Editor",
                        "CFBundleURLName": "cloud.shoplive.onboarding.demo",
                        "CFBundleURLSchemes": ["shopliveDemo"],
                    ],
                ],
                // The overlay web view talks https only, so no ATS exceptions are declared.
            ]),
            sources: ["ShopliveOnboardingDemo/**/*.swift", "ShopliveIntegration/**/*.swift"],
            resources: ["ShopliveOnboardingDemo/Resources/**"],
            dependencies: [
                .external(name: "ShoplivePlayerSDK"),
                .external(name: "ShopliveStreamerSDK"),
            ],
            settings: .settings(base: [
                "TARGETED_DEVICE_FAMILY": "1",

                // Signing — the same team as the SDK repository
                // (Tuist/ProjectDescriptionHelpers/Project+Templates.swift).
                // Without this, Xcode and device-target builds fail with
                // "Signing for ... requires a development team".
                "CODE_SIGN_STYLE": "Automatic",
                "DEVELOPMENT_TEAM": "D237UGRPX6",
                "CODE_SIGN_IDENTITY": "Apple Development",

                // The simulator needs no signing — this keeps simulator builds working on a machine
                // that has no team configured.
                "CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]": "NO",
                "CODE_SIGNING_REQUIRED[sdk=iphonesimulator*]": "NO",
                "CODE_SIGN_IDENTITY[sdk=iphonesimulator*]": "",
            ])
        ),

        // ⑤ The target that **proves by compilation** that "you can copy this and use it right away".
        //
        // Its only source is Integration/** — it does not include the demo harness
        // (Screens/, Support/, App/).
        // So the moment a single harness dependency appears inside Integration/, **this target fails to
        // build**. It reproduces exactly the situation of copying only Integration/ into an empty
        // project.
        //
        // It is not linked into the app target (the same sources are compiled twice, so linking both
        // would duplicate symbols).
        .target(
            name: "IntegrationCopyPasteProof",
            destinations: .iOS,
            product: .framework,
            bundleId: "cloud.shoplive.onboarding.demo.copypasteproof",
            deploymentTargets: .iOS("15.0"),
            infoPlist: .default,
            sources: ["ShopliveIntegration/**/*.swift"],
            dependencies: [
                .external(name: "ShoplivePlayerSDK"),
                .external(name: "ShopliveStreamerSDK"),
            ],
            settings: .settings(base: [
                "TARGETED_DEVICE_FAMILY": "1",
                "CODE_SIGNING_ALLOWED": "NO",
            ])
        ),
    ],
    schemes: [
        .scheme(
            name: "ShopliveOnboardingDemo",
            shared: true,
            buildAction: .buildAction(targets: ["ShopliveOnboardingDemo"]),
            runAction: .runAction(configuration: .debug, executable: "ShopliveOnboardingDemo")
        ),
        .scheme(
            name: "IntegrationCopyPasteProof",
            shared: true,
            buildAction: .buildAction(targets: ["IntegrationCopyPasteProof"])
        ),
    ]
)
