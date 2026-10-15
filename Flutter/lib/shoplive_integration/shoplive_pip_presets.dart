import 'package:shoplive_player/shoplive_player.dart';

/// Keeping the stream visible after the viewer leaves the player.
///
/// There are two kinds of PIP and they behave **differently**:
///
/// | | in-app PIP | OS PIP |
/// | --- | --- | --- |
/// | Owner | a floating window drawn by the SDK over your Flutter UI | the OS (Android `enterPictureInPictureMode`, iOS AVKit) |
/// | When | `enterPictureInPicture()`, a product tap with `actionOnNavigation = pip`, `presentationStyle: pip` | the app goes to the background while playing |
/// | Host setup | nothing | Android: `android:supportsPictureInPicture="true"` on the host Activity |
///
/// Without the Android manifest flag the player reports `PIP_ACTIVITY_NOT_DECLARED`
/// and stays in in-app PIP only. A `FlutterFragmentActivity` host is recommended —
/// the SDK registers its OS-PIP listener only on an androidx `ComponentActivity`.
///
/// ## Relationship with product landing
/// With `navigation.actionOnNavigation = pip` (the default), the SDK switches to PIP
/// by itself when a product tap navigates away. "Tap a product, video shrinks into a
/// corner" is that value, not something you implement.
///
/// ## Flutter differences
/// - `padding` is in **pixels**, not dp/pt.
/// - `aspectRatio` is ignored on iOS.
/// - `enterOSPipOnBackPressed` lives under `configuration.android`, not `pip`.
abstract final class ShoplivePipPresets {
  /// SDK defaults: both PIP kinds enabled, bottom-right, 9:16, 40% of the width.
  static const ShoplivePipOptions defaults = ShoplivePipOptions(
    isInAppPipEnabled: true,
    isOSPipEnabled: true,
    defaultPosition: ShoplivePipPosition.bottomRight,
    scale: 0.4,
    aspectRatio: ShoplivePipRatio.ratio9x16,
  );

  /// A small floating window inset from the screen edges — the usual choice when
  /// your app has a bottom navigation bar the window should not sit on.
  static ShoplivePipOptions floating({
    ShoplivePipPosition position = ShoplivePipPosition.bottomRight,
    double scale = 0.4,
    ShoplivePipRatio aspectRatio = ShoplivePipRatio.ratio9x16,
    int paddingPx = 48,
  }) => ShoplivePipOptions(
    isInAppPipEnabled: true,
    isOSPipEnabled: true,
    defaultPosition: position,
    scale: scale,
    aspectRatio: aspectRatio,
    padding: ShopliveInsets(left: paddingPx, top: paddingPx, right: paddingPx, bottom: paddingPx),
  );

  /// in-app PIP only — the SDK-drawn window, never the OS one.
  static ShoplivePipOptions inAppOnly({
    ShoplivePipPosition position = ShoplivePipPosition.bottomRight,
    double scale = 0.4,
  }) => ShoplivePipOptions(isInAppPipEnabled: true, isOSPipEnabled: false, defaultPosition: position, scale: scale);

  /// Back press shrinks to OS PIP instead of closing the player — Android only.
  static const ShoplivePlayerConfiguration osPipOnBackPressed = ShoplivePlayerConfiguration(
    pip: ShoplivePipOptions(isOSPipEnabled: true),
    android: ShopliveAndroidPlayerOptions(enterOSPipOnBackPressed: true),
  );

  /// No PIP at all — playback ends when the viewer leaves.
  static const ShoplivePipOptions disabled = ShoplivePipOptions(isInAppPipEnabled: false, isOSPipEnabled: false);
}
