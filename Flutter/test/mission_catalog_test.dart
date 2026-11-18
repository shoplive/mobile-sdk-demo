import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoplive_onboarding_demo/demo/data/demo_store.dart';
import 'package:shoplive_onboarding_demo/demo/data/missions.dart';
import 'package:shoplive_onboarding_demo/shoplive_integration/shoplive_player_event_logger.dart';
import 'package:shoplive_onboarding_demo/shoplive_integration/shoplive_preview.dart';
import 'package:shoplive_player/shoplive_player.dart';

/// The 9-mission catalog, the progress migration from the 8-mission numbers, and
/// the preview's re-show rule.
void main() {
  group('catalog', () {
    test('nine cards in the guide order, numbered by position', () {
      expect(missions.map((m) => m.id), MissionId.values);
      expect(missions.map((m) => m.number), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(MissionId.preview.number, 2);
      expect(MissionId.studio.number, 9);
    });

    test('every card names a file that exists in the copy-paste folder', () {
      for (final m in missions) {
        expect(File(m.sourcePath).existsSync(), isTrue, reason: m.sourcePath);
        expect(m.sourcePath, startsWith('lib/shoplive_integration/'));
      }
    });

    test('stored identifiers are frozen', () {
      expect(MissionId.values.map((id) => id.raw), [
        'player',
        'preview',
        'pip',
        'deeplink',
        'user',
        'events',
        'inline',
        'ui',
        'studio',
      ]);
      expect(MissionId.fromRaw('nope'), isNull);
    });
  });

  group('progress migration', () {
    test('old numbers move to the same feature, not the same number', () {
      final r = migrateProgress(legacy: ['1', '2', '3', '4', '5', '6', '7', '8'], stored: null);
      expect(r.ids, {
        MissionId.player,
        MissionId.deeplink,
        MissionId.user,
        MissionId.inline,
        MissionId.pip,
        MissionId.events,
        MissionId.ui,
        MissionId.studio,
      });
      expect(r.ids, isNot(contains(MissionId.preview)));
      expect(r.needsWrite, isTrue);
    });

    test('union with the new key, so an interrupted migration converges', () {
      final r = migrateProgress(legacy: ['2'], stored: ['preview', 'deeplink']);
      expect(r.ids, {MissionId.preview, MissionId.deeplink});
    });

    test('unknown values are dropped, never guessed', () {
      final r = migrateProgress(legacy: ['0', '9', 'x'], stored: ['bogus']);
      expect(r.ids, isEmpty);
      expect(r.dropped, ['bogus', '0', '9', 'x']);
      expect(r.needsWrite, isTrue);
    });

    test('nothing to do without a legacy key or bad values', () {
      final r = migrateProgress(legacy: null, stored: ['player']);
      expect(r.ids, {MissionId.player});
      expect(r.needsWrite, isFalse);
    });

    test('DemoStore.load migrates once and removes the old key', () async {
      SharedPreferences.setMockInitialValues({
        'demo.doneMissions': ['2', '5'],
      });
      final store = await DemoStore.load();
      expect(store.doneMissions, {MissionId.deeplink, MissionId.pip});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('demo.doneMissions'), isNull);
      expect(prefs.getStringList('demo.completedMissionIds'), ['deeplink', 'pip']);
    });
  });

  group('completion rule', () {
    test('playback completes the running playback mission only', () {
      expect(MissionProgress.creditFor(ShopliveMilestone.playbackStarted, MissionId.preview), MissionId.preview);
      expect(MissionProgress.creditFor(ShopliveMilestone.playbackStarted, MissionId.pip), isNull);
      expect(MissionProgress.creditFor(ShopliveMilestone.playbackStarted, null), isNull);
    });

    test("the preview's own small window is not the PIP mission", () {
      expect(MissionProgress.creditFor(ShopliveMilestone.inAppPipEntered, MissionId.preview), isNull);
      expect(MissionProgress.creditFor(ShopliveMilestone.inAppPipEntered, MissionId.player), MissionId.pip);
    });

    test('requests complete the events mission', () {
      expect(MissionProgress.creditFor(ShopliveMilestone.requestReceived, MissionId.ui), MissionId.events);
    });
  });

  group('preview host visit', () {
    ShoplivePreviewVisit visit({
      bool isShowing = false,
      ShopliveCloseReason? reason,
      bool other = false,
      bool first = false,
    }) => ShoplivePreview.onHostVisible(
      isShowing: isShowing,
      lastCloseReason: reason,
      otherSessionOngoing: other,
      isFirstVisit: first,
    );

    test('closed by the viewer: not again on this page', () {
      expect(visit(reason: ShopliveCloseReason.userAction), ShoplivePreviewVisit.closedByViewer);
    });

    test('closed for another reason: shown again', () {
      expect(visit(reason: ShopliveCloseReason.appRequest), ShoplivePreviewVisit.start);
      expect(visit(reason: ShopliveCloseReason.accessKeyChanged), ShoplivePreviewVisit.start);
      expect(visit(), ShoplivePreviewVisit.start);
    });

    test('still showing: not started twice', () {
      expect(visit(isShowing: true), ShoplivePreviewVisit.alreadyShowing);
    });

    test('another session: replaced on the first visit only', () {
      expect(visit(other: true, first: true), ShoplivePreviewVisit.start);
      expect(visit(other: true), ShoplivePreviewVisit.otherSessionOngoing);
    });
  });
}
