// swiftlint:disable:this file_name
// swiftlint:disable all
// swift-format-ignore-file
// swiftformat:disable all
// Generated using tuist — https://github.com/tuist/tuist

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name
public enum ShopliveOnboardingDemoStrings: Sendable {

  public enum Auth: Sendable {
  /// Cancel
    public static let cancel = ShopliveOnboardingDemoStrings.tr("Localizable", "auth.cancel")
    /// guest — watch without signing in
    public static let guest = ShopliveOnboardingDemoStrings.tr("Localizable", "auth.guest")
    /// Sign out (logout)
    public static let logout = ShopliveOnboardingDemoStrings.tr("Localizable", "auth.logout")
    /// profile — simple authentication
    public static let profile = ShopliveOnboardingDemoStrings.tr("Localizable", "auth.profile")
    /// token — server-signed JWT (recommended)
    public static let token = ShopliveOnboardingDemoStrings.tr("Localizable", "auth.token")

    public enum Sheet: Sendable {
    /// You can mix these within one app; it applies from the next playback
      public static let message = ShopliveOnboardingDemoStrings.tr("Localizable", "auth.sheet.message")
      /// How should we identify the user?
      public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "auth.sheet.title")
    }
  }

  public enum Banner: Sendable {
  /// MY SHOP · now
    public static let app = ShopliveOnboardingDemoStrings.tr("Localizable", "banner.app")
    /// 🔴 Summer sale live has started — join now!
    public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "banner.title")
  }

  public enum Dev: Sendable {
  /// default %@
    public static func `default`(_ p1: Any) -> String {
      return ShopliveOnboardingDemoStrings.tr("Localizable", "dev.default",String(describing: p1))
    }

    public enum Action: Sendable {
    /// Call
      public static let call = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.action.call")
      /// Send
      public static let send = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.action.send")
      /// Toggle
      public static let toggle = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.action.toggle")
    }

    public enum Error: Sendable {
    /// No player is currently playing
      public static let noPlayer = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.error.noPlayer")
    }

    public enum Group: Sendable {
    /// Advanced — every remaining configuration field
      public static let advanced = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.group.advanced")
      /// Authentication · Mission 3
      public static let auth = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.group.auth")
      /// Controls (applied immediately during playback)
      public static let control = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.group.control")
      /// Overlay · appearance · Mission 7
      public static let overlay = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.group.overlay")
      /// PIP · Mission 5
      public static let pip = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.group.pip")
    }

    public enum Hint: Sendable {
    /// Tap a value to cycle it. Every field has a default, so it works without being set.
      public static let cycle = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.hint.cycle")
    }

    public enum Log: Sendable {
    /// Clear
      public static let clear = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.log.clear")
      /// 📋 Copy log
      public static let copy = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.log.copy")
      /// No log entries yet — run a feature
      public static let empty = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.log.empty")
      /// ⚠ Engine switches are not reported as events. HLS↔WebRTC switching is internal to the SDK; network conditions surface only via playback(rebuffering) and connectionStateChanged.\n\n⚠ Issues being auto-recovered are not reported as error. error(isRecoverable=false) is delivered only when the session ends unrecoverably.
      public static let notice = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.log.notice")
    }

    public enum Tab: Sendable {
    /// Event log
      public static let log = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.tab.log")
      /// Options
      public static let options = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.tab.options")
    }

    public enum Toast: Sendable {
    /// 📋 Copied
      public static let copied = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.toast.copied")
    }

    public enum Unwired: Sendable {
    /// In this SDK build the following fields have no consumer, so the value is only stored (no effect):\noverlay.ui · pip.isOSPipEnabled · pip.autoEnterOnLeaveScreen · navigation.shareScheme · appearance.isStatusBarVisible · appearance.allowScreenCapture · both PlayOptions fields.\nOnly overlay.ui is worked around via the runtime property (overlayUI).
      public static let warning = ShopliveOnboardingDemoStrings.tr("Localizable", "dev.unwired.warning")
    }
  }

  public enum Feed: Sendable {
  /// ⤢ Full screen
    public static let expand = ShopliveOnboardingDemoStrings.tr("Localizable", "feed.expand")
    /// Home feed · Mission 4
    public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "feed.title")

    public enum Card1: Sendable {
    /// An ordinary feed card
      public static let detail = ShopliveOnboardingDemoStrings.tr("Localizable", "feed.card1.detail")
      /// Today's picks
      public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "feed.card1.title")
    }

    public enum Card2: Sendable {
    /// Playback above survives scrolling
      public static let detail = ShopliveOnboardingDemoStrings.tr("Localizable", "feed.card2.detail")
      /// Best sellers
      public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "feed.card2.title")
    }

    public enum Card3: Sendable {
    /// The session stays alive as you scroll further
      public static let detail = ShopliveOnboardingDemoStrings.tr("Localizable", "feed.card3.detail")
      /// New arrivals
      public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "feed.card3.title")
    }

    public enum Tip: Sendable {
    /// Below is ShoplivePlayerView — your app owns only the layout; controls, events and PIP use the exact same API as full screen.
      public static let embed = ShopliveOnboardingDemoStrings.tr("Localizable", "feed.tip.embed")
    }

    public enum Warn: Sendable {
    /// This embedded view is video-only per design doc §3.4 (overlayUI = .hidden). The automatic-PIP-on-leave option was removed from the public surface in this SDK build; only manual enterPictureInPicture() is available.
      public static let autoPip = ShopliveOnboardingDemoStrings.tr("Localizable", "feed.warn.autoPip")
    }
  }

  public enum List: Sendable {
  /// Features verified %d/8
    public static func title(_ p1: Int) -> String {
      return ShopliveOnboardingDemoStrings.tr("Localizable", "list.title",p1)
    }

    public enum Badge: Sendable {
    /// Verified
      public static let done = ShopliveOnboardingDemoStrings.tr("Localizable", "list.badge.done")
    }

    public enum Locked: Sendable {
    /// accessKey and campaignKey are required
      public static let credentials = ShopliveOnboardingDemoStrings.tr("Localizable", "list.locked.credentials")
      /// 🔒 %@ — see ⚙ at top right
      public static func hint(_ p1: Any) -> String {
        return ShopliveOnboardingDemoStrings.tr("Localizable", "list.locked.hint",String(describing: p1))
      }
      /// A stream token is required
      public static let streamToken = ShopliveOnboardingDemoStrings.tr("Localizable", "list.locked.streamToken")
    }

    public enum Mode: Sendable {
    /// My account · %@
      public static func own(_ p1: Any) -> String {
        return ShopliveOnboardingDemoStrings.tr("Localizable", "list.mode.own",String(describing: p1))
      }
      /// Tour · ShopLive demo campaign
      public static let tour = ShopliveOnboardingDemoStrings.tr("Localizable", "list.mode.tour")
    }

    public enum Rescue: Sendable {
    /// Closed the player because playback was never reached — check the log
      public static let toast = ShopliveOnboardingDemoStrings.tr("Localizable", "list.rescue.toast")
    }

    public enum Tip: Sendable {
    /// To read the code, open the 📄 file from a card in Xcode. Files under Integration/ have no demo-UI dependencies, so you can copy them as-is.
      public static let openFiles = ShopliveOnboardingDemoStrings.tr("Localizable", "list.tip.openFiles")
      /// Tapping a card runs it right away. Numbers match the mission numbers in the integration guide (sdk.shoplive.cloud).
      public static let tapToRun = ShopliveOnboardingDemoStrings.tr("Localizable", "list.tip.tapToRun")
    }
  }

  public enum Mission: Sendable {

    public enum _1: Sendable {
    /// Plays within 2–3s · chat and LIVE badge when live
      public static let check = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.1.check")
      /// Tap to open a full-screen live stream immediately.
      public static let summary = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.1.summary")
      /// Present the player
      public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.1.title")
    }

    public enum _2: Sendable {
    /// Tap banner → playback · ref arrives as referrer
      public static let check = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.2.check")
      /// Sends a mock push banner. Tapping it plays straight from the link.
      public static let summary = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.2.summary")
      /// Open via deep link
      public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.2.title")
    }

    public enum _3: Sendable {
    /// Chat nickname shows the member name
      public static let check = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.3.check")
      /// Pick guest / profile / token, then play.
      public static let summary = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.3.summary")
      /// Connect user info
      public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.3.title")
    }

    public enum _4: Sendable {
    /// Playback survives scrolling · promotes to full screen
      public static let check = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.4.check")
      /// See a player embedded between home-feed cards.
      public static let summary = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.4.summary")
      /// Embed in your screen
      public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.4.title")
    }

    public enum _5: Sendable {
    /// Small window persists · tap returns without interruption
      public static let check = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.5.check")
      /// After playback starts, tap a product to continue in a small window.
      public static let summary = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.5.summary")
      /// Keep watching in PIP
      public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.5.title")
    }

    public enum _6: Sendable {
    /// navigation/coupon requests received and respond called
      public static let check = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.6.check")
      /// Tap products and coupons, then watch what arrives in the log.
      public static let summary = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.6.summary")
      /// Events · products · coupons
      public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.6.title")
    }

    public enum _7: Sendable {
    /// Color applied · events still arrive when hidden
      public static let check = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.7.check")
      /// Change colors and the overlay in Options and see it applied.
      public static let summary = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.7.summary")
      /// Customize the UI
      public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.7.title")
    }

    public enum _8: Sendable {
    /// preview → LIVE transition · automatic recovery
      public static let check = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.8.check")
      /// Open the studio and start or stop a broadcast.
      public static let summary = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.8.summary")
      /// Go live
      public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "mission.8.title")
    }
  }

  public enum Nav: Sendable {

    public enum Action: Sendable {

      public enum Close: Sendable {
      /// close — closes the player.
        public static let explain = ShopliveOnboardingDemoStrings.tr("Localizable", "nav.action.close.explain")
      }

      public enum Keep: Sendable {
      /// keep — leaves the player as it is.
        public static let explain = ShopliveOnboardingDemoStrings.tr("Localizable", "nav.action.keep.explain")
      }

      public enum Pip: Sendable {
      /// pip — shrinks to a small window on navigation so viewing continues. (default)
        public static let explain = ShopliveOnboardingDemoStrings.tr("Localizable", "nav.action.pip.explain")
      }
    }
  }

  public enum Player: Sendable {

    public enum Failure: Sendable {
    /// ⚠️ Playback failed (%@) — the stream is not being broadcast. The player is left open; check the log, and tap '‹ List' to leave.
      public static func notice(_ p1: Any) -> String {
        return ShopliveOnboardingDemoStrings.tr("Localizable", "player.failure.notice",String(describing: p1))
      }
    }

    public enum Overlay: Sendable {
    /// ‹ List
      public static let back = ShopliveOnboardingDemoStrings.tr("Localizable", "player.overlay.back")
      /// Demo app only
      public static let badge = ShopliveOnboardingDemoStrings.tr("Localizable", "player.overlay.badge")
      /// ⌗ Developer
      public static let dev = ShopliveOnboardingDemoStrings.tr("Localizable", "player.overlay.dev")
    }
  }

  public enum Product: Sendable {
  /// Signature Cotton Shirt
    public static let name = ShopliveOnboardingDemoStrings.tr("Localizable", "product.name")
    /// $39.00
    public static let price = ShopliveOnboardingDemoStrings.tr("Localizable", "product.price")
    /// Product detail · your app's screen
    public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "product.title")

    public enum Pip: Sendable {
    /// Viewing continues in in-App PIP right now (state = .inAppPIP). Tap the PIP window to return to full screen without interruption.
      public static let active = ShopliveOnboardingDemoStrings.tr("Localizable", "product.pip.active")
    }

    public enum Tip: Sendable {
    /// This is the result of your app routing navigation(url).\nReceived URL  %@
      public static func routed(_ p1: Any) -> String {
        return ShopliveOnboardingDemoStrings.tr("Localizable", "product.tip.routed",String(describing: p1))
      }
    }

    public enum Warn: Sendable {
    /// navigation is the only request your app must handle. Without routing, tapping a product does nothing.
      public static let mustHandle = ShopliveOnboardingDemoStrings.tr("Localizable", "product.warn.mustHandle")
    }
  }

  public enum Start: Sendable {
  /// Tap any of the 8 features to run it immediately — viewing (Player) and broadcasting (Streamer). No reading required.
    public static let subtitle = ShopliveOnboardingDemoStrings.tr("Localizable", "start.subtitle")
    /// ShopLive SDK\nIntegration Demo
    public static let title = ShopliveOnboardingDemoStrings.tr("Localizable", "start.title")
    /// Take a tour · Start now
    public static let tour = ShopliveOnboardingDemoStrings.tr("Localizable", "start.tour")
    /// Validate and start
    public static let validate = ShopliveOnboardingDemoStrings.tr("Localizable", "start.validate")

    public enum Field: Sendable {
    /// accessKey *
      public static let accessKey = ShopliveOnboardingDemoStrings.tr("Localizable", "start.field.accessKey")
      /// campaignKey *
      public static let campaignKey = ShopliveOnboardingDemoStrings.tr("Localizable", "start.field.campaignKey")
      /// Stream token (Mission 8)
      public static let streamToken = ShopliveOnboardingDemoStrings.tr("Localizable", "start.field.streamToken")

      public enum AccessKey: Sendable {
      /// Issued from the Queenie console or by your contact
        public static let hint = ShopliveOnboardingDemoStrings.tr("Localizable", "start.field.accessKey.hint")
        /// Your accessKey
        public static let placeholder = ShopliveOnboardingDemoStrings.tr("Localizable", "start.field.accessKey.placeholder")
      }

      public enum CampaignKey: Sendable {
      /// Live or VOD — either works
        public static let hint = ShopliveOnboardingDemoStrings.tr("Localizable", "start.field.campaignKey.hint")
        /// campaignKey to test
        public static let placeholder = ShopliveOnboardingDemoStrings.tr("Localizable", "start.field.campaignKey.placeholder")
      }

      public enum StreamToken: Sendable {
      /// A separate path from viewer authentication
        public static let hint = ShopliveOnboardingDemoStrings.tr("Localizable", "start.field.streamToken.hint")
        /// Optional
        public static let placeholder = ShopliveOnboardingDemoStrings.tr("Localizable", "start.field.streamToken.placeholder")
      }
    }

    public enum Form: Sendable {
    /// You only need two. The stream token is required only for Mission 8.
      public static let tip = ShopliveOnboardingDemoStrings.tr("Localizable", "start.form.tip")
    }

    public enum Own: Sendable {
    /// Use my own account ▼
      public static let collapsed = ShopliveOnboardingDemoStrings.tr("Localizable", "start.own.collapsed")
      /// Use my own account ▲
      public static let expanded = ShopliveOnboardingDemoStrings.tr("Localizable", "start.own.expanded")
    }

    public enum Tip: Sendable {
    /// The code is not in this app. Read it in the demo project shipped alongside — each feature card names the file to open.
      public static let code = ShopliveOnboardingDemoStrings.tr("Localizable", "start.tip.code")
      /// Values are stored on this device only and never sent to a server. The stream token is kept in the Keychain.
      public static let privacy = ShopliveOnboardingDemoStrings.tr("Localizable", "start.tip.privacy")
    }

    public enum Toast: Sendable {
    /// ✅ Initialized — key validity is confirmed on playback
      public static let initialized = ShopliveOnboardingDemoStrings.tr("Localizable", "start.toast.initialized")
      /// accessKey and campaignKey are required
      public static let `required` = ShopliveOnboardingDemoStrings.tr("Localizable", "start.toast.required")
      /// The bundled demo keys are empty — fill in DemoDefaults in DemoCredentials.swift, or use “Use my own account” below
      public static let tourMissing = ShopliveOnboardingDemoStrings.tr("Localizable", "start.toast.tourMissing")
    }

    public enum TourNote: Sendable {
    /// Runs against the ShopLive demo campaign — no input needed.
      public static let available = ShopliveOnboardingDemoStrings.tr("Localizable", "start.tourNote.available")
      /// ⚠️ The bundled demo keys are empty — fill in DemoDefaults (DemoCredentials.swift) or enter your own below.
      public static let missing = ShopliveOnboardingDemoStrings.tr("Localizable", "start.tourNote.missing")
    }
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name

// MARK: - Implementation Details

extension ShopliveOnboardingDemoStrings {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.module.localizedString(forKey: key, value: nil, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
// swiftformat:enable all
// swiftlint:enable all
