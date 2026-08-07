// swift-tools-version: 5.9
import PackageDescription

#if TUIST
import struct ProjectDescription.PackageSettings

let packageSettings = PackageSettings()
#endif

// Shoplive unified SDK v3, pulled the same way an integrator would pull it.
//
// Only the two products are named here. ShopliveCore, ShopLiveWebRTCHelperSDK and WebRTC ride
// along inside them, so they never appear in this file — which is exactly the experience the
// distribution package is meant to give.
//
// `exact` rather than a range: the demo is meant to prove a specific released version, so an
// unnoticed bump would defeat the point.
let package = Package(
    name: "ShopliveOnboardingDemo",
    dependencies: [
        .package(url: "https://github.com/shoplive/shoplive-sdk-ios", exact: "3.0.0"),
    ]
)
