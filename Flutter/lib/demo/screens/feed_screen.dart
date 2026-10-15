import 'package:flutter/material.dart';

import '../../shoplive_integration/shoplive_feed_preview.dart';
import '../demo_controller.dart';
import '../l10n/demo_strings.dart';
import '../widgets/common.dart';
import 'mission_list_screen.dart';

/// Mission 4 — the demo's own home feed, with the stream shown inside it.
///
/// The native demos embed a `ShoplivePlayerView` between the cards. Flutter SDK
/// 3.0.2 has no embeddable widget, so this screen starts the player directly in
/// in-app PIP — a muted preview floating over the feed — and promotes it to full
/// screen on demand. See `shoplive_integration/shoplive_feed_preview.dart`.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.controller});

  final DemoController controller;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _started = false;

  String get _campaignKey => widget.controller.effectiveCampaignKey;

  @override
  void initState() {
    super.initState();
    // Start after the first frame — the plugin needs a screen to present over.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    // The floating window is not part of this widget tree. Close it with the
    // screen, or it stays over the next one.
    if (_started) ShopliveFeedPreview.close();
    super.dispose();
  }

  Future<void> _start() async {
    if (_campaignKey.isEmpty) return;
    final ok = await ShopliveFeedPreview.start(_campaignKey);
    if (mounted) setState(() => _started = ok);
  }

  Future<void> _close() async {
    await ShopliveFeedPreview.close();
    if (mounted) setState(() => _started = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DemoShell(
      controller: widget.controller,
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Tip(tr('feed_tip_embed')),
          const SizedBox(height: 8),
          Tip(tr('feed_warn_activity_context'), tone: TipTone.warn),
          const SizedBox(height: 10),
          if (_campaignKey.isEmpty)
            Tip(tr('feed_warn_no_campaign'), tone: TipTone.warn)
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_started)
                  OutlinedButton(onPressed: _close, child: Text(tr('feed_btn_close')))
                else
                  FilledButton(onPressed: _start, child: Text(tr('feed_btn_start'))),
                OutlinedButton(onPressed: ShopliveFeedPreview.collapseToPip, child: Text(tr('feed_btn_pip'))),
                OutlinedButton(
                  onPressed: ShopliveFeedPreview.expandToFullScreen,
                  child: Text(tr('feed_btn_fullscreen')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Tip(tr('feed_warn_expand_restream'), tone: TipTone.ok),
          ],
          const SizedBox(height: 12),
          for (final i in [1, 2, 3, 4, 1, 2, 3, 4]) ...[
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('feed_card${i}_title'), style: text.titleSmall),
                          Text(tr('feed_card${i}_desc'), style: text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
