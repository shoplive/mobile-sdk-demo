/// Built-in credentials for tour mode.
///
/// Checked in on purpose, so that cloning the repo and pressing "take a tour" works
/// with no setup — the same demo account as the native demos
/// (`Android/.../DemoDefaults.kt`, `iOS/.../DemoCredentials.swift`). Keep the three
/// in sync: a token rotated on one side has to be rotated on the others.
///
/// ## What this means
/// These are real values in a public-facing repository. They are a **throwaway demo
/// account** and nothing else may ever be put here. Anything belonging to a customer
/// or to production goes in `--dart-define`, which overrides the values below:
///
/// ```
/// flutter run \
///   --dart-define=SHOPLIVE_DEMO_ACCESS_KEY=... \
///   --dart-define=SHOPLIVE_DEMO_CAMPAIGN_KEY=... \
///   --dart-define=SHOPLIVE_DEMO_STREAM_TOKEN=...
/// ```
///
/// The stream token is short-lived: broadcasting (Mission 8) stops working when it
/// expires, and the fix is a new token from the console.
abstract final class DemoDefaults {
  static const String _accessKey = 'ZJZBkloYuh5zXsH7wuUi';
  static const String _campaignKey = '9c83384b5c93';
  static const String _streamToken =
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMDAzODI2IiwiYWNjZXNzS2V5IjoiWkpaQmtsb1l1aDV6WHNIN3d1VWkiLCJzb3VyY2UiOiJTVFJFQU1fQVBQIiwiZXhwIjoxODE2OTk4MjcxLCJpYXQiOjE3ODU0NjIyNzF9.77ZUK-ztmLR0Ow4N3vllxwU9-s-ziAtqGezvzvaZHhw';

  static const String _envAccessKey = String.fromEnvironment('SHOPLIVE_DEMO_ACCESS_KEY');
  static const String _envCampaignKey = String.fromEnvironment('SHOPLIVE_DEMO_CAMPAIGN_KEY');
  static const String _envStreamToken = String.fromEnvironment('SHOPLIVE_DEMO_STREAM_TOKEN');

  static String get accessKey => _envAccessKey.isNotEmpty ? _envAccessKey : _accessKey;
  static String get campaignKey => _envCampaignKey.isNotEmpty ? _envCampaignKey : _campaignKey;
  static String get streamToken => _envStreamToken.isNotEmpty ? _envStreamToken : _streamToken;

  static bool get hasDemoKeys => accessKey.isNotEmpty && campaignKey.isNotEmpty;
}

/// App-level wiring values that must match the native host files.
abstract final class DemoConfig {
  /// Mission 2. Must match the `<data android:scheme>` in
  /// `android/app/src/main/AndroidManifest.xml` and `CFBundleURLSchemes` in
  /// `ios/Runner/Info.plist`. Different from the native demos' `shoplivedemo`, so
  /// that all three apps can be installed on one device without a chooser.
  static const String deepLinkScheme = 'shoplivedemoflutter';
}
