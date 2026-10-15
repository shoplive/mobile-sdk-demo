import 'dart:async';

import 'package:shoplive_player/shoplive_player.dart';

import 'shoplive_event_labels.dart';
import 'shoplive_log.dart';

/// Events, products and coupons — subscribes to everything the player emits, logs
/// it, and hands the app-specific decisions back to you through callbacks.
///
/// The Flutter SDK talks to your app through **streams** on
/// `ShoplivePlayer.instance` (native SDKs use a delegate):
///
/// - `events` — notifications. Handle the ones you care about.
/// - `navigationRequests` — a product or banner was tapped. Open it.
/// - `couponRequests` / `customWebActionRequests` — requests that **need your
///   answer** via `request.respond(...)`.
///
/// ## Something must own the subscriptions
/// The streams only deliver while subscribed. Call [attach] once at app start and
/// keep this object alive for the app's lifetime — not per screen. In particular:
/// with **no** listener on `couponRequests`, the plugin answers coupons at once with
/// `success: false`; when every request listener is cancelled, pending requests are
/// answered with that same fallback.
///
/// ## Navigation is the only one you must handle
/// If nobody listens to `navigationRequests`, tapping a product does nothing at all.
/// That is why [onNavigation] is required.
///
/// ## Not calling respond looks like a freeze — then a failure
/// The coupon popup only dismisses once `respond` has been called. Without it the
/// plugin falls back after the request timeout (default 10 s,
/// `setRequestTimeout` 1–120 s) with `success: false`. This class logs REQUEST and
/// RESPOND as a pair — a REQUEST with no RESPOND after it is the bug.
///
/// ## Two things that never reach the log
/// 1. **Engine switches (HLS <-> WebRTC) are not events.** Network conditions are
///    only observable through the rebuffering signals in `playback`.
/// 2. **Issues being auto-recovered are not errors.** An `error` event arrives only
///    when the session dies unrecoverably (`recoverable = false`).
class ShoplivePlayerEventLogger {
  ShoplivePlayerEventLogger({
    required this.onNavigation,
    this.onFailure,
    this.onMilestone,
    this.couponMessage,
    ShoplivePlayer? player,
  }) : _player = player ?? ShoplivePlayer.instance;

  /// The URL of a product or banner the viewer tapped. Open it — nothing else will.
  final void Function(String url) onNavigation;

  /// Something the viewer should be told about. See [ShopliveFailure].
  final void Function(ShopliveFailure failure)? onFailure;

  /// Progress signals, if your app tracks them. Ignore it and nothing breaks.
  final void Function(ShopliveMilestone milestone)? onMilestone;

  /// The text shown in the coupon popup, localized by you. Null shows no message.
  final String? Function(String couponId)? couponMessage;

  final ShoplivePlayer _player;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// Consecutive playback failures. Reset when playback works or a session starts.
  int _consecutiveFailures = 0;

  /// Whether this session already reported a failure, so we do not repeat every 5s.
  bool _failureNotified = false;

  /// Report after this many consecutive failures — one can be transient.
  static const int failureThreshold = 2;

  bool get isAttached => _subscriptions.isNotEmpty;

  /// Subscribes to all four streams. Idempotent.
  void attach() {
    if (isAttached) return;
    _subscriptions
      ..add(_player.events.listen(_onEvent))
      ..add(_player.navigationRequests.listen(_onNavigation))
      ..add(_player.couponRequests.listen(_onCoupon))
      ..add(_player.customWebActionRequests.listen(_onCustomAction));
    logEvent('ShoplivePlayer streams subscribed (events, navigation, coupon, customWebAction)');
  }

  /// Cancels the subscriptions. Pending coupon/custom requests get the fallback.
  Future<void> detach() async {
    final subs = List.of(_subscriptions);
    _subscriptions.clear();
    for (final s in subs) {
      await s.cancel();
    }
  }

  void _onEvent(ShoplivePlayerEvent event) {
    switch (event) {
      case ShoplivePlayerStateChanged(:final state):
        logEvent('stateChanged(${state.name})');
        switch (state) {
          // A new session starts here. This logger is reused across sessions, so
          // the failure counters reset at this point.
          case ShoplivePlayerState.loading:
            _consecutiveFailures = 0;
            _failureNotified = false;
          case ShoplivePlayerState.inAppPip:
            onMilestone?.call(ShopliveMilestone.inAppPipEntered);
          default:
            break;
        }
      case ShopliveCampaignStatusChanged(:final status):
        logEvent('campaignStatusChanged(${status.name})');
      case ShopliveCampaignInfoReceived(:final info):
        logEvent(
          'campaignInfoReceived(campaignKey: "${info.campaignKey}", '
          'title: ${info.title}, status: ${info.status?.name})',
        );
      case ShoplivePlaybackEvent():
        logEvent('playback(${playbackLogLabel(event)})');
        switch (event.kind) {
          case ShoplivePlaybackEventKind.started:
            _consecutiveFailures = 0;
            onMilestone?.call(ShopliveMilestone.playbackStarted);
          case ShoplivePlaybackEventKind.rendering:
            _consecutiveFailures = 0;
          // Repeated failures never arrive as an error event — see below.
          case ShoplivePlaybackEventKind.failed:
            _onRepeatedPlaybackFailure(event.code);
          default:
            break;
        }
      case ShopliveConnectionStateChanged(:final state):
        logEvent('connectionStateChanged(${state.name})');
      case ShopliveAnalyticsEvent():
        logEvent(
          'analytics(campaignKey: "${event.campaignKey}", isPlaying: ${event.isPlaying}, '
          'isMuted: ${event.isMuted}, durationMs: ${event.durationMs})',
        );
      case ShopliveWebCommandReceived(:final name, :final payload):
        logEvent('webCommandReceived(name: "$name", payload: $payload)');
      case ShopliveUserNameUpdateRequested(:final payload):
        logEvent('userNameUpdateRequested($payload)');
      case ShoplivePlayerErrorEvent(:final error):
        _onError(error);
      case ShoplivePlayerUnknownEvent(:final rawType):
        logEvent('unknown(rawType: "$rawType")');
    }
  }

