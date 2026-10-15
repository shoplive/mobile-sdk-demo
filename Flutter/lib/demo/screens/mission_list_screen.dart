import 'package:flutter/material.dart';

import '../data/demo_store.dart';
import '../data/missions.dart';
import '../demo_controller.dart';
import '../devtools/dev_sheet.dart';
import '../l10n/demo_strings.dart';
import '../widgets/common.dart';

/// The frame around S2 (feature list) and the feed: progress in the app bar, the
/// mode bar, the ⌗ developer button, and the Mission 2 push banner.
class DemoShell extends StatelessWidget {
  const DemoShell({super.key, required this.controller, required this.child, this.showBack = false});

  final DemoController controller;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListenableBuilder(
      listenable: Listenable.merge([c, c.progress]),
      builder:
          (context, _) => Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: showBack,
              title: Text(
                tr('topbar_progress', [c.progress.done.length]),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              actions: [
                IconButton(
                  tooltip: tr('cd_settings'),
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    c.openSettings();
                    Navigator.of(context).pushNamed(Routes.start);
                  },
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => showDevSheet(context, c, DevSheetTab.log),
              icon: const Text('⌗', style: TextStyle(fontSize: 18)),
              label: Text(tr('fab_developer')),
            ),
            body: Stack(
              children: [
                Column(children: [if (c.mode != null) _ModeBar(controller: c), Expanded(child: child)]),
                // Mission 2 — the fake push banner, shown over the list rather than on a
                // screen of its own.
                if (c.showPushBanner) Positioned(left: 12, right: 12, top: 12, child: _PushBanner(controller: c)),
              ],
            ),
          ),
    );
  }
}

class _ModeBar extends StatelessWidget {
  const _ModeBar({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final isOwn = c.mode == DemoMode.own;
    final tone = isOwn ? DemoColors.ok : Theme.of(context).colorScheme.primary;
    final modeText = isOwn ? tr('mode_own', [_masked(c.store.accessKey, tr('key_not_entered'))]) : tr('mode_tour');
    return Container(
      width: double.infinity,
      color: tone.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        tr('mode_auth_suffix', [modeText, c.authMethod.label]),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tone),
      ),
    );
  }

  static String _masked(String key, String blank) =>
      key.isEmpty ? blank : (key.length <= 8 ? key : '${key.substring(0, 8)}…');
}

class _PushBanner extends StatelessWidget {
  const _PushBanner({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: controller.onPushBannerTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('push_banner_source'), style: text.labelSmall?.copyWith(color: muted)),
              const SizedBox(height: 3),
              Text(tr('push_banner_title'), style: text.titleSmall),
              const SizedBox(height: 3),
              Text(
                '${controller.pushBannerLink}',
                style: text.labelSmall?.copyWith(fontFamily: 'monospace', color: muted),
              ),
              TextButton(onPressed: controller.dismissPushBanner, child: Text(tr('push_banner_dismiss'))),
            ],
          ),
        ),
      ),
    );
  }
}

/// The feature list, and effectively the app's only menu.
///
/// **Tapping a card runs it.** There is no screen in between showing steps or
/// code. "Verified" is decided automatically from SDK events.
class MissionListScreen extends StatelessWidget {
  const MissionListScreen({super.key, required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) => DemoShell(
    controller: controller,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Tip(tr('mission_list_tip')),
        const SizedBox(height: 9),
        for (final m in missions) ...[
          _MissionCard(
            mission: m,
            isDone: controller.progress.done.contains(m.number),
            lockReason: controller.lockReason(m),
            onTap: () => controller.runMission(m.number),
          ),
          const SizedBox(height: 9),
        ],
        const SizedBox(height: 4),
        Tip(tr('mission_list_code_tip'), tone: TipTone.ok),
        const SizedBox(height: 9),
        Tip(tr('mission_list_sdk_screen_tip'), tone: TipTone.warn),
      ],
    ),
  );
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.isDone, required this.lockReason, required this.onTap});

  final Mission mission;
  final bool isDone;
  final String? lockReason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isLocked = lockReason != null;
    return Card(
      elevation: 0,
      color: scheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: scheme.outline)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isDone ? DemoColors.ok : (isLocked ? scheme.outline : scheme.onSurface),
                    child: Text(
                      isDone ? '✓' : '${mission.number}',
                      style: text.labelMedium?.copyWith(
                        color: isLocked && !isDone ? scheme.onSurfaceVariant : scheme.surface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr(mission.titleKey), style: text.titleSmall),
                        Text(
                          tr(mission.descriptionKey),
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '✔ ${tr(mission.checkPointKey)}',
                          style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        SourcePathLine(mission.sourcePath),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isDone)
                    Pill(tr('badge_confirmed'), color: DemoColors.ok)
                  else
                    Icon(isLocked ? Icons.lock : Icons.chevron_right, color: scheme.outline),
                ],
              ),
              if (lockReason != null) ...[
                const SizedBox(height: 9),
                Tip(tr('lock_message', [lockReason]), tone: TipTone.warn),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
