import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shoplive_player/shoplive_player.dart';

import 'shoplive_event_labels.dart';
import 'shoplive_log.dart';

/// A preview — a silent small window floating over one of your screens (a product
/// page, say) that invites a viewer who has **not** started watching yet. Tapping
/// it grows the same session to full screen with sound; the SDK does that, so there
/// is nothing for you to call.
///
/// The Flutter plugin (3.0.4+) makes it one call:
///
/// ```dart
/// await ShoplivePlayer.instance.startPreview('{CAMPAIGN_KEY}');
/// ```
///
/// It uses the SDK preview presets only (preview stream, muted, overlay hidden,
/// started in the small window). What you saved with `setConfiguration` is kept for
/// the next `start`, not applied here.
///
/// A viewer who is already watching and moves to another screen gets PIP instead
/// (see `ShoplivePipPresets`); the window looks the same, the purpose does not.
///
/// ## What startPreview decides for you
/// - A viewing session is showing (a `start` player, or a preview the viewer
///   expanded): **nothing happens**. Close it first if your screen should win.
/// - A preview with the same key is showing: it is kept.
///
/// ## The guide's recommendations, as code
/// - Not again on the same screen once the viewer closed it ([onHostVisible]).
/// - A preview nobody expanded belongs to the screen it floats over: when that
///   screen goes away, close it ([ShoplivePreviewSession.leave]). One the viewer
///   expanded is now a viewing session and is left alone.
/// - Not while the campaign is not live — your policy, see
///   [ShoplivePreviewSession.start] `closeWhenNotLive`.
abstract final class ShoplivePreview {
  /// Decides whether the host screen should start a preview. Only a viewer's own
  /// close ([ShopliveCloseReason.userAction]) holds it back; a close the app caused,
  /// an access-key change, or no known reason does not.
  ///
  /// - [isShowing]: this screen's preview is starting or showing.
  /// - [lastCloseReason]: why this screen's previous preview closed, if one did.
  /// - [otherSessionOngoing]: a session that is not this screen's preview is
  ///   starting or showing (a PIP the viewer is watching, say).
  /// - [isFirstVisit]: the screen is showing for the first time (the viewer just
  ///   opened it). Then the preview starts like any other explicit start, after
  ///   closing the other session; [otherSessionOngoing] only holds back re-showing.
  static ShoplivePreviewVisit onHostVisible({
    required bool isShowing,
    required ShopliveCloseReason? lastCloseReason,
    required bool otherSessionOngoing,
    required bool isFirstVisit,
  }) {
    if (isShowing) return ShoplivePreviewVisit.alreadyShowing;
    if (otherSessionOngoing && !isFirstVisit) return ShoplivePreviewVisit.otherSessionOngoing;
    if (lastCloseReason == ShopliveCloseReason.userAction) return ShoplivePreviewVisit.closedByViewer;
    return ShoplivePreviewVisit.start;
  }

  /// States in which a session is starting or on screen.
  static bool isOngoing(ShoplivePlayerState? state) => switch (state) {
    ShoplivePlayerState.loading ||
    ShoplivePlayerState.playing ||
    ShoplivePlayerState.paused ||
    ShoplivePlayerState.inAppPip => true,
    _ => false,
  };
}

/// What to do when the host screen becomes visible.
enum ShoplivePreviewVisit {
  /// Nothing running and nothing against it — start one.
  start,

  /// This screen's preview is still up (back from another screen, app resumed).
  alreadyShowing,

  /// Coming back while another session is starting or playing. Re-showing a
  /// preview would close it, and a viewer who is watching is not the one to invite.
  otherSessionOngoing,

  /// The viewer closed it on this screen. Do not push it again.
  closedByViewer,
}

/// What one host screen's preview has shown about itself, recorded from
/// `ShoplivePlayer.instance.events`. Create one per host screen.
///
/// ## One player in Flutter
/// `ShoplivePlayer.instance` is the only player, so its `events` are always about
/// the current session. A `start` elsewhere in your app replaces this preview
/// **without** a `closed` event — the host must know when someone else took over
/// and call [forget].
class ShoplivePreviewSession {
  /// [isCurrent] tells whether the player session is still this preview's. The
  /// player is a singleton and another `start` replaces the preview without a
  /// `closed`, so events and a late `close()` are checked against it.
  ShoplivePreviewSession({ShoplivePlayer? player, bool Function()? isCurrent})
    : _player = player ?? ShoplivePlayer.instance,
      _isCurrent = isCurrent ?? _always;

  static bool _always() => true;

  final ShoplivePlayer _player;
  final bool Function() _isCurrent;
  StreamSubscription<ShoplivePlayerEvent>? _events;

  bool _isOpen = false;

  /// A state of this preview arrived. A `closed` before that belongs to the
  /// session the host closed right before starting this one.
  bool _sawOwnState = false;
  bool _sawSmallWindow = false;
  bool _wasExpanded = false;
  ShopliveCloseReason? _closeReason;
  bool _closeWhenNotLive = false;

  /// Started and not reported closed.
  bool get isOpen => _isOpen;

