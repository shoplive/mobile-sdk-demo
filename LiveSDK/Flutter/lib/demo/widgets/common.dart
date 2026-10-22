import 'package:flutter/material.dart';

/// Colours shared with the native demos (`Android/.../ui/theme/Theme.kt`).
abstract final class DemoColors {
  static const brand = Color(0xFFFF2D55);
  static const ok = Color(0xFF2EA043);
  static const warn = Color(0xFFD29922);
  static const info = Color(0xFF4C9AFF);
}

ThemeData demoTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: DemoColors.brand, brightness: brightness).copyWith(
    primary: DemoColors.brand,
    surface: dark ? const Color(0xFF161B22) : Colors.white,
    onSurface: dark ? const Color(0xFFE6EDF3) : const Color(0xFF111111),
    onSurfaceVariant: dark ? const Color(0xFF9AA7B6) : const Color(0xFF6B7280),
    outline: dark ? const Color(0xFF2A3140) : const Color(0xFFDCDFE5),
    surfaceContainerHighest: dark ? const Color(0xFF1C2230) : const Color(0xFFF2F3F6),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF0E1117) : const Color(0xFFFAFAFC),
    useMaterial3: true,
  );
}

enum TipTone { info, ok, warn }

/// A small coloured note. The native demos use the same three tones.
class Tip extends StatelessWidget {
  const Tip(this.text, {super.key, this.tone = TipTone.info});

  final String text;
  final TipTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      TipTone.info => DemoColors.info,
      TipTone.ok => DemoColors.ok,
      TipTone.warn => DemoColors.warn,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
    child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
  );
}

/// "📄 lib/shoplive_integration/..." — the bridge from a card to the source file.
class SourcePathLine extends StatelessWidget {
  const SourcePathLine(this.path, {super.key});

  final String path;

  @override
  Widget build(BuildContext context) => Text(
    '📄 $path',
    style: Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(fontFamily: 'monospace', color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
  );
}
