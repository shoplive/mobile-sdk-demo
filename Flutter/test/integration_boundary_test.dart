import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shoplive_onboarding_demo/shoplive_integration/shoplive_deep_link_router.dart';
import 'package:shoplive_onboarding_demo/shoplive_integration/shoplive_initializer.dart';
import 'package:shoplive_onboarding_demo/shoplive_integration/shoplive_user_setup.dart';

/// The copy boundary, enforced.
///
/// `lib/shoplive_integration/` is what a customer copies. It may import only Dart,
/// Flutter, the Shoplive packages, `crypto`, and its own files — never the demo
/// harness (`lib/demo/`) or anything the customer would have to add for the demo's
/// sake. The iOS demo enforces the same rule with a separate build target; this is
/// the Flutter form of it.
void main() {
  const allowed = ['dart:', 'package:flutter/', 'package:shoplive_', 'package:crypto/'];

  test('shoplive_integration imports nothing from the demo harness', () {
    final files = Directory(
      'lib/shoplive_integration',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    final violations = <String>[];
    for (final file in files) {
      for (final line in file.readAsLinesSync()) {
        final m = RegExp(r'''^(?:import|export)\s+'([^']+)';''').firstMatch(line.trim());
        if (m == null) continue;
        final uri = m.group(1)!;
        final isLocal = !uri.contains(':') && !uri.contains('/');
        if (!isLocal && !allowed.any(uri.startsWith)) violations.add('${file.path}: $uri');
      }
    }
    expect(violations, isEmpty);
  });

  test('deep link parse round-trips linkUri', () {
    final uri = ShopliveDeepLinkRouter.linkUri(scheme: 'myshop', campaignKey: 'abc123', referrer: 'push_1');
    final link = ShopliveDeepLinkRouter.parse(uri, scheme: 'myshop');
    expect(link?.campaignKey, 'abc123');
    expect(link?.referrer, 'push_1');
    expect(ShopliveDeepLinkRouter.parse(Uri.parse('other://live?campaign=x'), scheme: 'myshop'), isNull);
    expect(ShopliveDeepLinkRouter.parse(Uri.parse('myshop://live'), scheme: 'myshop'), isNull);
  });

  test('key validation catches malformed input', () {
    expect(ShopliveInitializer.validate('', 'c'), ShopliveKeyProblem.keysRequired);
    expect(ShopliveInitializer.validate('a b', 'c'), ShopliveKeyProblem.accessKeyWhitespace);
    expect(ShopliveInitializer.validate('a', 'c\n'), ShopliveKeyProblem.campaignKeyWhitespace);
    expect(ShopliveInitializer.validate('a', 'c'), isNull);
  });

  test('profile id is hashed, stable and not the raw id', () {
    final a = ShopliveUserSetup.hashUserId('user-1');
    expect(a, ShopliveUserSetup.hashUserId('user-1'));
    expect(a, isNot(contains('user-1')));
    expect(a.length, 64);
  });
}
