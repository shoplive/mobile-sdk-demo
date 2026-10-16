import 'package:flutter/material.dart';

import '../data/demo_defaults.dart';
import '../data/demo_store.dart';
import '../data/qr_credentials.dart';
import '../demo_controller.dart';
import '../l10n/demo_strings.dart';
import '../widgets/common.dart';
import 'qr_scan_screen.dart';

/// S1 — choose a mode: the built-in demo campaign, or your own keys.
///
/// Both paths end in `Shoplive.initialize`. The keys are only format-checked here;
/// the SDK has no "is this key valid?" API, so real validity shows up on the first
/// playback as an error event.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key, required this.controller});

  final DemoController controller;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late final TextEditingController _accessKey = TextEditingController(text: widget.controller.accessKeyInput);
  late final TextEditingController _campaignKey = TextEditingController(text: widget.controller.campaignKeyInput);
  late final TextEditingController _streamToken = TextEditingController(text: widget.controller.streamTokenInput);
  late final TextEditingController _userJwt = TextEditingController(text: widget.controller.userJwtInput);

  DemoController get c => widget.controller;

  @override
  void dispose() {
    _accessKey.dispose();
    _campaignKey.dispose();
    _streamToken.dispose();
    _userJwt.dispose();
    super.dispose();
  }

  /// Opens the scanner and copies what the QR carries into the form fields.
  Future<void> _scanQr() async {
    final qr = await Navigator.of(context).push<QrCredentials>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (qr == null || !mounted) return;
    c.applyQrCredentials(qr);
    _accessKey.text = c.accessKeyInput;
    _campaignKey.text = c.campaignKeyInput;
    _streamToken.text = c.streamTokenInput;
    _userJwt.text = c.userJwtInput;
  }

  void _proceed() => Navigator.of(context).pushNamedAndRemoveUntil(Routes.missions, (_) => false);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder:
              (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  // Language first and fixed in place: below the collapsible form it
                  // jumped up and down every time the form opened or closed.
                  Align(alignment: Alignment.centerRight, child: _LanguagePicker(controller: c)),
                  const SizedBox(height: 12),
                  Text(tr('start_title'), style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(tr('start_subtitle'), style: text.bodyMedium),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () async {
                      if (await c.startTour() && mounted) _proceed();
                    },
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: Text(tr('start_tour_button')),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(DemoDefaults.hasDemoKeys ? 'start_tour_hint_ready' : 'start_tour_hint_missing'),
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    onPressed: c.toggleOwnForm,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    child: Text(tr('start_own_button', [c.ownFormExpanded ? '▲' : '▼'])),
                  ),
                  if (c.ownFormExpanded) ..._ownForm(text),
                  if (c.validationError != null) ...[
                    const SizedBox(height: 10),
                    Tip(c.validationError!, tone: TipTone.warn),
                  ],
                  if (c.mode != null) ...[
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _proceed,
                      child: Text(
                        tr('start_back_to_missions', [
                          tr(c.mode == DemoMode.own ? 'mode_label_own' : 'mode_label_tour'),
                        ]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Tip(tr('start_code_tip'), tone: TipTone.ok),
                ],
              ),
        ),
      ),
    );
  }

  List<Widget> _ownForm(TextTheme text) => [
    const SizedBox(height: 12),
    Text(tr('start_own_tip'), style: text.bodySmall),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      onPressed: _scanQr,
      icon: const Icon(Icons.qr_code_scanner),
      label: Text(tr('qr_button')),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
    ),
    const SizedBox(height: 12),
    _field(_accessKey, 'field_access_key', 'field_access_key_hint', (v) => c.accessKeyInput = v),
    _field(_campaignKey, 'field_campaign_key', 'field_campaign_key_hint', (v) => c.campaignKeyInput = v),
    _field(_streamToken, 'field_stream_token', 'field_stream_token_hint', (v) => c.streamTokenInput = v),
    _field(_userJwt, 'field_user_jwt', 'field_user_jwt_hint', (v) => c.userJwtInput = v),
    const SizedBox(height: 6),
    FilledButton.tonal(
      onPressed: () async {
        if (await c.startOwn() && mounted) _proceed();
      },
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
      child: Text(tr('start_validate_button')),
    ),
    const SizedBox(height: 8),
    Tip(tr('start_validation_tip')),
    const SizedBox(height: 6),
    Text(tr('start_storage'), style: text.bodySmall),
  ];

  Widget _field(TextEditingController ctl, String label, String hint, ValueChanged<String> onChanged) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctl,
      onChanged: onChanged,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        labelText: tr(label),
        helperText: tr(hint),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

/// Compact, top-right language switch. The note that explains it ("app-level, not
/// the device language") moves into the tooltip so the header stays one row.
class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Tooltip(
        message: '${tr('language_label')} — ${tr('language_note')}',
        triggerMode: TooltipTriggerMode.tap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.language, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
      SegmentedButton<DemoLanguage>(
        segments: [for (final l in DemoLanguage.values) ButtonSegment(value: l, label: Text(l.nativeName))],
        selected: {DemoStrings.language.value},
        onSelectionChanged: (s) => controller.setLanguage(s.first),
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
    ],
  );
}
