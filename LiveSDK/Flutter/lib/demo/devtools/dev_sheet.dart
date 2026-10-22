import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shoplive_integration/shoplive_log.dart';
import '../data/demo_log.dart';
import '../data/missions.dart';
import '../demo_controller.dart';
import '../l10n/demo_strings.dart';
import '../widgets/common.dart';
import 'options_tab.dart';

/// V1 — the developer sheet: the event log and every configuration option.
Future<void> showDevSheet(BuildContext context, DemoController controller, DevSheetTab tab) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (context) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            builder:
                (context, scroll) => DefaultTabController(
                  length: 2,
                  initialIndex: tab == DevSheetTab.log ? 0 : 1,
                  child: Column(
                    children: [
                      TabBar(tabs: [Tab(text: tr('tab_event_log')), Tab(text: tr('tab_options'))]),
                      Expanded(
                        child: TabBarView(
                          children: [
                            const LogTab(),
                            OptionsTab(
                              controller: controller,
                              onReplay: () {
                                Navigator.of(context).pop();
                                controller.replayWithCurrentOptions();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );

class LogTab extends StatelessWidget {
  const LogTab({super.key});

  @override
  Widget build(BuildContext context) {
    final log = DemoLog.instance;
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        final entries = log.entries;
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
          children: [
            Tip(tr('log_note_engine_switch'), tone: TipTone.warn),
            const SizedBox(height: 6),
            Tip(tr('log_note_auto_recovery'), tone: TipTone.warn),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => Clipboard.setData(ClipboardData(text: log.asPlainText())),
                  child: Text(tr('log_copy')),
                ),
                TextButton(onPressed: log.clear, child: Text(tr('log_clear'))),
              ],
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(tr('log_empty'), textAlign: TextAlign.center, style: text.bodySmall),
              ),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${e.timeText} ',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      TextSpan(
                        text: '${e.kind.tag} ',
                        style: TextStyle(color: _color(e.kind), fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: e.message),
                      if (e.repeated > 1)
                        TextSpan(text: '  ×${e.repeated}', style: const TextStyle(color: DemoColors.info)),
                    ],
                  ),
                  style: text.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11.5),
                ),
              ),
          ],
        );
      },
    );
  }

  static Color _color(ShopliveLogKind kind) => switch (kind) {
    ShopliveLogKind.call => DemoColors.info,
    ShopliveLogKind.event => DemoColors.ok,
    ShopliveLogKind.request => DemoColors.brand,
    ShopliveLogKind.respond => const Color(0xFFA371F7),
    ShopliveLogKind.error => DemoColors.warn,
  };
}
