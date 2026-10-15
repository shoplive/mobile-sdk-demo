/// The single hole through which this package emits log lines.
///
/// Files in this folder never call `print`, `debugPrint` or the demo app's event log
/// directly. They call [shopliveLog], which does nothing by default. That is what
/// makes them copyable: an app that copies these files gets silence until it opts
/// in, and never a missing-symbol error.
///
/// ## Wiring it up (one line, in `main()`)
/// ```dart
/// shopliveLog = (kind, message) => debugPrint('${kind.tag} $message');
/// ```
///
/// If you do not want any of it, delete this file and the `logCall(...)` /
/// `logEvent(...)` calls in the other files. Nothing else depends on it.
library;

enum ShopliveLogKind {
  /// App -> SDK. An API call we made (initialize / setUser / start ...).
  call('→SDK'),

  /// SDK -> app notification (`ShoplivePlayer.instance.events`).
  event('EVENT'),

  /// SDK -> app request (`navigationRequests` / `couponRequests` / ...). The app
  /// has to answer these.
  request('REQUEST'),

  /// The answer we sent back (`request.respond(...)`).
  respond('RESPOND'),

  /// Something failed.
  error('ERROR');

  const ShopliveLogKind(this.tag);

  final String tag;
}

/// Log sink. No-op until the host app replaces it.
///
/// Set this once, early (`main()`), before any Shoplive call.
///
/// Log text is intentionally NOT localized: it records SDK API names and event
/// payloads for developers, and translating those makes them harder to match
/// against the SDK reference.
void Function(ShopliveLogKind kind, String message) shopliveLog = (_, __) {};

void logCall(String message) => shopliveLog(ShopliveLogKind.call, message);
void logEvent(String message) => shopliveLog(ShopliveLogKind.event, message);
void logRequest(String message) => shopliveLog(ShopliveLogKind.request, message);
void logRespond(String message) => shopliveLog(ShopliveLogKind.respond, message);
void logError(String message) => shopliveLog(ShopliveLogKind.error, message);

/// Shortens a secret to its first 8 characters for logging.
///
/// Access keys, JWTs and stream tokens end up in log lines that get copied into
/// bug reports and crash reporters. Never log them whole.
String shopliveMasked(String? value) {
  if (value == null || value.trim().isEmpty) return '(none)';
  if (value.length <= 8) return '$value…';
  return '${value.substring(0, 8)}…';
}
