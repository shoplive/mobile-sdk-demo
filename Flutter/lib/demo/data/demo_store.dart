import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shoplive_integration/shoplive_player_event_logger.dart';
import '../l10n/demo_strings.dart';

enum DemoMode { tour, own }

/// Everything the demo remembers between launches: the mode, the keys the user
/// typed, the verified missions and the display language.
///
/// Stored with `shared_preferences` — on this device only, never sent anywhere.
/// A customer app keeps its own keys in its own config, not in a screen like this.
class DemoStore {
  DemoStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<DemoStore> load() async {
    final store = DemoStore._(await SharedPreferences.getInstance());
    final lang = store._prefs.getString(_kLanguage);
    DemoStrings.language.value = DemoLanguage.values.firstWhere((l) => l.name == lang, orElse: () => DemoLanguage.en);
    return store;
  }

  static const _kMode = 'demo.mode';
  static const _kAccessKey = 'demo.accessKey';
  static const _kCampaignKey = 'demo.campaignKey';
  static const _kStreamToken = 'demo.streamToken';
  static const _kUserJwt = 'demo.userJwt';
  static const _kDone = 'demo.doneMissions';
  static const _kLanguage = 'demo.language';

  DemoMode? get mode => switch (_prefs.getString(_kMode)) {
    'tour' => DemoMode.tour,
    'own' => DemoMode.own,
    _ => null,
  };
  set mode(DemoMode? value) => value == null ? _prefs.remove(_kMode) : _prefs.setString(_kMode, value.name);

  String get accessKey => _prefs.getString(_kAccessKey) ?? '';
  set accessKey(String v) => _prefs.setString(_kAccessKey, v);

  String get campaignKey => _prefs.getString(_kCampaignKey) ?? '';
  set campaignKey(String v) => _prefs.setString(_kCampaignKey, v);

  String get streamToken => _prefs.getString(_kStreamToken) ?? '';
  set streamToken(String v) => _prefs.setString(_kStreamToken, v);

  String get userJwt => _prefs.getString(_kUserJwt) ?? '';
  set userJwt(String v) => _prefs.setString(_kUserJwt, v);

  Set<int> get doneMissions => (_prefs.getStringList(_kDone) ?? const []).map(int.tryParse).whereType<int>().toSet();
  set doneMissions(Set<int> v) => _prefs.setStringList(_kDone, v.map((e) => '$e').toList());

  void setLanguage(DemoLanguage lang) {
    DemoStrings.language.value = lang;
    _prefs.setString(_kLanguage, lang.name);
  }
}

/// The "verified" judgement. **Decided automatically from SDK events, not by the
/// user ticking a box.**
///
/// Which mission is running is recorded first ([startMission]); when the events
/// coming out of the player satisfy that mission's success condition, it is marked
/// done. The rules live in [record] and [markBroadcastLive] and nowhere else.
class MissionProgress extends ChangeNotifier {
  MissionProgress(this._store) : _done = _store.doneMissions;

  final DemoStore _store;
  Set<int> _done;

  Set<int> get done => _done;

  /// The mission currently running, which decides where an event is credited.
  int? activeMission;

  void startMission(int number) => activeMission = number;

  /// Translates a copy-paste-layer milestone into this demo's progress rules.
  void record(ShopliveMilestone milestone) => switch (milestone) {
    // Playback started — the success condition for missions 1, 2, 3, 4 and 7.
    ShopliveMilestone.playbackStarted => {1, 2, 3, 4, 7}.contains(activeMission) ? _complete(activeMission!) : null,
    // Entered in-app PIP — mission 5. Seeing PIP counts even during another mission.
    ShopliveMilestone.inAppPipEntered => _complete(5),
    // A navigation, coupon or custom request arrived — mission 6.
    ShopliveMilestone.requestReceived => _complete(6),
  };

  /// The broadcast went LIVE — mission 8.
  void markBroadcastLive() => _complete(8);

  void reset() {
    _done = {};
    _store.doneMissions = _done;
    notifyListeners();
  }

  void _complete(int number) {
    if (_done.contains(number)) return;
    _done = {..._done, number};
    _store.doneMissions = _done;
    notifyListeners();
  }
}
