import 'package:flutter/material.dart';
import 'package:shoplive_player/shoplive_player.dart';

import '../../shoplive_integration/shoplive_player_session.dart';
import '../data/demo_options.dart';
import '../l10n/demo_strings.dart';
import '../widgets/common.dart';

/// V2 — the app's own product screen, opened by a `navigation(url)` request.
///
/// This screen is the proof that the app routed the request: nothing in the SDK
/// opens a product page. With the default `actionOnNavigation = pip` the player
/// shrinks into its floating window and keeps playing over this screen.
class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.url, required this.options});

  final String url;
  final DemoOptionsStore options;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final action = options.value.actionOnNavigation;
    return Scaffold(
      appBar: AppBar(title: Text(tr('product_toolbar_title'), style: text.titleMedium)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          Tip(tr('product_tip_result'), tone: TipTone.ok),
          const SizedBox(height: 12),
          Text(tr('product_received_url'), style: text.labelMedium),
          const SizedBox(height: 4),
          SelectableText(url, style: text.bodySmall?.copyWith(fontFamily: 'monospace')),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Text('👕', style: TextStyle(fontSize: 72)),
            ),
          ),
          const SizedBox(height: 12),
          Text(tr('product_name'), style: text.titleLarge),
          Text(tr('product_price'), style: text.titleMedium?.copyWith(color: DemoColors.brand)),
          const SizedBox(height: 16),
          GroupLabel(
            'navigation.actionOnNavigation = ${action.name}'
            '${action == ShopliveNavigationAction.pip ? ' (${tr('product_action_default')})' : ''}',
          ),
          Tip(
            tr(switch (action) {
              ShopliveNavigationAction.keep => 'product_action_keep_desc',
              ShopliveNavigationAction.close => 'product_action_close_desc',
              _ => 'product_action_pip_desc',
            }),
          ),
          const SizedBox(height: 8),
          Tip(tr('product_warn_required'), tone: TipTone.warn),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ShoplivePlayerSession.exitPictureInPicture();
            },
            child: Text(tr('product_btn_exit_pip')),
          ),
          const SizedBox(height: 12),
          Tip(tr('product_tip_policy')),
        ],
      ),
    );
  }
}
