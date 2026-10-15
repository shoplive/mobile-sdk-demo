import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shoplive_integration/shoplive_deep_link_router.dart';
import '../shoplive_integration/shoplive_initializer.dart';
import '../shoplive_integration/shoplive_log.dart';
import '../shoplive_integration/shoplive_player_event_logger.dart';
import '../shoplive_integration/shoplive_player_launcher.dart';
import '../shoplive_integration/shoplive_studio_launcher.dart';
import '../shoplive_integration/shoplive_user_setup.dart';
import 'data/demo_defaults.dart';
import 'data/demo_log.dart';
import 'data/demo_options.dart';
import 'data/demo_store.dart';
import 'data/missions.dart';
import 'l10n/demo_strings.dart';

/// Route names. The SDK's player and studio are native screens owned by the SDK,
/// so they have no route — the only "running" screen this app owns is the feed.
abstract final class Routes {
  static const start = '/start';
  static const missions = '/missions';
  static const feed = '/feed';
  static const product = '/product';
}

/// Screen state and the "tap a card, it runs" flow.
///
/// Running a mission calls the SDK directly, with no screen in between. The code is
/// read in the project sources; the app is for watching it behave.
///
/// This class is also where the demo meets the copy-paste layer: it supplies the
/// callbacks `shoplive_integration/` asks for (navigate, failure, milestone, coupon
/// text) and keeps every piece of demo state on this side of the line.
class DemoController extends ChangeNotifier {
  DemoController({required this.store, required this.progress, required this.options}) {
    mode = store.mode;
    accessKeyInput = store.accessKey.isEmpty ? DemoDefaults.accessKey : store.accessKey;
    campaignKeyInput = store.campaignKey.isEmpty ? DemoDefaults.campaignKey : store.campaignKey;
    streamTokenInput = store.streamToken.isEmpty ? DemoDefaults.streamToken : store.streamToken;
    userJwtInput = store.userJwt;
    ownFormExpanded = mode == DemoMode.own && store.accessKey.isEmpty;
  }

  final DemoStore store;
  final MissionProgress progress;
  final DemoOptionsStore options;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  /// One event receiver for the app's whole life, so the log does not split and
  /// coupon requests always have a listener. Attached in [attach].
  ///
  /// The four callbacks are everything the copy-paste layer needs from this app.
  /// Note what each keeps on this side: routing (this app's Navigator), localized
  /// text (this app's strings), mission progress (demo-only state).
  late final ShoplivePlayerEventLogger playerEvents = ShoplivePlayerEventLogger(
    onNavigation: openProduct,
    onFailure: _reportFailure,
    onMilestone: progress.record,
    couponMessage: (_) => tr('coupon_issued'),
  );

  StreamSubscription<Uri>? _links;

  // ── UI state ───────────────────────────────────────────────────────────────

  DemoMode? mode;
  String accessKeyInput = '';
  String campaignKeyInput = '';
  String streamTokenInput = '';
  String userJwtInput = '';
  bool ownFormExpanded = false;
  ShopliveUserMethod authMethod = ShopliveUserMethod.guest;

  /// Whether the fake push banner is showing (Mission 2).
  bool showPushBanner = false;

  /// Why the start screen rejected the input.
  String? validationError;

  /// One-shot messages for the SnackBar. The screen drains it.
  final ValueNotifier<String?> message = ValueNotifier(null);

  /// One-shot request to open the developer sheet on a tab.
  final ValueNotifier<DevSheetTab?> devSheetRequest = ValueNotifier(null);

  void attach() {
    playerEvents.attach();
    // Mission 2. app_links 6.x emits the cold-start link on this same stream, so
    // one subscription covers both cold and warm starts.
    _links = AppLinks().uriLinkStream.listen(_onIncomingLink, onError: (Object e) => logError('app_links: $e'));
  }

  @override
  void dispose() {
    _links?.cancel();
    playerEvents.detach();
    super.dispose();
  }

  // ── Effective credentials ──────────────────────────────────────────────────

  String get effectiveAccessKey => switch (mode) {
    DemoMode.own => store.accessKey,
    DemoMode.tour => DemoDefaults.accessKey,
    null => '',
  };

  String get effectiveCampaignKey => switch (mode) {
    DemoMode.own => store.campaignKey,
    DemoMode.tour => DemoDefaults.campaignKey,
    null => '',
  };

  String get effectiveStreamToken => switch (mode) {
    DemoMode.own => store.streamToken,
    DemoMode.tour => DemoDefaults.streamToken,
    null => '',
  };

