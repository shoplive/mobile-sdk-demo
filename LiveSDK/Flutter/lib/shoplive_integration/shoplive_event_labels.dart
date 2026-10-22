import 'package:flutter/services.dart';
import 'package:shoplive_player/shoplive_player.dart';

/// Human-readable labels for SDK values.
///
/// These are the smallest helpers that make SDK values readable in a log, and you
/// need them the moment you start reading logs — so they are part of the copyable
/// set, not the demo harness.
///
/// The English text here is a *default*. If your app shows any of it to users, map
/// [ShopliveErrorCause] to your own localized text instead of printing
/// [ShopliveErrorCause.defaultMessage]; log lines themselves stay English.

/// Short label used in log lines.
String playbackLogLabel(ShoplivePlaybackEvent event) => switch (event.kind) {
  ShoplivePlaybackEventKind.failed => 'failed(code: ${event.code}, message: ${event.message})',
  final kind => kind.name,
};

/// Why playback failed, grouped by what the app should do about it.
///
/// The SDK has no "is this key valid?" API — `Shoplive.initialize` only stores the
/// value. So a bad access key, a missing campaign, an auth problem and a dead
/// network are all told apart *after* a play attempt, from the error event.
enum ShopliveErrorCause {
  /// initialize was never called, or the access key is wrong.
  accessKey('Invalid key — accessKey is not set. Call initialize first.'),
  campaignNotFound('Campaign not found — check the campaignKey.'),
  notOnAir('The campaign is not on air. Check whether it is VOD and its scheduled time.'),

  /// The viewer identity is missing, expired, or rejected. See ShopliveUserSetup.
  authRequired('Authentication required — check user authentication.'),
  network('Network — check your connection. (The SDK is attempting automatic recovery.)'),
  server('Server error — try again shortly.'),
  other('Other error');

  const ShopliveErrorCause(this.defaultMessage);

  final String defaultMessage;
}

/// Maps an SDK error code onto the cause groups above.
///
/// `ShopliveError.code` is an opaque string. Both platforms send the Android
/// UPPER_SNAKE constant names (`CAMPAIGN_NOT_FOUND`, ...), so one table covers both.
ShopliveErrorCause errorCauseOf(ShopliveError error) => switch (error.code) {
  'NOT_INITIALIZED_ACCESS_KEY' => ShopliveErrorCause.accessKey,
  'CAMPAIGN_NOT_FOUND' => ShopliveErrorCause.campaignNotFound,
  'CAMPAIGN_NOT_ON_AIR' || 'LIVE_NOT_BROADCASTING' => ShopliveErrorCause.notOnAir,
  'AUTHENTICATION_FAILED' ||
  'GUEST_LOGIN_NOT_ALLOWED' ||
  'CUSTOM_ACCOUNT_NOT_FOUND' ||
  'CUSTOM_ACCOUNT_EXPIRED' ||
  'INVALID_SIGNATURE' ||
  'DUPLICATE_SESSION' ||
  'EXPIRED_SESSION' => ShopliveErrorCause.authRequired,
  'CONNECTION_ISSUE' || 'FAILED_NETWORK' => ShopliveErrorCause.network,
  'SERVER_ERROR' => ShopliveErrorCause.server,
  _ => ShopliveErrorCause.other,
};

/// One log line carrying everything needed to diagnose the error: the raw codes,
/// whether the SDK will keep trying, and the grouped cause.
String errorLogLine(ShopliveError error) =>
    'error(code: ${error.code}, rawCode: ${error.rawCode}, recoverable: ${error.recoverable}) '
    '${errorCauseOf(error).defaultMessage} · ${error.message}';

/// Every Flutter SDK method returns a Future that fails with a [PlatformException].
/// This is the one-line form of it for the log.
///
/// | code | meaning |
/// | --- | --- |
/// | `INVALID_ARGUMENT` | missing, blank, unknown or out-of-range value |
/// | `NO_HOST_SCREEN` | no foreground screen to show the player or studio on |
/// | `NOT_RUNNING` | a session command was sent with no player session running |
/// | `SDK_ERROR` | the native SDK call failed — `details` carries the class and code |
String platformExceptionLogLine(PlatformException e) =>
    'PlatformException(code: ${e.code}, message: ${e.message}, details: ${e.details})';
