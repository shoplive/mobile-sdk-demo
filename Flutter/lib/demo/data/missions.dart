/// A mission's identity. **Branching and progress use this, never a number.**
///
/// [raw] is what gets stored on disk, so the nine values are frozen — renaming one
/// silently drops everybody's progress for it. The number a viewer sees is
/// [number], derived from the declaration order below and never stored.
///
/// Declaration order **is** the display order: the integration guide's mission map
/// (https://sdk.shoplive.cloud), the same order as the native demos. To renumber,
/// reorder the values — nothing else.
enum MissionId {
  player('player'), // 1 · full-screen player
  preview('preview'), // 2 · preview over a product page
  pip('pip'), // 3 · PIP
  deeplink('deeplink'), // 4 · deep link
  user('user'), // 5 · user info
  events('events'), // 6 · events · products · coupons
  inline('inline'), // 7 · inline preview in a list screen (the feed)
  ui('ui'), // 8 · UI customization
  studio('studio'); // 9 · broadcasting

  const MissionId(this.raw);

  final String raw;

  /// The number on the card — the guide's Mission number.
  int get number => index + 1;

  /// Null for anything that is not one of the nine stored values.
  static MissionId? fromRaw(String raw) {
    for (final id in values) {
      if (id.raw == raw) return id;
    }
    return null;
  }
}

/// How tapping the card runs it.
enum MissionRun {
  /// Opens the SDK's full-screen player.
  player,

  /// The demo's own product page, with a preview floating over it.
  preview,

  /// Fake push banner -> a real deep link -> the player.
  deepLink,

  /// Asks for an auth method, then plays.
  auth,

  /// The demo's own home feed screen, with a floating preview.
  feed,

  /// Opens the SDK's studio.
  studio,
}

enum DevSheetTab { log, options }

/// One feature card.
///
/// [Mission.sourcePath] is the only bridge between this app and the project
/// sources, so it must match the real file path. Every path points into
/// `lib/shoplive_integration/`, the copy-paste folder: what the card demonstrates
/// is exactly what a customer takes.
class Mission {
  const Mission({
    required this.id,
    required this.sourceFile,
    required this.run,
    this.openSheet,
    this.needsStreamToken = false,
  });

  final MissionId id;
  final String sourceFile;
  final MissionRun run;

  /// Which developer-sheet tab to open right after running. Null opens nothing.
  final DevSheetTab? openSheet;
  final bool needsStreamToken;

  int get number => id.number;
  String get titleKey => 'mission_${id.raw}_title';
  String get descriptionKey => 'mission_${id.raw}_desc';
  String get checkPointKey => 'mission_${id.raw}_check';
  String get sourcePath => '$integrationDir/$sourceFile';
}

/// The copy-paste folder. Everything under here is meant to be taken as-is.
const String integrationDir = 'lib/shoplive_integration';

/// The cards in display order. Built from [MissionId.values], so a new identifier
/// that is not described in [_describe] does not compile.
final List<Mission> missions = [for (final id in MissionId.values) _describe(id)];

Mission missionOf(MissionId id) => missions[id.index];

Mission _describe(MissionId id) => switch (id) {
  MissionId.player => Mission(id: id, sourceFile: 'shoplive_player_launcher.dart', run: MissionRun.player),
  MissionId.preview => Mission(id: id, sourceFile: 'shoplive_preview.dart', run: MissionRun.preview),
  MissionId.pip => Mission(id: id, sourceFile: 'shoplive_pip_presets.dart', run: MissionRun.player),
  MissionId.deeplink => Mission(id: id, sourceFile: 'shoplive_deep_link_router.dart', run: MissionRun.deepLink),
  MissionId.user => Mission(id: id, sourceFile: 'shoplive_user_setup.dart', run: MissionRun.auth),
  MissionId.events => Mission(
    id: id,
    sourceFile: 'shoplive_player_event_logger.dart',
    run: MissionRun.player,
    openSheet: DevSheetTab.log,
  ),
  MissionId.inline => Mission(id: id, sourceFile: 'shoplive_feed_preview.dart', run: MissionRun.feed),
  MissionId.ui => Mission(
    id: id,
    sourceFile: 'shoplive_player_presets.dart',
    run: MissionRun.player,
    openSheet: DevSheetTab.options,
  ),
  MissionId.studio => Mission(
    id: id,
    sourceFile: 'shoplive_studio_launcher.dart',
    run: MissionRun.studio,
    needsStreamToken: true,
  ),
};
