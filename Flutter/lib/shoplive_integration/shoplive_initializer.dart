import 'package:flutter/services.dart';
import 'package:shoplive_player/shoplive_player.dart';

import 'shoplive_event_labels.dart';
import 'shoplive_log.dart';

/// SDK initialization — done **once** for the whole app.
///
/// ```dart
/// await Shoplive.initialize(const ShopliveConfiguration(accessKey: '{ACCESS_KEY}'));
/// ```
///
/// Put it in `main()`, after `WidgetsFlutterBinding.ensureInitialized()`. A deep
/// link can cold-start the app (see `ShopliveDeepLinkRouter`), and initialization
/// has to be finished before the player starts, otherwise playback fails with
/// `NOT_INITIALIZED_ACCESS_KEY`. **Await it** — every Flutter SDK call is async, and
/// a `start` that races an unawaited `initialize` is the Flutter form of that bug.
///
/// To switch accounts, call [initialize] again — the last access key wins. To also
/// change *who* the viewer is, call [logout] first: that is what clears the
/// authentication slots.
abstract final class ShopliveInitializer {
  static String? _initializedAccessKey;

  static bool get isInitialized => _initializedAccessKey != null;

  static String? get currentAccessKey => _initializedAccessKey;

  /// [allowedWebViewDomains] restricts the domains the overlay WebView may open.
  /// Null means the SDK default (no restriction).
  ///
  /// [attribution] UTM parameters. A **full replace** — you cannot change one field.
  ///
  /// Returns false when the SDK refused the call (the reason is logged).
  static Future<bool> initialize(
    String accessKey, {
    List<String>? allowedWebViewDomains,
    ShopliveAttribution? attribution,
  }) async {
    try {
      await Shoplive.initialize(
        ShopliveConfiguration(
          accessKey: accessKey,
          allowedWebViewDomains: allowedWebViewDomains,
          attribution: attribution,
        ),
      );
      _initializedAccessKey = accessKey;
      logCall('Shoplive.initialize(accessKey: "${shopliveMasked(accessKey)}")');
      logCall(
        'SDK version ${await Shoplive.getSdkVersion()} · '
        'plugin ${ShoplivePlayer.pluginVersion}',
      );
      return true;
    } on PlatformException catch (e) {
      logError('Shoplive.initialize failed — ${platformExceptionLogLine(e)}');
      return false;
    }
  }

  /// Initializes only if it has not happened yet, or the access key changed.
  /// Calling initialize repeatedly with the same key is harmless; this guard exists
  /// to keep the log readable.
  static Future<void> initializeIfNeeded(String accessKey) async {
    if (accessKey.trim().isEmpty) return;
    if (_initializedAccessKey == accessKey) return;
    await initialize(accessKey);
  }

  /// Releases the authenticated identity — user, auth token and stream token, all
  /// three slots at once. The access key and UTM values survive.
  ///
  /// `setUser(ShopliveUser.guest())` does **not** do this.
  static Future<void> logout() async {
    try {
      await Shoplive.logout();
      logCall('Shoplive.logout() — cleared user/authToken/streamToken');
    } on PlatformException catch (e) {
      logError('Shoplive.logout failed — ${platformExceptionLogLine(e)}');
    }
  }

  // ── Key format pre-check ───────────────────────────────────────────────────
  //
  // There is no API to ask the SDK whether a key is valid (initialize just stores
  // it). So the only thing worth doing locally is catching malformed input — real
  // validity shows up as an error event on the first play attempt.

  /// Null means valid. Use the [ShopliveKeyProblem] to pick your own localized text.
  static ShopliveKeyProblem? validate(String accessKey, String campaignKey) {
    if (accessKey.trim().isEmpty || campaignKey.trim().isEmpty) return ShopliveKeyProblem.keysRequired;
    if (accessKey.contains(RegExp(r'\s'))) return ShopliveKeyProblem.accessKeyWhitespace;
    if (campaignKey.contains(RegExp(r'\s'))) return ShopliveKeyProblem.campaignKeyWhitespace;
    return null;
  }
}

enum ShopliveKeyProblem {
  keysRequired('accessKey and campaignKey are required.'),

  /// Copy-paste from a console usually gains a trailing space or newline.
  accessKeyWhitespace('accessKey contains whitespace. Check whether it was truncated when copied.'),
  campaignKeyWhitespace('campaignKey contains whitespace.');

  const ShopliveKeyProblem(this.defaultMessage);

  final String defaultMessage;
}
