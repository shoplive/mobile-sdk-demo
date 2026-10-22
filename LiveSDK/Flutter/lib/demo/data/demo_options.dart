import 'package:flutter/foundation.dart';
import 'package:shoplive_player/shoplive_player.dart';

/// The state edited by the developer sheet's "options" tab.
///
/// **Every field of the Flutter `ShoplivePlayerConfiguration` has one control
/// here** — including fields no mission uses, so all of them can be tried. The
/// conversion into a configuration is [DemoConfigurationFactory]'s job.
///
/// The defaults are **kept identical to the SDK defaults**, so running without
/// touching anything demonstrates "you do not have to specify anything".
///
/// This is demo harness — a screen's mutable state. Customer-facing examples are in
/// `shoplive_integration/shoplive_player_presets.dart`.
@immutable
class DemoOptions {
  const DemoOptions({
    this.type = ShoplivePlayerType.live,
    this.isInAppPipEnabled = true,
    this.isOSPipEnabled = true,
    this.enterOSPipOnBackPressed = false,
    this.pipPosition = ShoplivePipPosition.bottomRight,
    this.pipScale = 0.4,
    this.pipAspectRatio = ShoplivePipRatio.ratio9x16,
    this.pipPaddingPx = 0,
    this.muteOnStart = false,
    this.mixWithOthers = false,
    this.autoResumeOnFocusGained = true,
    this.isVolumeKeyEnabled,
    this.indicatorColor = IndicatorColor.white,
    this.isStatusBarVisible = true,
    this.allowScreenCapture = true,
    this.closeWhenAppDestroyed = true,
    this.actionOnNavigation = ShopliveNavigationAction.pip,
    this.shareScheme = '',
    this.overlayUI = ShopliveOverlayUIMode.builtIn,
    this.customParameters = const {},
    this.referrer = '',
    this.keepWindowStateOnPlayExecuted = false,
    this.resizeMode = ShopliveResizeMode.fill,
  });

  // ── type ────────────────────────────────────────────────────────────────────
  final ShoplivePlayerType type;

  // ── pip ─────────────────────────────────────────────────────────────────────
  final bool isInAppPipEnabled;
  final bool isOSPipEnabled;

  /// configuration.android.enterOSPipOnBackPressed (Android only).
  final bool enterOSPipOnBackPressed;
  final ShoplivePipPosition pipPosition;
  final double pipScale;

  /// Ignored on iOS.
  final ShoplivePipRatio pipAspectRatio;

  /// The same value on all four sides, in **pixels**.
  final int pipPaddingPx;

  // ── sound ───────────────────────────────────────────────────────────────────
  final bool muteOnStart;
  final bool mixWithOthers;

  /// configuration.android.autoResumeOnFocusGained (Android only).
  final bool autoResumeOnFocusGained;

  /// configuration.android.isVolumeKeyEnabled. Null follows the type's default.
  final bool? isVolumeKeyEnabled;

  // ── appearance ──────────────────────────────────────────────────────────────
  final IndicatorColor indicatorColor;

  /// configuration.android.isStatusBarVisible (Android only).
  final bool isStatusBarVisible;

  /// configuration.android.allowScreenCapture (Android only). SDK default true.
  final bool allowScreenCapture;

  // ── navigation ──────────────────────────────────────────────────────────────
  final ShopliveNavigationAction actionOnNavigation;
  final String shareScheme;

  /// configuration.android.closeWhenAppDestroyed (Android only).
  final bool closeWhenAppDestroyed;

  // ── overlay ─────────────────────────────────────────────────────────────────
  final ShopliveOverlayUIMode overlayUI;

  // ── customParameters ────────────────────────────────────────────────────────
  final Map<String, String> customParameters;

  // ── PlayOptions (per playback) ──────────────────────────────────────────────
  final String referrer;
  final bool keepWindowStateOnPlayExecuted;

  // ── Runtime (applied during playback, not configuration) ────────────────────
  final ShopliveResizeMode resizeMode;

  static const DemoOptions defaults = DemoOptions();

  bool get isModified => this != defaults;

