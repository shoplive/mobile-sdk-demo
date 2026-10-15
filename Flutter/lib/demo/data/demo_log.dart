import 'package:flutter/foundation.dart';

import '../../shoplive_integration/shoplive_log.dart';

/// The process-wide log that the developer sheet's "event log" tab reads.
///
/// This is the demo's own logger — `shoplive_integration/` never calls it. It
/// arrives here through [install], which sets it as the `shopliveLog` sink.
///
/// Events keep arriving while the SDK's player or studio is in front, and Flutter
/// cannot draw on top of those native screens, so they are collected here and read
/// after coming back.
///
/// `playback(rendering)` can arrive once per second, so (1) the log is capped at
/// [maxEntries] lines, and (2) an identical line repeated back-to-back bumps a
/// counter instead of adding a line.
class DemoLog extends ChangeNotifier {
  DemoLog._();

  static final DemoLog instance = DemoLog._();

  static const int maxEntries = 300;

  final List<DemoLogEntry> _entries = [];

  /// Newest first.
  List<DemoLogEntry> get entries => List.unmodifiable(_entries);

  /// Installs this log as the integration layer's sink. Call before any SDK call.
  static void install() {
    shopliveLog = (kind, message) {
      instance.add(kind, message);
      debugPrint('[Shoplive] ${kind.tag} $message');
    };
  }

  void add(ShopliveLogKind kind, String message) {
    final head = _entries.isEmpty ? null : _entries.first;
    if (head != null && head.kind == kind && head.message == message) {
      _entries[0] = head.copyWith(time: DateTime.now(), repeated: head.repeated + 1);
    } else {
      _entries.insert(0, DemoLogEntry(kind: kind, message: message, time: DateTime.now()));
      if (_entries.length > maxEntries) _entries.removeRange(maxEntries, _entries.length);
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  /// Plain text, for the copy button.
  String asPlainText() => _entries
      .map((e) {
        final times = e.repeated > 1 ? ' (x${e.repeated})' : '';
        return '[${e.timeText}] ${e.kind.name.toUpperCase()} ${e.message}$times';
      })
      .join('\n');
}

@immutable
class DemoLogEntry {
  const DemoLogEntry({required this.kind, required this.message, required this.time, this.repeated = 1});

  final ShopliveLogKind kind;
  final String message;
  final DateTime time;

  /// How many times this same message repeated in a row. 1 is not shown.
  final int repeated;

  String get timeText => '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}';

  DemoLogEntry copyWith({DateTime? time, int? repeated}) =>
      DemoLogEntry(kind: kind, message: message, time: time ?? this.time, repeated: repeated ?? this.repeated);

  static String _two(int v) => v.toString().padLeft(2, '0');
}
