import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoplive_player/shoplive_player.dart';

import '../../shoplive_integration/shoplive_event_labels.dart';
import '../../shoplive_integration/shoplive_log.dart';
import '../../shoplive_integration/shoplive_player_session.dart';
import '../data/demo_options.dart';
import '../demo_controller.dart';
import '../l10n/demo_strings.dart';
import '../widgets/common.dart';

/// The options tab: one control per `ShoplivePlayerConfiguration` field, the
/// per-playback `ShoplivePlayOptions`, and the runtime commands.
///
/// Configuration applies on the next `start` (▶ replay). Only the "controls" group
/// acts on the running session.
class OptionsTab extends StatefulWidget {
  const OptionsTab({super.key, required this.controller, required this.onReplay});

  final DemoController controller;
  final VoidCallback onReplay;

  @override
  State<OptionsTab> createState() => _OptionsTabState();
}

class _OptionsTabState extends State<OptionsTab> {
  bool _advanced = false;

  DemoOptionsStore get store => widget.controller.options;

  void _set(DemoOptions Function(DemoOptions) f) => store.update(f);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DemoOptions>(
    valueListenable: store,
    builder:
        (context, o, _) => ListView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 40),
          children: [
            Tip(tr('warn_config_merge')),

            // ── type ──────────────────────────────────────────────────────────
            GroupLabel(tr('group_playback_type')),
            Tip(tr('tip_playback_type')),
            _cycle(
              'type',
              o.type,
              const [ShoplivePlayerType.live, ShoplivePlayerType.preview],
              (v) => _set((o) => o.copyWith(type: v)),
              defaultValue: 'live',
            ),

            // ── auth ──────────────────────────────────────────────────────────
            GroupLabel(tr('group_auth')),
            Tip(tr('tip_auth')),

            // ── pip ───────────────────────────────────────────────────────────
            GroupLabel(tr('group_pip')),
            _toggle(
              'pip.isInAppPipEnabled',
              o.isInAppPipEnabled,
              (v) => _set((o) => o.copyWith(isInAppPipEnabled: v)),
              defaultValue: true,
            ),
            _toggle(
              'pip.isOSPipEnabled',
              o.isOSPipEnabled,
              (v) => _set((o) => o.copyWith(isOSPipEnabled: v)),
              defaultValue: true,
              warning: tr('warn_os_pip_activity_only'),
            ),
            _cycle(
              'pip.defaultPosition',
              o.pipPosition,
              _real(ShoplivePipPosition.values),
              (v) => _set((o) => o.copyWith(pipPosition: v)),
              defaultValue: 'bottomRight',
            ),
            _cycle(
              'pip.scale',
              o.pipScale,
              const [0.4, 0.3, 0.5, 0.6],
              (v) => _set((o) => o.copyWith(pipScale: v)),
              defaultValue: '0.4',
            ),
            _cycle(
              'pip.aspectRatio (Android)',
              o.pipAspectRatio,
              _real(ShoplivePipRatio.values),
              (v) => _set((o) => o.copyWith(pipAspectRatio: v)),
              defaultValue: 'ratio9x16',
            ),
            _cycle(
              'pip.padding (px, all sides)',
              o.pipPaddingPx,
              const [0, 24, 48, 96],
              (v) => _set((o) => o.copyWith(pipPaddingPx: v)),
              defaultValue: '0',
            ),

            // ── overlay · appearance ──────────────────────────────────────────
            GroupLabel(tr('group_overlay_appearance')),
            _cycle(
              'overlay.ui',
              o.overlayUI,
              const [ShopliveOverlayUIMode.builtIn, ShopliveOverlayUIMode.hidden],
              (v) => _set((o) => o.copyWith(overlayUI: v)),
              defaultValue: 'builtIn',
              warning: tr('warn_overlay_hidden'),
            ),
            _cycle(
              'appearance.indicatorColor',
              o.indicatorColor,
              IndicatorColor.values,
              (v) => _set((o) => o.copyWith(indicatorColor: v)),
              label: (c) => c.literalLabel ?? tr('value_white_default'),
              defaultValue: tr('value_white_default'),
            ),
            _toggle(
              'sound.muteOnStart',
              o.muteOnStart,
              (v) => _set((o) => o.copyWith(muteOnStart: v)),
              defaultValue: false,
              warning: tr('warn_mute_on_start'),
            ),

            // ── runtime controls ──────────────────────────────────────────────
            GroupLabel(tr('group_control')),
            Tip(tr('tip_control_runtime'), tone: TipTone.ok),
            _action('setMuted(true)', tr('action_call'), () => ShoplivePlayerSession.setMuted(true)),
            _action('setMuted(false)', tr('action_call'), () => ShoplivePlayerSession.setMuted(false)),
            _cycle('setResizeMode', o.resizeMode, const [ShopliveResizeMode.fill, ShopliveResizeMode.fit], (v) {
              _set((o) => o.copyWith(resizeMode: v));
              ShoplivePlayerSession.setResizeMode(v);
            }, defaultValue: 'fill'),
            _action(
              'setOverlayUI(hidden)',
              tr('action_call'),
              () => ShoplivePlayerSession.setOverlayUI(ShopliveOverlayUIMode.hidden),
            ),
            _action(
              'setOverlayUI(builtIn)',
              tr('action_call'),
              () => ShoplivePlayerSession.setOverlayUI(ShopliveOverlayUIMode.builtIn),
            ),
            _action('reload()', tr('action_call'), ShoplivePlayerSession.reload),
            _action(
              'send(command:)',
              tr('action_send'),
              () => ShoplivePlayerSession.send('HIGHLIGHT_PRODUCT', {'sku': 'A-1024'}),
            ),
            _action('enterPictureInPicture()', tr('action_enter'), ShoplivePlayerSession.enterPictureInPicture),
            _action('exitPictureInPicture()', tr('action_exit'), ShoplivePlayerSession.exitPictureInPicture),
            _action('stop()', tr('action_stop'), ShoplivePlayerSession.stop),
            _action('close()', tr('action_stop'), ShoplivePlayerSession.close),

            // ── session state (Flutter: everything is a Future) ───────────────
            GroupLabel(tr('group_runtime_state')),
            _action('getState() · isMuted() · isInPictureInPicture()', tr('action_read'), _logState),
            _action('getConfiguration()', tr('action_read'), _logConfiguration),

            // ── advanced ──────────────────────────────────────────────────────
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => setState(() => _advanced = !_advanced),
              child: Text(tr(_advanced ? 'advanced_collapse' : 'advanced_expand')),
            ),
            if (_advanced) ..._advancedFields(o),

