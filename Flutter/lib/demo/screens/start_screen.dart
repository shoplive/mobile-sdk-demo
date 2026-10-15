import 'package:flutter/material.dart';

import '../data/demo_defaults.dart';
import '../data/demo_store.dart';
import '../demo_controller.dart';
import '../l10n/demo_strings.dart';
import '../widgets/common.dart';

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
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                children: [
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
                  const SizedBox(height: 18),
                  _LanguagePicker(controller: c),
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

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tr('language_label'), style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6),
      SegmentedButton<DemoLanguage>(
        segments: [for (final l in DemoLanguage.values) ButtonSegment(value: l, label: Text(l.nativeName))],
        selected: {DemoStrings.language.value},
        onSelectionChanged: (s) => controller.setLanguage(s.first),
        showSelectedIcon: false,
      ),
      const SizedBox(height: 6),
      Text(tr('language_note'), style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
