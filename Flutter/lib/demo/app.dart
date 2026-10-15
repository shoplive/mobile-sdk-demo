import 'package:flutter/material.dart';

import 'demo_controller.dart';
import 'devtools/dev_sheet.dart';
import 'l10n/demo_strings.dart';
import 'screens/feed_screen.dart';
import 'screens/mission_list_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/start_screen.dart';
import 'widgets/common.dart';

/// The screen structure — the same as the native demos.
///
/// - S1 [Routes.start] start
/// - S2 [Routes.missions] feature list
/// - S3 the running screen — the player and studio are **native screens owned by
///   the SDK**, so they have no route. The only one the app owns is the home feed
///   ([Routes.feed], Mission 4).
/// - V1 the developer sheet (modal bottom sheet), V2 product detail ([Routes.product]).
class DemoApp extends StatefulWidget {
  const DemoApp({super.key, required this.controller});

  final DemoController controller;

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  final GlobalKey<ScaffoldMessengerState> _messenger = GlobalKey();

  DemoController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.message.addListener(_showMessage);
    c.devSheetRequest.addListener(_openDevSheet);
  }

  @override
  void dispose() {
    c.message.removeListener(_showMessage);
    c.devSheetRequest.removeListener(_openDevSheet);
    super.dispose();
  }

  void _showMessage() {
    final text = c.message.value;
    if (text == null) return;
    c.message.value = null;
    _messenger.currentState
      ?..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 5)));
  }

  void _openDevSheet() {
    final tab = c.devSheetRequest.value;
    final context = c.navigatorKey.currentContext;
    if (tab == null || context == null) return;
    c.devSheetRequest.value = null;
    showDevSheet(context, c, tab);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DemoLanguage>(
    valueListenable: DemoStrings.language,
    builder:
        (context, _, __) => MaterialApp(
          title: tr('app_name'),
          debugShowCheckedModeBanner: false,
          navigatorKey: c.navigatorKey,
          scaffoldMessengerKey: _messenger,
          theme: demoTheme(Brightness.light),
          darkTheme: demoTheme(Brightness.dark),
          // Skip the start screen when a mode was stored.
          initialRoute: c.mode == null ? Routes.start : Routes.missions,
          // Exactly one initial route. The default treats '/start' as a deep link
          // and stacks '/' (the feature list) under it, so Back on the start screen
          // would land on the list with no mode chosen.
          onGenerateInitialRoutes: (name) => [_route(RouteSettings(name: name))],
          onGenerateRoute: _route,
        ),
  );

  Route<void> _route(RouteSettings settings) => MaterialPageRoute<void>(
    settings: settings,
    builder:
        (context) => switch (settings.name) {
          Routes.start => StartScreen(controller: c),
          Routes.feed => FeedScreen(controller: c),
          Routes.product => ProductDetailScreen(url: settings.arguments as String? ?? '', options: c.options),
          _ => MissionListScreen(controller: c),
        },
  );
}