            const SizedBox(height: 16),
            FilledButton(onPressed: widget.onReplay, child: Text(tr('btn_replay_with_options'))),
            TextButton(onPressed: store.reset, child: Text(tr('btn_reset_defaults'))),
          ],
        ),
  );

  List<Widget> _advancedFields(DemoOptions o) => [
    Tip(tr('advanced_note')),
    GroupLabel('sound'),
    _toggle(
      'sound.mixWithOthers',
      o.mixWithOthers,
      (v) => _set((o) => o.copyWith(mixWithOthers: v)),
      defaultValue: false,
    ),
    GroupLabel('navigation'),
    _cycle(
      'navigation.actionOnNavigation',
      o.actionOnNavigation,
      _real(ShopliveNavigationAction.values),
      (v) => _set((o) => o.copyWith(actionOnNavigation: v)),
      defaultValue: 'pip',
    ),
    _cycle(
      'navigation.shareScheme',
      o.shareScheme,
      const ['', 'myshop://share'],
      (v) => _set((o) => o.copyWith(shareScheme: v)),
      label: (v) => v.isEmpty ? tr('value_null_sdk_default') : v,
      defaultValue: 'null',
    ),
    GroupLabel('customParameters'),
    _cycle<Map<String, String>>(
      'customParameters',
      o.customParameters,
      const [
        {},
        {'channel': 'flutter_demo'},
      ],
      (v) => _set((o) => o.copyWith(customParameters: v)),
      label: (v) => '$v',
      defaultValue: '{}',
    ),
    GroupLabel('android (ignored on iOS)'),
    _toggle(
      'android.enterOSPipOnBackPressed',
      o.enterOSPipOnBackPressed,
      (v) => _set((o) => o.copyWith(enterOSPipOnBackPressed: v)),
      defaultValue: false,
    ),
    _cycle<bool?>(
      'android.isVolumeKeyEnabled',
      o.isVolumeKeyEnabled,
      const [null, true, false],
      (v) => _set((o) => o.copyWith(isVolumeKeyEnabled: () => v)),
      label: (v) => v == null ? tr('value_null_by_type') : '$v',
      defaultValue: 'null',
    ),
    _toggle(
      'android.autoResumeOnFocusGained',
      o.autoResumeOnFocusGained,
      (v) => _set((o) => o.copyWith(autoResumeOnFocusGained: v)),
      defaultValue: true,
    ),
    _toggle(
      'android.isStatusBarVisible',
      o.isStatusBarVisible,
      (v) => _set((o) => o.copyWith(isStatusBarVisible: v)),
      defaultValue: true,
    ),
    _toggle(
      'android.allowScreenCapture',
      o.allowScreenCapture,
      (v) => _set((o) => o.copyWith(allowScreenCapture: v)),
      defaultValue: true,
      warning: tr('warn_allow_screen_capture'),
    ),
    _toggle(
      'android.closeWhenAppDestroyed',
      o.closeWhenAppDestroyed,
      (v) => _set((o) => o.copyWith(closeWhenAppDestroyed: v)),
      defaultValue: true,
    ),
    GroupLabel(tr('group_play_options')),
    Tip(tr('tip_play_options')),
    _cycle(
      'playOptions.referrer',
      o.referrer,
      const ['', 'options_tab', 'home_banner'],
      (v) => _set((o) => o.copyWith(referrer: v)),
      label: (v) => v.isEmpty ? 'null' : '"$v"',
      defaultValue: 'null',
    ),
    _toggle(
      'playOptions.keepWindowStateOnPlayExecuted',
      o.keepWindowStateOnPlayExecuted,
      (v) => _set((o) => o.copyWith(keepWindowStateOnPlayExecuted: v)),
      defaultValue: false,
    ),
  ];

  Future<void> _logState() async {
    final player = ShoplivePlayer.instance;
    final state = await ShoplivePlayerSession.state();
    if (state == null) {
      logError('getState() — no running player.');
      return;
    }
    try {
      logCall(
        'getState() → ${state.name} · isMuted() → ${await player.isMuted()} · '
        'isInPictureInPicture() → ${await player.isInPictureInPicture()}',
      );
    } on PlatformException catch (e) {
      logCall('getState() → ${state.name}');
      logError('isMuted() / isInPictureInPicture() — ${platformExceptionLogLine(e)}');
    }
  }

  Future<void> _logConfiguration() async {
    final c = await ShoplivePlayerSession.configuration();
    if (c == null) return;
    logCall(
      'getConfiguration() → type: ${c.type?.name}, '
      'pip: {inApp: ${c.pip?.isInAppPipEnabled}, os: ${c.pip?.isOSPipEnabled}, '
      'position: ${c.pip?.defaultPosition?.name}, scale: ${c.pip?.scale}}, '
      'sound: {muteOnStart: ${c.sound?.muteOnStart}, mixWithOthers: ${c.sound?.mixWithOthers}}, '
      'overlay: ${c.overlay?.ui?.name}, navigation: ${c.navigation?.actionOnNavigation?.name}, '
      'indicatorColor: ${c.appearance?.indicatorColor?.toRadixString(16)}, '
      'customParameters: ${c.customParameters}',
    );
  }

  /// Enum values without the `unknown` the plugin uses for unrecognised wire values
  /// (sending `unknown` back fails with INVALID_ARGUMENT).
  static List<T> _real<T extends Enum>(List<T> values) => values.where((v) => v.name != 'unknown').toList();

  Widget _toggle(
    String name,
    bool value,
    ValueChanged<bool> onChanged, {
    required bool defaultValue,
    String? warning,
  }) => _OptionRow(
    name: name,
    defaultHint: tr('option_default_prefix', ['$defaultValue']),
    warning: warning,
    trailing: Switch(value: value, onChanged: onChanged),
  );

  Widget _cycle<T>(
    String name,
    T value,
    List<T> values,
    ValueChanged<T> onChanged, {
    String Function(T)? label,
    required String defaultValue,
    String? warning,
  }) {
    String show(T v) => label != null ? label(v) : (v is Enum ? v.name : '$v');
    return _OptionRow(
      name: name,
      defaultHint: tr('option_default_prefix', [defaultValue]),
      warning: warning,
      trailing: OutlinedButton(
        onPressed: () {
          final i = values.indexOf(value);
          onChanged(values[(i + 1) % values.length]);
        },
        child: Text(show(value)),
      ),
    );
  }

  Widget _action(String name, String actionLabel, Future<void> Function() onTap) =>
      _OptionRow(name: name, trailing: FilledButton.tonal(onPressed: onTap, child: Text(actionLabel)));
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.name, required this.trailing, this.defaultHint, this.warning});

  final String name;
  final Widget trailing;
  final String? defaultHint;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: text.bodySmall?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                    if (defaultHint != null)
                      Text(
                        defaultHint!,
                        style: text.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
          if (warning != null) ...[const SizedBox(height: 4), Tip(warning!, tone: TipTone.warn)],
        ],
      ),
    );
  }
}
