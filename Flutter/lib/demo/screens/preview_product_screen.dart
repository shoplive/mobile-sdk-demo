import 'package:flutter/material.dart';
import 'package:shoplive_player/shoplive_player.dart';

import '../../shoplive_integration/shoplive_log.dart';
import '../../shoplive_integration/shoplive_player_session.dart';
import '../../shoplive_integration/shoplive_preview.dart';
import '../data/missions.dart';
import '../demo_controller.dart';
import '../l10n/demo_strings.dart';
import '../widgets/common.dart';
import 'mission_list_screen.dart';
import 'product_detail_screen.dart';

/// Preview mission — the app's own product page with a preview floating over it.
///
/// A screen of its own rather than [ProductDetailScreen], which already has another
/// job: it is where a product tap lands (events mission), and its "exit PIP" button
/// acts on the current session. Only the product itself ([ProductSummary]) is
/// shared.
///
/// The SDK-facing part is `shoplive_integration/shoplive_preview.dart`. What stays
/// here is *when* to call it: when the page becomes visible (first frame, another
/// route popped off it, app resumed) and when the page is gone for good (dispose).
class PreviewProductScreen extends StatefulWidget {
  const PreviewProductScreen({super.key, required this.controller});

  final DemoController controller;

  @override
  State<PreviewProductScreen> createState() => _PreviewProductScreenState();
}

class _PreviewProductScreenState extends State<PreviewProductScreen> with RouteAware {
  /// This page's preview. One per page instance: a new visit from the card is a
  /// new page, so "closed by the viewer" holds only for this page.
  final ShoplivePreviewSession _session = ShoplivePreviewSession();
  late final AppLifecycleListener _lifecycle;

  /// False until the page has been visible once. The first visit follows the
  /// viewer's card tap; later ones are automatic.
  bool _hasShown = false;

  /// A visibility decision is running (first frame, resume and pop can overlap).
  bool _deciding = false;

  DemoController get c => widget.controller;

  /// Every start path records its mission first. If another mission is running,
  /// someone else's `start` replaced this page's preview (no `closed` arrives then).
  bool get _isOurs => c.progress.activeMission == MissionId.preview;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onVisible);
    // After the first frame — the plugin needs a screen to present over.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onVisible());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) c.routeObserver.subscribe(this, route);
  }

  @override
  void didPopNext() => _onVisible();

  @override
  void dispose() {
    c.routeObserver.unsubscribe(this);
    _lifecycle.dispose();
    // A preview the viewer never expanded should not follow them around the app.
    // If another mission took over, the session on screen is not ours to close.
    if (_isOurs) {
      _session.leave();
    } else {
      _session.dispose();
    }
    super.dispose();
  }

  Future<void> _onVisible() async {
    if (_deciding || !mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _deciding = true;
    try {
      await _decide();
    } finally {
      _deciding = false;
    }
  }

  Future<void> _decide() async {
    final isFirstVisit = !_hasShown;
    _hasShown = true;
    if (!_isOurs) _session.forget();

    final missionBefore = c.progress.activeMission;
    final ongoing = ShoplivePreview.isOngoing(await ShoplivePlayerSession.state());
    // Another start path (a deep link, say) ran while we waited — that session wins.
    if (c.progress.activeMission != missionBefore) {
      logEvent('preview: ${c.progress.activeMission?.raw} started meanwhile — preview not started');
      return;
    }
    final visit = ShoplivePreview.onHostVisible(
      // Open = no closed event yet. The state read and the event stream are separate
      // channels, so a closed state without its event means "closing": wait for the
      // reason rather than re-showing a preview the viewer may have just closed.
      isShowing: _session.isOpen,
      lastCloseReason: _session.closeReason,
      otherSessionOngoing: !_session.isOpen && ongoing,
      isFirstVisit: isFirstVisit,
    );
    switch (visit) {
      case ShoplivePreviewVisit.start:
        if (!mounted) return;
        await c.startPreview(_session, closeOtherFirst: isFirstVisit && ongoing);
      case ShoplivePreviewVisit.alreadyShowing:
        logEvent('preview: still showing on this page — not started again');
      case ShoplivePreviewVisit.otherSessionOngoing:
        logEvent('preview: another session is up — not started, it would close that session');
      case ShoplivePreviewVisit.closedByViewer:
        logEvent(
          'preview: closed by the viewer (${ShopliveCloseReason.userAction.name}) on this page — not shown again',
        );
    }
  }

  @override
  Widget build(BuildContext context) => DemoShell(
    controller: c,
    showBack: true,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Text(tr('mission_badge', [MissionId.preview.number]), style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        const ProductSummary(),
        const SizedBox(height: 6),
        Text(tr('preview_product_desc'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (c.effectiveCampaignKey.isEmpty) ...[
          Tip(tr('feed_warn_no_campaign'), tone: TipTone.warn),
          const SizedBox(height: 8),
        ],
        Tip(tr('preview_tip_page'), tone: TipTone.ok),
        const SizedBox(height: 8),
        Tip(tr('preview_tip_reshow')),
        const SizedBox(height: 8),
        Tip(tr('preview_tip_leave'), tone: TipTone.warn),
      ],
    ),
  );
}
