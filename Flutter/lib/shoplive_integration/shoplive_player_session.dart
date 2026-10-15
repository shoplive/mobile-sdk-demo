import 'package:flutter/services.dart';
import 'package:shoplive_player/shoplive_player.dart';

import 'shoplive_event_labels.dart';
import 'shoplive_log.dart';

/// Commands to the running player — things a configuration cannot change.
///
/// `setMuted`, `setResizeMode`, `setOverlayUI`, `reload`, `send` and the PIP
/// transitions are not configuration; they are commands to a running session. On
/// native you keep a player handle for this. In Flutter the handle is
/// `ShoplivePlayer.instance`, and "no session" comes back as
/// `PlatformException(NOT_RUNNING)` — which this class turns into a log line instead
/// of an uncaught error.
///
/// `close()` is the one command that succeeds with no session (idempotent).
abstract final class ShoplivePlayerSession {
  static ShoplivePlayer get _player => ShoplivePlayer.instance;

  static Future<bool> isRunning() async => await _guard('isRunning()', _player.isRunning, quiet: true) ?? false;

  static Future<void> setMuted(bool muted) => _guard('setMuted($muted)', () => _player.setMuted(muted));

  static Future<void> setResizeMode(ShopliveResizeMode mode) =>
      _guard('setResizeMode(${mode.name})', () => _player.setResizeMode(mode));

  /// Toggles the built-in overlay during playback. To be certain a value applies
  /// from the first frame, set `overlay.ui` in the configuration instead.
  static Future<void> setOverlayUI(ShopliveOverlayUIMode mode) =>
      _guard('setOverlayUI(${mode.name})', () => _player.setOverlayUI(mode));

  static Future<void> reload() => _guard('reload()', _player.reload);

  /// Sends a command into the overlay WebView — the app-to-overlay channel for
  /// anything the SDK does not model, e.g. highlighting a product your UI selected.
  static Future<void> send(String command, [Map<String, Object?>? payload]) =>
      _guard('send("$command", $payload)', () => _player.send(command, payload));

  static Future<void> enterPictureInPicture() => _guard('enterPictureInPicture()', _player.enterPictureInPicture);

  static Future<void> exitPictureInPicture() => _guard('exitPictureInPicture()', _player.exitPictureInPicture);

  static Future<void> stop() => _guard('stop()', _player.stop);

  static Future<void> close() => _guard('close()', _player.close);

  /// Reads the current state for display. Null when there is no session.
  static Future<ShoplivePlayerState?> state() => _guard('getState()', _player.getState, quiet: true);

  /// The full, merged configuration the next `start` will use.
  static Future<ShoplivePlayerConfiguration?> configuration() =>
      _guard('getConfiguration()', _player.getConfiguration, quiet: true);

  static Future<T?> _guard<T>(String label, Future<T> Function() call, {bool quiet = false}) async {
    try {
      final result = await call();
      if (!quiet) logCall('ShoplivePlayer.instance.$label');
      return result;
    } on PlatformException catch (e) {
      if (e.code == ShoplivePlatformErrorCode.notRunning) {
        if (!quiet) logError('$label — no running player. Start playback first.');
      } else {
        logError('$label failed — ${platformExceptionLogLine(e)}');
      }
      return null;
    }
  }
}