  // ── The one request you must handle ────────────────────────────────────────

  void _onNavigation(ShopliveNavigationRequest request) {
    logRequest('navigation(url: "${request.url}") — the app MUST handle this');
    onMilestone?.call(ShopliveMilestone.requestReceived);
    onNavigation(request.url);
    logRespond('→ navigation handled by the app');
  }

  // ── respond is what dismisses the popup ────────────────────────────────────

  Future<void> _onCoupon(ShopliveCouponRequest request) async {
    logRequest('coupon(id: "${request.couponId}") received');
    onMilestone?.call(ShopliveMilestone.requestReceived);

    // A real app calls its coupon server here and responds with the result.
    // Awaiting a server round-trip first is fine — just answer before the timeout.
    final delivered = await request.respond(
      ShopliveCouponResult(
        success: true,
        status: ShopliveResultStatus.hide,
        message: couponMessage?.call(request.couponId),
        alertType: ShopliveResultAlertType.toast,
      ),
    );
    _logDelivery('respond(success: true, status: hide, alertType: toast)', delivered);
  }

  Future<void> _onCustomAction(ShopliveCustomWebActionRequest request) async {
    logRequest(
      'customWebAction(id: "${request.id}", type: "${request.actionType}", '
      'payload: ${request.payload})',
    );
    onMilestone?.call(ShopliveMilestone.requestReceived);
    final delivered = await request.respond(
      const ShopliveCustomActionResult(success: true, status: ShopliveResultStatus.hide),
    );
    _logDelivery('respond(success: true, status: hide)', delivered);
  }

  /// `respond` returns false when the request was already answered — by the
  /// timeout fallback, by another listener, or after the plugin detached.
  void _logDelivery(String call, bool delivered) {
    if (delivered) {
      logRespond('→ $call called');
    } else {
      logError('→ $call too late — the request was already answered with the fallback');
    }
  }

  void _onError(ShopliveError error) {
    final line = errorLogLine(error);
    logError(line);
    // Anything the SDK is still recovering from does not get here. If it did
    // arrive unrecoverable, the session is over — tell the viewer.
    //
    // Measured on iOS (Flutter 3.0.2, 2026-10-15): a campaign with no stream sends
    // the same `recoverable: false` error on every retry (~5 s) while the session
    // stays open, so report it once per session like the playback failures below.
    if (!error.recoverable && !_failureNotified) {
      _failureNotified = true;
      onFailure?.call(
        ShopliveFailure(
          kind: ShopliveFailureKind.unrecoverableError,
          cause: errorCauseOf(error),
          code: error.code,
          logLine: line,
        ),
      );
    }
  }

  /// Reports repeated playback failure.
  ///
  /// Measured on the native SDKs (2026-07-30, SDK 3.0.0): a campaign that is not on
  /// air produces `playback(failed)` every ~5 seconds, and **no `error` event ever
  /// arrives**. Counting `playback(failed)` is the only signal available. On iOS the
  /// Flutter plugin sends `failed` with `code: null`.
  void _onRepeatedPlaybackFailure(int? code) {
    _consecutiveFailures += 1;
    if (_failureNotified || _consecutiveFailures < failureThreshold) return;
    _failureNotified = true;

    final codeText = code?.toString() ?? '-';
    final line =
        'playback keeps failing (code: $codeText) after '
        '$_consecutiveFailures attempts — no stream available';
    logError(line);
    onFailure?.call(
      ShopliveFailure(kind: ShopliveFailureKind.repeatedPlaybackFailure, cause: null, code: codeText, logLine: line),
    );
  }
}

enum ShopliveFailureKind {
  /// Playback failed repeatedly. Usually: the campaign has no live stream.
  repeatedPlaybackFailure,

  /// The session ended and the SDK will not retry.
  unrecoverableError,
}

/// Something went wrong in a way the viewer should hear about.
///
/// Handed to you as data rather than as a finished sentence, so the text stays in
/// your app's localized resources. [logLine] is the English detail already written
/// to the log; use it for bug reports, not for the UI.
///
/// ## Where to show it
/// When this arrives the SDK player is usually on top of your Flutter UI (a native
/// Activity / view controller), so a SnackBar in your own Scaffold is hidden behind
/// it until the viewer comes back.
class ShopliveFailure {
  const ShopliveFailure({required this.kind, required this.cause, required this.code, required this.logLine});

  final ShopliveFailureKind kind;

  /// Null for [ShopliveFailureKind.repeatedPlaybackFailure].
  final ShopliveErrorCause? cause;

  /// SDK error code, or the playback code. "-" when the SDK gave none.
  final String code;
  final String logLine;
}

/// Playback progress worth recording, for apps that track it.
enum ShopliveMilestone {
  /// The stream is actually playing (not merely requested).
  playbackStarted,

  /// The video moved into the SDK's floating window.
  inAppPipEntered,

  /// A request arrived that the app had to answer (navigation, coupon, custom).
  requestReceived,
}