  /// Why the last preview of this session closed. Null while it runs or before it.
  ShopliveCloseReason? get closeReason => _closeReason;

  /// The viewer grew the small window to full screen at least once.
  bool get wasExpanded => _wasExpanded;

  /// Starts the preview. Returns false when the plugin refused the call (logged).
  ///
  /// [closeWhenNotLive] is the guide's "do not show it while not live", as a
  /// switch: when the campaign is not live and the viewer never expanded the
  /// window, it is closed. Off keeps VOD and upcoming campaigns visible.
  Future<bool> start(String campaignKey, {bool closeWhenNotLive = false}) async {
    _events ??= _player.events.listen(_onEvent);
    _closeWhenNotLive = closeWhenNotLive;
    _isOpen = true;
    _sawOwnState = false;
    _sawSmallWindow = false;
    _wasExpanded = false;
    _closeReason = null;
    logCall('ShoplivePlayer.instance.startPreview("$campaignKey") — SDK preview presets, small muted window');
    try {
      await _player.startPreview(campaignKey);
      return true;
    } on PlatformException catch (e) {
      // INVALID_ARGUMENT: blank key. NO_HOST_SCREEN: no screen yet.
      // Android SDK_ERROR: not initialized, or the window could not open.
      _isOpen = false;
      logError('startPreview failed — ${platformExceptionLogLine(e)}');
      return false;
    }
  }

  /// Someone else's `start` replaced this preview (no `closed` arrives for it).
  /// Stops treating it as open; a close reason recorded earlier is kept.
  void forget() => _isOpen = false;

  /// Call when the host screen is gone for good. Closes the preview unless the
  /// viewer expanded it; `close()` reports `appRequest`. Also stops listening.
  ///
  /// Not expanded is the safe default: if the expansion signal never arrived and
  /// the window cannot be read, it is treated as the screen's own and closed.
  Future<void> leave() async {
    await _events?.cancel();
    _events = null;
    if (!_isOpen) {
      logEvent('preview host left — the preview had already closed (${_closeReason?.name ?? 'never started'})');
      return;
    }
    if (_wasExpanded || (_sawSmallWindow && await _isOutOfSmallWindow())) {
      logEvent('preview host left — the viewer expanded it, so it keeps playing');
      return;
    }
    if (!_isCurrent()) {
      _isOpen = false;
      logEvent('preview host left — another session replaced the preview, left alone');
      return;
    }
    logCall('ShoplivePlayer.instance.close() — preview host left before it was expanded');
    try {
      await _player.close();
    } on PlatformException catch (e) {
      logError('close failed — ${platformExceptionLogLine(e)}');
    }
  }

  /// Stops listening without touching the player.
  Future<void> dispose() async {
    await _events?.cancel();
    _events = null;
  }

  void _onEvent(ShoplivePlayerEvent event) {
    if (!_isOpen) return;
    if (!_isCurrent()) {
      forget();
      return;
    }
    switch (event) {
      case ShoplivePlayerStateChanged(state: ShoplivePlayerState.closed, :final closeReason):
        if (!_sawOwnState) return;
        _isOpen = false;
        _closeReason = closeReason;
      case ShoplivePlayerStateChanged(:final state):
        _sawOwnState = true;
        if (state == ShoplivePlayerState.inAppPip) {
          _sawSmallWindow = true;
        } else if (state == ShoplivePlayerState.playing && _sawSmallWindow && !_wasExpanded) {
          // A preview starts in the small window and can report playing while still
          // small, so "expanded" = playing again after the window **and** out of it.
          unawaited(_checkExpanded());
        }
      case ShopliveCampaignStatusChanged(:final status) when status != ShopliveCampaignStatus.live:
        // TODO(SDP-VERIFY): 요확인 — 라이브가 아닌 캠페인에서 프리뷰 작은 창이 무엇을 보여 주는지(대기 화면 / 즉시 닫힘·closeReason)는 SDK 동작, 실측 필요
        unawaited(_onNotLive(status));
      default:
        break;
    }
  }

  Future<void> _onNotLive(ShopliveCampaignStatus status) async {
    if (_wasExpanded) {
      logEvent('preview: campaign is ${status.name} — expanded by the viewer, kept');
    } else if (!_closeWhenNotLive) {
      logEvent('preview: campaign is ${status.name} — kept (closeWhenNotLive is off)');
    } else {
      logCall('ShoplivePlayer.instance.close() — preview campaign is ${status.name}, not live');
      try {
        await _player.close();
      } on PlatformException catch (e) {
        logError('close failed — ${platformExceptionLogLine(e)}');
      }
    }
  }

  Future<void> _checkExpanded() async {
    if (await _isOutOfSmallWindow() && _isOpen && !_wasExpanded) {
      _wasExpanded = true;
      logEvent('preview expanded to full screen — now a viewing session');
    }
  }

  Future<bool> _isOutOfSmallWindow() async {
    try {
      return !await _player.isInPictureInPicture();
    } on PlatformException {
      return false; // no session to read — treat as not expanded
    }
  }
}
