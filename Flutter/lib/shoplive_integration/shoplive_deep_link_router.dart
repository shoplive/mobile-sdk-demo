import 'shoplive_log.dart';

/// Turning a link into playback.
///
/// Handles links shaped like
///
/// ```
/// {scheme}://live?campaign={CAMPAIGN_KEY}&ref={REFERRER}
/// ```
///
/// The scheme and host are **parameters, not constants**: they belong to your app's
/// `AndroidManifest.xml` `<intent-filter>` and iOS `CFBundleURLTypes`, not to this
/// file. Pass the same value you declared there.
///
/// ## Receiving the link is your app's job
/// The Flutter SDK has no link handling. Use whatever your app already uses
/// (`app_links`, `uni_links`, go_router's deep linking, a push SDK's callback) and
/// hand the `Uri` to [parse]. The demo uses `app_links`.
///
/// ## Cold start is the whole problem
/// The app may be dead when the link is tapped. The order then has to be:
///
/// 1. `await Shoplive.initialize(...)` — in `main()`, before `runApp`
/// 2. `await Shoplive.setUser(...)` — if you need it
/// 3. `await ShoplivePlayer.instance.start(campaignKey, playOptions: ShoplivePlayOptions(referrer: ref))`
///
/// Start before initialization and playback fails with `NOT_INITIALIZED_ACCESS_KEY`.
/// Start before the first frame and it fails with `NO_HOST_SCREEN`.
///
/// ## Which is why this file does not start playback
/// It only parses. Only the host knows whether initialization has finished and a
/// screen is up, so it decides and it plays.
abstract final class ShopliveDeepLinkRouter {
  static const String _paramCampaign = 'campaign';
  static const String _paramRef = 'ref';

  /// Returns a [ShopliveLink] when this is a link we can handle, otherwise null.
  /// Null means "not ours" — let the rest of your routing have it.
  static ShopliveLink? parse(Uri? uri, {required String scheme, String host = 'live'}) {
    if (uri == null) return null;
    if (uri.scheme.toLowerCase() != scheme.toLowerCase()) return null;
    if (uri.host.toLowerCase() != host.toLowerCase()) return null;

    final campaignKey = (uri.queryParameters[_paramCampaign] ?? '').trim();
    if (campaignKey.isEmpty) {
      logError('Deep link has no campaign parameter: $uri');
      return null;
    }

    final link = ShopliveLink(campaignKey: campaignKey, referrer: uri.queryParameters[_paramRef]);
    logCall('deep link received — $uri');
    logCall('parsed → campaignKey: "${link.campaignKey}", referrer: ${link.referrer}');
    return link;
  }

  /// Builds the link your backend or push payload should contain.
  static Uri linkUri({required String scheme, required String campaignKey, String? referrer, String host = 'live'}) =>
      Uri(
        scheme: scheme,
        host: host,
        queryParameters: {
          _paramCampaign: campaignKey,
          if (referrer != null && referrer.trim().isNotEmpty) _paramRef: referrer,
        },
      );
}

class ShopliveLink {
  const ShopliveLink({required this.campaignKey, this.referrer});

  final String campaignKey;

  /// Where the viewer came from. Forward it as `ShoplivePlayOptions.referrer` — the
  /// only link between "which push" and "how long they watched".
  final String? referrer;
}
