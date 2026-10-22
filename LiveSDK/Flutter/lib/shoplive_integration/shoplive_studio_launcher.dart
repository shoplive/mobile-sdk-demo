import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shoplive_streamer/shoplive_streamer.dart';

import 'shoplive_event_labels.dart';
import 'shoplive_log.dart';

/// Broadcasting from the app — needs the `shoplive_streamer` package.
///
/// ```dart
/// await Shoplive.setStreamToken(streamerJwt);           // a different path from viewer auth
/// await ShopliveStreamer.instance.start(campaignKey);
/// ```
///
/// ## The stream token is not the viewer identity
/// `Shoplive.setUser(...)` is **who is watching**; `Shoplive.setStreamToken(...)` is
/// **permission to broadcast**. Setting one does not fill the other.
/// `Shoplive.logout()` clears both. Without a token the server returns no ingest
/// address and the studio shows a "failed to start" dialog.
///
/// ## The SDK provides the whole studio UI
/// Camera preview, switching, chat, settings and the countdown are SDK screens.
/// Resolution and bitrate are server-driven.
///
/// ## Host setup
/// - Android: declare `CAMERA` and `RECORD_AUDIO` in the manifest. The SDK asks for
///   the runtime permissions itself.
/// - iOS: `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` in
///   `Info.plist`, or iOS terminates the app when the studio asks for the camera.
///
/// ## Events before you subscribe are dropped
/// They are not replayed, so read `getState()` right after subscribing.
/// Every `start` call creates a new broadcast session.
abstract final class ShopliveStudioLauncher {
  static StreamSubscription<ShopliveStreamerEvent>? _events;
  static void Function()? _onBroadcastLive;
  static void Function(String logLine)? _onFatalError;

  /// [streamToken] blank means "do not start".
  /// [onBroadcastLive] called when the broadcast reaches `live`.
  /// [onFatalError] an unrecoverable streamer error, already formatted for a log.
  ///
  /// Returns true if a start was attempted and accepted by the plugin.
  static Future<bool> start(
    String campaignKey, {
    required String streamToken,
    void Function()? onBroadcastLive,
    void Function(String logLine)? onFatalError,
  }) async {
    if (streamToken.trim().isEmpty) {
      logError('No stream token — broadcasting requires one.');
      return false;
    }

    final streamer = ShopliveStreamer.instance;
    _onBroadcastLive = onBroadcastLive;
    _onFatalError = onFatalError;
    try {
      await Shoplive.setStreamToken(streamToken);
      logCall('Shoplive.setStreamToken("${shopliveMasked(streamToken)}")');

      // Subscribe once and keep it — the stream is shared by every session.
      _events ??= streamer.events.listen(_onEvent);
      // Read the state once, right after subscribing — earlier events are gone.
      logEvent('StreamerEvent subscribed — current state: ${(await streamer.getState()).name}');

      logCall('ShopliveStreamer.instance.start("$campaignKey")');
      await streamer.start(campaignKey);
      return true;
    } on PlatformException catch (e) {
      logError('studio start failed — ${platformExceptionLogLine(e)}');
      return false;
    }
  }

  static void _onEvent(ShopliveStreamerEvent event) {
    switch (event) {
      case ShopliveStreamerStateChanged(:final state, :final isRehearsal):
        // isRehearsal is null on iOS (the iOS SDK has no rehearsal flag).
        logEvent('StreamerEvent.stateChanged(${state.name}, isRehearsal: $isRehearsal)');
        if (state == ShopliveBroadcastState.live) _onBroadcastLive?.call();
      case ShopliveStreamerErrorEvent(:final error):
        final text =
            'StreamerEvent.error(code: ${error.code}, rawCode: ${error.rawCode}, '
            'recoverable: ${error.recoverable}) ${error.message}';
        logError(text);
        if (!error.recoverable) _onFatalError?.call(text);
      case ShopliveStreamerUnknownEvent(:final rawType):
        logEvent('StreamerEvent.unknown(rawType: "$rawType")');
    }
  }
}
