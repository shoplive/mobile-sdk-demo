import 'package:flutter/services.dart';
import 'package:shoplive_player/shoplive_player.dart';

import 'shoplive_event_labels.dart';
import 'shoplive_log.dart';
import 'shoplive_player_presets.dart';

/// Starting full-screen playback.
///
/// The integration is three calls:
///
/// ```dart
/// await Shoplive.initialize(const ShopliveConfiguration(accessKey: '{ACCESS_KEY}')); // once, in main()
/// await Shoplive.setUser(const ShopliveUser.guest());                                // optional
/// await ShoplivePlayer.instance.start('{CAMPAIGN_KEY}');
/// ```
///
/// ## No context, no Activity — but there must be a screen
/// Unlike native Android, there is nothing to pass: the plugin presents the SDK
/// player over the top-most native screen (Android: the Flutter host Activity; iOS:
/// the top view controller). With no foreground screen, `start` fails with
/// `PlatformException(NO_HOST_SCREEN)` — so do not start from a background isolate
/// or before the first frame.
///
/// ## One player, a singleton
/// `ShoplivePlayer.instance` is the only player. Calling `start` while a session is
/// open switches the campaign in the same player (iOS) instead of opening a second.
/// Subscribe to its streams once — see `ShoplivePlayerEventLogger`.
abstract final class ShoplivePlayerLauncher {
  /// [configuration] is **merged** onto the current settings (see
  /// [ShoplivePlayerPresets]). [playOptions] apply to this call only.
  ///
  /// Returns false when the plugin refused the call (logged).
  static Future<bool> start(
    String campaignKey, {
    ShoplivePlayerConfiguration configuration = ShoplivePlayerPresets.defaults,
    ShoplivePlayOptions? playOptions,
  }) async {
    final options = playOptions ?? ShoplivePlayerPresets.playOptions();
    logCall(
      'ShoplivePlayer.instance.start("$campaignKey", referrer: ${options.referrer}, '
      'presentationStyle: ${options.presentationStyle?.name})',
    );
    try {
      await ShoplivePlayer.instance.start(campaignKey, playOptions: options, configuration: configuration);
      return true;
    } on PlatformException catch (e) {
      // INVALID_ARGUMENT here is usually presentationStyle: pip with
      // pip.isInAppPipEnabled false in the merged configuration.
      logError('start failed — ${platformExceptionLogLine(e)}');
      return false;
    }
  }
}