  /// Why a card is locked. Null means it can run.
  ///
  /// A stream token is required even in tour mode: without one the studio opens but
  /// cannot go live, so the card is locked and says why.
  String? lockReason(Mission mission) {
    if (mode == null) return tr('lock_need_mode');
    if (effectiveAccessKey.isEmpty || effectiveCampaignKey.isEmpty) return tr('lock_need_keys');
    if (mission.needsStreamToken && effectiveStreamToken.isEmpty) return tr('lock_need_stream_token');
    return null;
  }

  // ── Start screen ───────────────────────────────────────────────────────────

  void toggleOwnForm() {
    ownFormExpanded = !ownFormExpanded;
    validationError = null;
    notifyListeners();
  }

  /// Tour mode — initialize immediately with the built-in demo keys.
  Future<bool> startTour() async {
    if (!DemoDefaults.hasDemoKeys) {
      validationError = tr('msg_demo_keys_missing');
      notifyListeners();
      return false;
    }
    store.mode = DemoMode.tour;
    await ShopliveInitializer.initialize(DemoDefaults.accessKey);
    authMethod = await _applyAuthMethod(ShopliveUserMethod.guest);
    mode = DemoMode.tour;
    validationError = null;
    notifyListeners();
    return true;
  }

  /// Own credentials — validate the input, then initialize.
  Future<bool> startOwn() async {
    final accessKey = accessKeyInput.trim();
    final campaignKey = campaignKeyInput.trim();

    final problem = ShopliveInitializer.validate(accessKey, campaignKey);
    if (problem != null) {
      validationError = tr(switch (problem) {
        ShopliveKeyProblem.keysRequired => 'validate_keys_required',
        ShopliveKeyProblem.accessKeyWhitespace => 'validate_access_key_whitespace',
        ShopliveKeyProblem.campaignKeyWhitespace => 'validate_campaign_key_whitespace',
      });
      notifyListeners();
      return false;
    }

    store
      ..accessKey = accessKey
      ..campaignKey = campaignKey
      ..streamToken = streamTokenInput.trim()
      ..userJwt = userJwtInput.trim()
      ..mode = DemoMode.own;

    await ShopliveInitializer.initialize(accessKey);
    authMethod = await _applyAuthMethod(ShopliveUserMethod.guest);
    mode = DemoMode.own;
    validationError = null;
    notifyListeners();
    showMessage(tr('msg_validation_ok'));
    return true;
  }

  /// Back to the start screen (the gear icon). Credentials are kept.
  void openSettings() {
    ownFormExpanded = mode == DemoMode.own;
    validationError = null;
    notifyListeners();
  }

  // ── Running a mission ──────────────────────────────────────────────────────

  Future<void> runMission(int number) async {
    final mission = missionOf(number);
    final lock = lockReason(mission);
    if (lock != null) {
      showMessage(lock);
      return;
    }

    progress.startMission(number);

    switch (mission.run) {
      case MissionRun.player:
        _openSheetFor(mission);
        await _launchPlayer();
      case MissionRun.deepLink:
        // No dedicated screen — a banner over the list.
        showPushBanner = true;
        notifyListeners();
      case MissionRun.auth:
        final method = await _askAuthMethod();
        if (method != null) await chooseAuthMethod(method);
      case MissionRun.feed:
        _openSheetFor(mission);
        navigatorKey.currentState?.pushNamed(Routes.feed);
      case MissionRun.studio:
        _openSheetFor(mission);
        await _launchStudio();
    }
  }

  void _openSheetFor(Mission mission) {
    if (mission.openSheet != null) devSheetRequest.value = mission.openSheet;
  }

  Future<void> _launchPlayer({String? referrerOverride}) async {
    final o = options.value;
    await ShoplivePlayerLauncher.start(
      effectiveCampaignKey,
      // Demo-only assembly: every options-tab field at once. A customer app would
      // pass one of the ShoplivePlayerPresets instead.
      configuration: DemoConfigurationFactory.from(o),
      playOptions: DemoConfigurationFactory.playOptions(o, referrerOverride: referrerOverride),
    );
  }

  /// The options tab's "replay with these options".
  Future<void> replayWithCurrentOptions() async {
    if (effectiveCampaignKey.isEmpty) {
      showMessage(tr('msg_no_campaign_key'));
      return;
    }
    progress.startMission(7);
    await _launchPlayer();
  }

  Future<void> _launchStudio() async {
    final started = await ShopliveStudioLauncher.start(
      effectiveCampaignKey,
      streamToken: effectiveStreamToken,
      onBroadcastLive: progress.markBroadcastLive,
      onFatalError: showMessage,
    );
    if (!started) showMessage(tr('msg_studio_not_started'));
  }

