import 'package:flutter/material.dart';

import 'demo/app.dart';
import 'demo/data/demo_defaults.dart';
import 'demo/data/demo_log.dart';
import 'demo/data/demo_options.dart';
import 'demo/data/demo_store.dart';
import 'demo/demo_controller.dart';
import 'shoplive_integration/shoplive_initializer.dart';

/// App entry point.
///
/// **SDK initialization happens here, before `runApp`.** A deep link can cold-start
/// the app (Mission 2), and the access key has to be set before playback starts.
/// The last used mode's key is restored and initialized; when nothing is stored,
/// initialization waits until the user chooses on the start screen.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Install the log sink before any SDK call, so nothing is lost. This is the only
  // wiring the copy-paste layer needs from the host app.
  DemoLog.install();

  final store = await DemoStore.load();

  // On relaunch, skip the start screen and go straight in with the last mode.
  final accessKey = switch (store.mode) {
    DemoMode.own => store.accessKey,
    DemoMode.tour => DemoDefaults.accessKey,
    null => '',
  };
  await ShopliveInitializer.initializeIfNeeded(accessKey);

  final controller = DemoController(store: store, progress: MissionProgress(store), options: DemoOptionsStore())
    ..attach();

  runApp(DemoApp(controller: controller));
}
