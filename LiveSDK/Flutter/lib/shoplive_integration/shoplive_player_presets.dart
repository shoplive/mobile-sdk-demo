import 'package:shoplive_player/shoplive_player.dart';

/// Ready-made `ShoplivePlayerConfiguration` examples — copy the one closest to what
/// you need and edit it.
///
/// ## Flutter difference: configuration is **merged**, not replaced
/// On native, each `start` takes a whole new immutable configuration. In the
/// Flutter plugin, `start(configuration:)` and `setConfiguration` **merge** the given
/// fields on top of the current settings, and null fields keep their current value.
/// So [defaults] does *not* reset anything an earlier `start` set — pass every field
/// you care about, or read the current state back with
/// `ShoplivePlayer.instance.getConfiguration()`.
///
/// Things you change *during* playback are not configuration but runtime commands:
/// `setMuted`, `setResizeMode`, `setOverlayUI` — see `ShoplivePlayerSession`.
///
/// ## What the Flutter API does not have
/// Native-only appearance fields — loading animation, chat fonts, iOS
/// `allowScreenCapture` — are not exposed in 3.0.2; the SDK defaults apply.
/// `android:` options are accepted on iOS and ignored.
///
/// ## What `overlay.ui = hidden` means
/// It only **hides** the built-in overlay UI (chat, products, coupons). The command
/// channel stays alive, so product and coupon requests keep arriving — that is the
/// mode to use when your app draws its own UI.
abstract final class ShoplivePlayerPresets {
  /// Nothing set — the three-line integration. Keeps whatever is current.
  static const ShoplivePlayerConfiguration defaults = ShoplivePlayerConfiguration();

  /// Full-screen live viewing with sound on.
  ///
  /// [ShoplivePlayerType.live] decides the volume-key policy and the default
  /// receive resolution, so set it deliberately rather than by accident.
  static ShoplivePlayerConfiguration fullScreenLive({bool muteOnStart = false, bool mixWithOthers = false}) =>
      ShoplivePlayerConfiguration(
        type: ShoplivePlayerType.live,
        sound: ShopliveSoundOptions(
          muteOnStart: muteOnStart,
          // true keeps other apps' audio playing alongside the stream.
          mixWithOthers: mixWithOthers,
        ),
        android: const ShopliveAndroidPlayerOptions(autoResumeOnFocusGained: true),
      );

  /// A small preview floating over your own screen.
  ///
  /// [ShoplivePlayerType.preview] blocks the volume keys and receives at preview
  /// resolution — less traffic, and the hardware keys keep controlling your app.
  /// Muted on start, because autoplaying sound over a feed is hostile.
  /// Start it with `ShoplivePresentationStyle.pip`; see `ShopliveFeedPreview`.
  static ShoplivePlayerConfiguration preview({bool muteOnStart = true}) => ShoplivePlayerConfiguration(
    type: ShoplivePlayerType.preview,
    sound: ShopliveSoundOptions(muteOnStart: muteOnStart),
    pip: const ShoplivePipOptions(isInAppPipEnabled: true),
  );

  /// Your brand colour on the loading indicator.
  ///
  /// [indicatorColor] is ARGB, e.g. `0xFFFF2D55` — the same value on both platforms.
  /// [isStatusBarVisible] is Android-only (ignored on iOS).
  static ShoplivePlayerConfiguration branded({required int indicatorColor, bool isStatusBarVisible = true}) =>
      ShoplivePlayerConfiguration(
        appearance: ShopliveAppearanceOptions(indicatorColor: indicatorColor),
        android: ShopliveAndroidPlayerOptions(isStatusBarVisible: isStatusBarVisible),
      );

  /// Video only, no built-in overlay — for apps that render chat, products and
  /// coupons themselves. Every event and request still arrives.
  static const ShoplivePlayerConfiguration overlayHidden = ShoplivePlayerConfiguration(
    overlay: ShopliveOverlayOptions(ui: ShopliveOverlayUIMode.hidden),
  );

  /// The built-in overlay back on. Needed explicitly because configuration merges.
  static const ShoplivePlayerConfiguration overlayBuiltIn = ShoplivePlayerConfiguration(
    overlay: ShopliveOverlayOptions(ui: ShopliveOverlayUIMode.builtIn),
  );

  /// Screenshots and screen mirroring blacked out — **Android only** (`FLAG_SECURE`).
  /// The iOS SDK option is not exposed by the Flutter plugin 3.0.2.
  static const ShoplivePlayerConfiguration captureProtected = ShoplivePlayerConfiguration(
    android: ShopliveAndroidPlayerOptions(allowScreenCapture: false),
  );

  /// Per-playback options. Unlike a configuration, these are not kept between
  /// `start()` / `play()` calls.
  ///
  /// [referrer] where this view came from — push id, campaign slot, screen name.
  /// It is the only link between "which entry point" and "how long they watched".
  static ShoplivePlayOptions playOptions({
    String? referrer,
    bool keepWindowStateOnPlayExecuted = false,
    ShoplivePresentationStyle presentationStyle = ShoplivePresentationStyle.fullscreen,
  }) => ShoplivePlayOptions(
    referrer: (referrer == null || referrer.trim().isEmpty) ? null : referrer,
    keepWindowStateOnPlayExecuted: keepWindowStateOnPlayExecuted,
    presentationStyle: presentationStyle,
  );
}