  // ── Deep link ──────────────────────────────────────────────────────────────

  Uri get pushBannerLink => ShopliveDeepLinkRouter.linkUri(
    scheme: DemoConfig.deepLinkScheme,
    campaignKey: effectiveCampaignKey,
    referrer: 'push_demo',
  );

  void dismissPushBanner() {
    showPushBanner = false;
    notifyListeners();
  }

  /// Banner tap fires a **real** link at this app through the OS, so it goes
  /// through the real intent-filter / URL scheme and the real app_links path.
  Future<void> onPushBannerTap() async {
    showPushBanner = false;
    notifyListeners();
    final uri = pushBannerLink;
    logCall('test deep link fired — $uri');
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) logError('launchUrl($uri) returned false — is the scheme registered?');
    } catch (e) {
      logError('launchUrl($uri) failed — $e');
    }
  }

  void _onIncomingLink(Uri uri) {
    final link = ShopliveDeepLinkRouter.parse(uri, scheme: DemoConfig.deepLinkScheme);
    if (link == null) return;
    // Cold start: the link can arrive before the first frame. Starting the player
    // then fails with NO_HOST_SCREEN, so wait for a frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _playFromDeepLink(link));
  }

  Future<void> _playFromDeepLink(ShopliveLink link) async {
    final accessKey = effectiveAccessKey;
    if (accessKey.isEmpty) {
      showMessage(tr('msg_deeplink_no_access_key'));
      return;
    }
    // Cold-start safety — make sure initialization finished before playing.
    await ShopliveInitializer.initializeIfNeeded(accessKey);
    progress.startMission(2);
    final o = options.value;
    await ShoplivePlayerLauncher.start(
      link.campaignKey,
      configuration: DemoConfigurationFactory.from(o),
      playOptions: DemoConfigurationFactory.playOptions(o, referrerOverride: link.referrer),
    );
  }

  // ── Auth method ────────────────────────────────────────────────────────────

  Future<ShopliveUserMethod?> _askAuthMethod() async {
    final context = navigatorKey.currentContext;
    if (context == null) return null;
    return showDialog<ShopliveUserMethod>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(tr('auth_dialog_title'), style: Theme.of(context).textTheme.titleMedium),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('auth_dialog_note'), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                for (final method in ShopliveUserMethod.values)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(method),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text('${method.label} — ${tr('auth_${method.name}_desc')}'),
                    ),
                  ),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('auth_dialog_cancel')))],
          ),
    );
  }

  Future<void> chooseAuthMethod(ShopliveUserMethod method) async {
    final applied = await _applyAuthMethod(method);
    authMethod = applied;
    notifyListeners();
    if (applied != method) showMessage(tr('msg_token_needs_jwt'));
    progress.startMission(3);
    await _launchPlayer();
  }

  /// The demo's profile values live here, not in `shoplive_integration/` — a
  /// customer app passes its own logged-in user the same way.
  Future<ShopliveUserMethod> _applyAuthMethod(ShopliveUserMethod method) => ShopliveUserSetup.apply(
    method,
    jwt: store.userJwt,
    profile: ShopliveUserSetup.exampleProfile(name: tr('demo_user_name')),
  );

  // ── Product detail (navigation requests) ───────────────────────────────────

  /// Opens the destination of a navigation request.
  ///
  /// When it arrives the SDK player is usually in front. With the default
  /// `actionOnNavigation = pip` the SDK shrinks itself into PIP, uncovering this
  /// app — so pushing a Flutter route is enough.
  void openProduct(String url) {
    navigatorKey.currentState?.pushNamed(Routes.product, arguments: url);
  }

  // ── Failures ───────────────────────────────────────────────────────────────

  void _reportFailure(ShopliveFailure failure) {
    switch (failure.kind) {
      case ShopliveFailureKind.repeatedPlaybackFailure:
        showMessage(tr('err_playback_failed', [failure.code]));
      case ShopliveFailureKind.unrecoverableError:
        final cause = failure.cause == null ? '' : tr('err_${_causeKey(failure.cause!.name)}');
        showMessage('$cause (code: ${failure.code})'.trim());
    }
  }

  /// accessKey → access_key, matching the Android string resource names.
  static String _causeKey(String name) => name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

  // ── Misc ───────────────────────────────────────────────────────────────────

  void showMessage(String text) => message.value = text;

  void resetProgress() {
    progress.reset();
    DemoLog.instance.clear();
    showMessage(tr('msg_progress_reset'));
  }

  void setLanguage(DemoLanguage lang) {
    store.setLanguage(lang);
    notifyListeners();
  }
}
