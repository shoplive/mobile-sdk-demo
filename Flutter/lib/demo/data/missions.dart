/// The eight feature cards. The numbers are **the same Mission numbers as the
/// integration guide** (https://sdk.shoplive.cloud) and the native demos.
///
/// [Mission.sourcePath] is the only bridge between this app and the project
/// sources, so it must match the real file path. Every path points into
/// `lib/shoplive_integration/`, the copy-paste folder: what the card demonstrates
/// is exactly what a customer takes.
enum MissionRun {
  /// Opens the SDK's full-screen player.
  player,

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

class Mission {
  const Mission({
    required this.number,
    required this.sourceFile,
    required this.run,
    this.openSheet,
    this.needsStreamToken = false,
  });

  final int number;
  final String sourceFile;
  final MissionRun run;

  /// Which developer-sheet tab to open right after running. Null opens nothing.
  final DevSheetTab? openSheet;
  final bool needsStreamToken;

  String get titleKey => 'mission${number}_title';
  String get descriptionKey => 'mission${number}_desc';
  String get checkPointKey => 'mission${number}_check';
  String get sourcePath => '$integrationDir/$sourceFile';
}

/// The copy-paste folder. Everything under here is meant to be taken as-is.
const String integrationDir = 'lib/shoplive_integration';

const List<Mission> missions = [
  Mission(number: 1, sourceFile: 'shoplive_player_launcher.dart', run: MissionRun.player),
  Mission(number: 2, sourceFile: 'shoplive_deep_link_router.dart', run: MissionRun.deepLink),
  Mission(number: 3, sourceFile: 'shoplive_user_setup.dart', run: MissionRun.auth),
  Mission(number: 4, sourceFile: 'shoplive_feed_preview.dart', run: MissionRun.feed),
  Mission(number: 5, sourceFile: 'shoplive_pip_presets.dart', run: MissionRun.player),
  Mission(
    number: 6,
    sourceFile: 'shoplive_player_event_logger.dart',
    run: MissionRun.player,
    openSheet: DevSheetTab.log,
  ),
  Mission(
    number: 7,
    sourceFile: 'shoplive_player_presets.dart',
    run: MissionRun.player,
    openSheet: DevSheetTab.options,
  ),
  Mission(number: 8, sourceFile: 'shoplive_studio_launcher.dart', run: MissionRun.studio, needsStreamToken: true),
];

Mission missionOf(int number) => missions.firstWhere((m) => m.number == number);