  DemoOptions copyWith({
    ShoplivePlayerType? type,
    bool? isInAppPipEnabled,
    bool? isOSPipEnabled,
    bool? enterOSPipOnBackPressed,
    ShoplivePipPosition? pipPosition,
    double? pipScale,
    ShoplivePipRatio? pipAspectRatio,
    int? pipPaddingPx,
    bool? muteOnStart,
    bool? mixWithOthers,
    bool? autoResumeOnFocusGained,
    bool? Function()? isVolumeKeyEnabled,
    IndicatorColor? indicatorColor,
    bool? isStatusBarVisible,
    bool? allowScreenCapture,
    bool? closeWhenAppDestroyed,
    ShopliveNavigationAction? actionOnNavigation,
    String? shareScheme,
    ShopliveOverlayUIMode? overlayUI,
    Map<String, String>? customParameters,
    String? referrer,
    bool? keepWindowStateOnPlayExecuted,
    ShopliveResizeMode? resizeMode,
  }) => DemoOptions(
    type: type ?? this.type,
    isInAppPipEnabled: isInAppPipEnabled ?? this.isInAppPipEnabled,
    isOSPipEnabled: isOSPipEnabled ?? this.isOSPipEnabled,
    enterOSPipOnBackPressed: enterOSPipOnBackPressed ?? this.enterOSPipOnBackPressed,
    pipPosition: pipPosition ?? this.pipPosition,
    pipScale: pipScale ?? this.pipScale,
    pipAspectRatio: pipAspectRatio ?? this.pipAspectRatio,
    pipPaddingPx: pipPaddingPx ?? this.pipPaddingPx,
    muteOnStart: muteOnStart ?? this.muteOnStart,
    mixWithOthers: mixWithOthers ?? this.mixWithOthers,
    autoResumeOnFocusGained: autoResumeOnFocusGained ?? this.autoResumeOnFocusGained,
    isVolumeKeyEnabled: isVolumeKeyEnabled != null ? isVolumeKeyEnabled() : this.isVolumeKeyEnabled,
    indicatorColor: indicatorColor ?? this.indicatorColor,
    isStatusBarVisible: isStatusBarVisible ?? this.isStatusBarVisible,
    allowScreenCapture: allowScreenCapture ?? this.allowScreenCapture,
    closeWhenAppDestroyed: closeWhenAppDestroyed ?? this.closeWhenAppDestroyed,
    actionOnNavigation: actionOnNavigation ?? this.actionOnNavigation,
    shareScheme: shareScheme ?? this.shareScheme,
    overlayUI: overlayUI ?? this.overlayUI,
    customParameters: customParameters ?? this.customParameters,
    referrer: referrer ?? this.referrer,
    keepWindowStateOnPlayExecuted: keepWindowStateOnPlayExecuted ?? this.keepWindowStateOnPlayExecuted,
    resizeMode: resizeMode ?? this.resizeMode,
  );

  @override
  bool operator ==(Object other) =>
      other is DemoOptions &&
      other.type == type &&
      other.isInAppPipEnabled == isInAppPipEnabled &&
      other.isOSPipEnabled == isOSPipEnabled &&
      other.enterOSPipOnBackPressed == enterOSPipOnBackPressed &&
      other.pipPosition == pipPosition &&
      other.pipScale == pipScale &&
      other.pipAspectRatio == pipAspectRatio &&
      other.pipPaddingPx == pipPaddingPx &&
      other.muteOnStart == muteOnStart &&
      other.mixWithOthers == mixWithOthers &&
      other.autoResumeOnFocusGained == autoResumeOnFocusGained &&
      other.isVolumeKeyEnabled == isVolumeKeyEnabled &&
      other.indicatorColor == indicatorColor &&
      other.isStatusBarVisible == isStatusBarVisible &&
      other.allowScreenCapture == allowScreenCapture &&
      other.closeWhenAppDestroyed == closeWhenAppDestroyed &&
      other.actionOnNavigation == actionOnNavigation &&
      other.shareScheme == shareScheme &&
      other.overlayUI == overlayUI &&
      mapEquals(other.customParameters, customParameters) &&
      other.referrer == referrer &&
      other.keepWindowStateOnPlayExecuted == keepWindowStateOnPlayExecuted &&
      other.resizeMode == resizeMode;

