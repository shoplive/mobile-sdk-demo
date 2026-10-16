/// Credentials read from a QR code — the same QR codes the native SDK test apps scan.
///
/// ## Format (from the native test apps)
/// The QR holds a URL. Only its query parameters matter; scheme, host and path are
/// ignored:
///
/// ```
/// https://<any>?ak=<accessKey>&ck=<campaignKey>&title=<title>&userjwt=<JWT>&st=<streamToken>
/// ```
///
/// | Key | Field | Source |
/// | --- | --- | --- |
/// | `ak` | accessKey | Android `CampaignListActivity`, iOS `SLQRReaderViewController` / `QRReaderViewController` |
/// | `ck` | campaignKey | same |
/// | `title` | label only | same (falls back to "Unknown Title (QR)") |
/// | `userjwt` | user JWT (Mission 3) | iOS PlayerDemo2 `SLQRReaderViewController` |
/// | `st` | stream token (Mission 8) | **new in this demo** — no native test app reads a stream token from QR |
///
/// ## Rules
/// - Native apps read `ak` and `ck` together, or neither. This demo does the same:
///   one without the other is rejected, so a half-filled key pair never replaces a
///   working one.
/// - `userjwt` and `st` may come alone (PlayerDemo2 accepts a JWT-only QR).
/// - Blank values count as missing. Values are trimmed.
/// - The Android app also derives a dev flag from `host.contains("dev")`. This demo
///   has no dev environment, so the host is ignored.
class QrCredentials {
  const QrCredentials({this.accessKey, this.campaignKey, this.title, this.userJwt, this.streamToken});

  static const String keyAccessKey = 'ak';
  static const String keyCampaignKey = 'ck';
  static const String keyTitle = 'title';
  static const String keyUserJwt = 'userjwt';
  static const String keyStreamToken = 'st';

  final String? accessKey;
  final String? campaignKey;
  final String? title;
  final String? userJwt;
  final String? streamToken;

  bool get hasKeyPair => accessKey != null && campaignKey != null;

  /// Null when the text is not a URL, or carries nothing this demo can use.
  static QrCredentials? parse(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasQuery) return null;

    final Map<String, String> q;
    try {
      q = uri.queryParameters;
    } on FormatException {
      return null; // malformed percent-encoding
    }
    String? value(String key) {
      final v = q[key]?.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    final ak = value(keyAccessKey);
    final ck = value(keyCampaignKey);
    final pairOk = ak != null && ck != null;
    final result = QrCredentials(
      accessKey: pairOk ? ak : null,
      campaignKey: pairOk ? ck : null,
      title: value(keyTitle),
      userJwt: value(keyUserJwt),
      streamToken: value(keyStreamToken),
    );
    if (!result.hasKeyPair && result.userJwt == null && result.streamToken == null) return null;
    return result;
  }

  /// The field names that were filled, for the confirmation message.
  List<String> get filledFields => [
    if (accessKey != null) 'accessKey',
    if (campaignKey != null) 'campaignKey',
    if (streamToken != null) 'streamToken',
    if (userJwt != null) 'userJwt',
  ];
}
