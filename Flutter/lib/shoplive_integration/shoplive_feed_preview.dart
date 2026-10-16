import 'package:shoplive_player/shoplive_player.dart';

import 'shoplive_player_launcher.dart';
import 'shoplive_player_presets.dart';
import 'shoplive_player_session.dart';

/// Showing a stream inside your own screen — the Flutter way.
///
/// ## There is no embeddable player widget in Flutter SDK 3.0.2
/// Native has `ShoplivePlayerView` (Android) / an embeddable view (iOS) that you
/// place in your own layout. The Flutter plugin 3.0.2 has **no** `PlatformView`
/// widget: the player is always a native screen presented over Flutter.
///
/// The closest equivalent — and the documented replacement for the 1.x
/// `showPreview` — is to start the player **directly in in-app PIP**, as a small
/// muted preview floating over your Flutter screen:
///
/// ```dart
/// await ShoplivePlayer.instance.start(campaignKey,
///   playOptions: const ShoplivePlayOptions(presentationStyle: ShoplivePresentationStyle.pip),
///   configuration: const ShoplivePlayerConfiguration(
///     type: ShoplivePlayerType.preview,
///     pip: ShoplivePipOptions(isInAppPipEnabled: true),
///   ));
/// ```
///
/// What that means for your layout:
/// - The window floats; it does not scroll with your content. Position it with
///   `pip.defaultPosition` / `padding` so it does not cover your key UI.
/// - `presentationStyle: pip` requires `pip.isInAppPipEnabled: true` in the
///   **merged** configuration, otherwise `start` fails with `INVALID_ARGUMENT`.
/// - Events and requests arrive on the same streams as full screen.
/// - [expandToFullScreen] is `exitPictureInPicture()` on the running session, not a
///   new `start`. Measured on iOS (2026-10-15): `stateChanged(loading)` follows it;
///   whether the stream is re-fetched was not verified.
abstract final class ShopliveFeedPreview {
  static Future<bool> start(
    String campaignKey, {
    ShoplivePipPosition position = ShoplivePipPosition.bottomRight,
    double scale = 0.45,
  }) => ShoplivePlayerLauncher.start(
    campaignKey,
    configuration: ShoplivePlayerConfiguration(
      type: ShoplivePlayerType.preview,
      sound: const ShopliveSoundOptions(muteOnStart: true),
      pip: ShoplivePipOptions(isInAppPipEnabled: true, defaultPosition: position, scale: scale),
    ),
    playOptions: ShoplivePlayerPresets.playOptions(
      referrer: 'feed_preview',
      presentationStyle: ShoplivePresentationStyle.pip,
    ),
  );

  /// Promotes the floating preview to full screen.
  static Future<void> expandToFullScreen() => ShoplivePlayerSession.exitPictureInPicture();

  /// Shrinks the full-screen player back into the floating window.
  static Future<void> collapseToPip() => ShoplivePlayerSession.enterPictureInPicture();

  /// Removes the preview. Call it when your screen goes away — the floating window
  /// is not tied to any widget's lifecycle.
  static Future<void> close() => ShoplivePlayerSession.close();
}