  @override
  int get hashCode => Object.hashAll([
    type, isInAppPipEnabled, isOSPipEnabled, enterOSPipOnBackPressed, pipPosition, pipScale, //
    pipAspectRatio, pipPaddingPx, muteOnStart, mixWithOthers, autoResumeOnFocusGained,
    isVolumeKeyEnabled, indicatorColor, isStatusBarVisible, allowScreenCapture,
    closeWhenAppDestroyed, actionOnNavigation, shareScheme, overlayUI,
    Object.hashAllUnordered(customParameters.entries.map((e) => '${e.key}=${e.value}')),
    referrer, keepWindowStateOnPlayExecuted, resizeMode,
  ]);
}

/// `appearance.indicatorColor` is an ARGB int; the demo cycles a few presets.
enum IndicatorColor {
  white(0xFFFFFFFF, null),
  brand(0xFFFF2D55, '#FF2D55'),
  blue(0xFF1F6FEB, '#1F6FEB'),
  black(0xFF111111, '#111111');

  const IndicatorColor(this.argb, this.literalLabel);

  final int argb;

  /// Null means "use the localized `value_white_default` label".
  final String? literalLabel;
}

/// Process-wide options state: it must read the same values while an SDK screen is
/// in front, and survive the demo's screens being rebuilt.
class DemoOptionsStore extends ValueNotifier<DemoOptions> {
  DemoOptionsStore() : super(DemoOptions.defaults);

  void update(DemoOptions Function(DemoOptions) transform) => value = transform(value);

  void reset() => value = DemoOptions.defaults;
}

/// Demo-only assembly: every options-tab field at once.
///
/// A customer app would pass one of the `ShoplivePlayerPresets` instead. Because
/// the Flutter plugin **merges** configuration onto the current settings, this
/// factory always fills every field — a field left null would silently keep the
/// value from an earlier playback.
abstract final class DemoConfigurationFactory {
  static ShoplivePlayerConfiguration from(DemoOptions o) => ShoplivePlayerConfiguration(
    type: o.type,
    pip: ShoplivePipOptions(
      isInAppPipEnabled: o.isInAppPipEnabled,
      isOSPipEnabled: o.isOSPipEnabled,
      defaultPosition: o.pipPosition,
      scale: o.pipScale,
      aspectRatio: o.pipAspectRatio,
      padding: ShopliveInsets(left: o.pipPaddingPx, top: o.pipPaddingPx, right: o.pipPaddingPx, bottom: o.pipPaddingPx),
    ),
    sound: ShopliveSoundOptions(muteOnStart: o.muteOnStart, mixWithOthers: o.mixWithOthers),
    appearance: ShopliveAppearanceOptions(indicatorColor: o.indicatorColor.argb),
    navigation: ShopliveNavigationOptions(
      actionOnNavigation: o.actionOnNavigation,
      // Limitation of the Flutter API: a shareScheme cannot be reset to null
      // once set. An empty string is sent as "not set" only on the first start.
      shareScheme: o.shareScheme.trim().isEmpty ? null : o.shareScheme.trim(),
    ),
    overlay: ShopliveOverlayOptions(ui: o.overlayUI),
    customParameters: o.customParameters,
    android: ShopliveAndroidPlayerOptions(
      enterOSPipOnBackPressed: o.enterOSPipOnBackPressed,
      isVolumeKeyEnabled: o.isVolumeKeyEnabled,
      autoResumeOnFocusGained: o.autoResumeOnFocusGained,
      isStatusBarVisible: o.isStatusBarVisible,
      allowScreenCapture: o.allowScreenCapture,
      closeWhenAppDestroyed: o.closeWhenAppDestroyed,
    ),
  );

  static ShoplivePlayOptions playOptions(DemoOptions o, {String? referrerOverride}) {
    final referrer = referrerOverride ?? o.referrer;
    return ShoplivePlayOptions(
      referrer: referrer.trim().isEmpty ? null : referrer.trim(),
      keepWindowStateOnPlayExecuted: o.keepWindowStateOnPlayExecuted,
      presentationStyle: ShoplivePresentationStyle.fullscreen,
    );
  }
}
