import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shoplive_integration/shoplive_log.dart';
import '../../shoplive_integration/shoplive_player_event_logger.dart';
import '../l10n/demo_strings.dart';
import 'missions.dart';

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
    await store._migrateProgress();
    return store;
  }

  static const _kMode = 'demo.mode';
  static const _kAccessKey = 'demo.accessKey';
  static const _kCampaignKey = 'demo.campaignKey';
  static const _kStreamToken = 'demo.streamToken';
  static const _kUserJwt = 'demo.userJwt';

  /// Mission identifiers ([MissionId.raw]).
  static const _kDone = 'demo.completedMissionIds';

  /// Builds before the 9-mission order stored the 8-mission guide numbers here.
  static const _kLegacyDone = 'demo.doneMissions';
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

  Set<MissionId> get doneMissions => {...?_readList(_kDone)?.map(MissionId.fromRaw).whereType<MissionId>()};
  set doneMissions(Set<MissionId> v) => _prefs.setStringList(_kDone, _storedValues(v));

  /// Clears both keys — an old key left behind would be migrated back next launch.
  Future<void> clearDoneMissions() async {
    final removedNew = await _prefs.remove(_kDone);
    final removedOld = await _prefs.remove(_kLegacyDone);
    if (!removedNew || !removedOld) {
      logError('progress: reset could not be saved — the old record may come back on the next launch');
    }
  }

  /// Folds the 8-mission number record into the identifier key, once.
  ///
  /// The new key is written **first** and the old one removed **after**. If the app
  /// dies in between, the next launch folds the same numbers into the same set (a
  /// union), so no version flag is needed. An old key that cannot be read is left
  /// alone for the next launch.
  Future<void> _migrateProgress() async {
    var legacyReadable = true;
    List<String>? legacy;
    try {
      legacy = _prefs.getStringList(_kLegacyDone);
    } catch (e) {
      legacyReadable = false;
      logError('progress: "$_kLegacyDone" is not a string list ($e) — migration skipped, kept for the next launch');
    }
    final result = migrateProgress(legacy: legacy, stored: _readList(_kDone));
    if (result.dropped.isNotEmpty) logError('progress: dropped values that name no mission: ${result.dropped}');
    if (!result.needsWrite) return;

    final saved = await _prefs.setStringList(_kDone, _storedValues(result.ids));
    if (!saved) {
      logError('progress: saving migrated progress failed — the old key stays and migration reruns next launch');
      return;
    }
    if (legacy != null && legacyReadable) {
      await _prefs.remove(_kLegacyDone);
      logEvent('progress: migrated 8-mission record $legacy → ${_storedValues(result.ids)}');
    }
  }

  List<String>? _readList(String key) {
    try {
      return _prefs.getStringList(key);
    } catch (e) {
      logError('progress: "$key" is not a string list ($e) — ignored');
      return null;
    }
  }

  static List<String> _storedValues(Set<MissionId> ids) => (ids.map((id) => id.raw).toList()..sort());

  void setLanguage(DemoLanguage lang) {
    DemoStrings.language.value = lang;
    _prefs.setString(_kLanguage, lang.name);
  }
}

/// The outcome of reading stored progress. [needsWrite] is false when nothing changes.
class ProgressMigration {
  const ProgressMigration({required this.ids, required this.dropped, required this.needsWrite});

  final Set<MissionId> ids;

  /// Values that named no mission. Logged, then gone for good.
  final List<String> dropped;
  final bool needsWrite;
}

/// Old guide number -> the same feature today. Frozen: it describes what old builds
/// wrote, not the current order. The preview mission is new and has no entry.
/// The same table as the native demos.
const Map<int, MissionId> legacyMissionNumbers = {
  1: MissionId.player,
  2: MissionId.deeplink,
  3: MissionId.user,
  4: MissionId.inline,
  5: MissionId.pip,
  6: MissionId.events,
  7: MissionId.ui,
  8: MissionId.studio,
};

/// Old numbers and new identifiers in, one identifier set out. Union of both, so a
/// run interrupted after writing the new key and before deleting the old one
/// converges to the same set; anything that names no mission is dropped rather
/// than guessed (crediting a wrong mission is worse than losing a tick).
ProgressMigration migrateProgress({required List<String>? legacy, required List<String>? stored}) {
  final dropped = <String>[];
  final ids = <MissionId>{};
  for (final raw in stored ?? const <String>[]) {
    final id = MissionId.fromRaw(raw);
    id == null ? dropped.add(raw) : ids.add(id);
  }
  for (final value in legacy ?? const <String>[]) {
    final id = legacyMissionNumbers[int.tryParse(value)];
    id == null ? dropped.add(value) : ids.add(id);
  }
  return ProgressMigration(ids: ids, dropped: dropped, needsWrite: legacy != null || dropped.isNotEmpty);
}

/// The "verified" judgement. **Decided automatically from SDK events, not by the
/// user ticking a box.**
///
/// Which mission is running is recorded first ([startMission]); when the events
/// coming out of the player satisfy that mission's success condition, it is marked
/// done. The rules live in [creditFor] and [markBroadcastLive] and nowhere else.
class MissionProgress extends ChangeNotifier {
  MissionProgress(this._store) : _done = _store.doneMissions;

  final DemoStore _store;
  Set<MissionId> _done;

  Set<MissionId> get done => _done;

  /// The mission currently running, which decides where an event is credited.
  MissionId? activeMission;

  void startMission(MissionId id) => activeMission = id;

  /// Missions whose success signal is "playback started".
  static const Set<MissionId> playbackMissions = {
    MissionId.player,
    MissionId.preview,
    MissionId.deeplink,
    MissionId.user,
    MissionId.inline,
    MissionId.ui,
  };

  /// Translates a copy-paste-layer milestone into this demo's progress rules.
  void record(ShopliveMilestone milestone) {
    final credited = creditFor(milestone, activeMission);
    if (credited != null) {
      _complete(credited);
    } else if (milestone == ShopliveMilestone.inAppPipEntered) {
      logEvent('progress: in-app PIP of the preview session — not the PIP mission');
    }
  }

  /// Which mission [milestone] completes while [active] runs, or null.
  ///
  /// - Playback started: the running mission, if it is a playback mission.
  /// - In-app PIP entered: the PIP mission, even during another mission — except
  ///   while the preview mission runs: its small window is the preview, not
  ///   "keep watching in PIP" (same rule as the native demos).
  /// - A navigation, coupon or custom request: the events mission.
  static MissionId? creditFor(ShopliveMilestone milestone, MissionId? active) => switch (milestone) {
    ShopliveMilestone.playbackStarted => playbackMissions.contains(active) ? active : null,
    ShopliveMilestone.inAppPipEntered => active == MissionId.preview ? null : MissionId.pip,
    ShopliveMilestone.requestReceived => MissionId.events,
  };

  /// The broadcast went LIVE.
  void markBroadcastLive() => _complete(MissionId.studio);

  void reset() {
    _done = {};
    _store.clearDoneMissions();
    notifyListeners();
  }

  void _complete(MissionId id) {
    if (_done.contains(id)) return;
    _done = {..._done, id};
    _store.doneMissions = _done;
    notifyListeners();
  }
}
