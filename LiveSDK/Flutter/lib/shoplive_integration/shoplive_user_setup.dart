import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:shoplive_player/shoplive_player.dart';

import 'shoplive_event_labels.dart';
import 'shoplive_log.dart';

/// Connecting the viewer's identity.
///
/// Three ways, and one app **may mix them**. They take effect from the next
/// playback onwards.
///
/// | Method | Call | When |
/// | --- | --- | --- |
/// | guest | `Shoplive.setUser(const ShopliveUser.guest())` | watching without logging in |
/// | profile | `Shoplive.setUser(ShopliveUser.profile(id: ...))` | show a member without server work |
/// | token | `Shoplive.setUser(ShopliveUser.token(jwt))` | server-signed JWT (recommended) |
///
/// ## Careful — guest is not "sign out"
/// `ShopliveUser.guest()` leaves an existing identity in place. To sign out you
/// must call `Shoplive.logout()` — [apply] does both for the guest method.
///
/// ## Token beats profile
/// Once a token is set, tokens generated from a profile are ignored.
///
/// ## iOS ignores `profile.custom`
/// Accepted and dropped on iOS (no iOS SDK counterpart).
enum ShopliveUserMethod {
  guest,
  profile,
  token;

  /// The API value, so it is never translated.
  String get label => name;
}

abstract final class ShopliveUserSetup {
  /// [jwt] is required for [ShopliveUserMethod.token]; blank falls back to guest.
  /// [profile] is used for [ShopliveUserMethod.profile]; pass your own logged-in
  /// user's values instead of [exampleProfile].
  ///
  /// Returns the method that was actually applied.
  static Future<ShopliveUserMethod> apply(
    ShopliveUserMethod method, {
    String jwt = '',
    ShopliveProfileUser? profile,
  }) async {
    final effective = method == ShopliveUserMethod.token && jwt.trim().isEmpty ? ShopliveUserMethod.guest : method;

    try {
      switch (effective) {
        case ShopliveUserMethod.guest:
          // Guest alone will not release an existing login — clear it explicitly.
          await Shoplive.logout();
          await Shoplive.setUser(const ShopliveUser.guest());
          logCall('Shoplive.logout() → setUser(ShopliveUser.guest())');
        case ShopliveUserMethod.profile:
          final user = profile ?? exampleProfile();
          await Shoplive.setUser(user);
          logCall('Shoplive.setUser(ShopliveUser.profile(id: "${shopliveMasked(user.id)}"))');
        case ShopliveUserMethod.token:
          await Shoplive.setUser(ShopliveUser.token(jwt));
          logCall('Shoplive.setUser(ShopliveUser.token("${shopliveMasked(jwt)}"))');
      }
    } on PlatformException catch (e) {
      logError('setUser(${effective.label}) failed — ${platformExceptionLogLine(e)}');
    }

    if (method == ShopliveUserMethod.token && effective == ShopliveUserMethod.guest) {
      logError('token method selected but the JWT is empty — falling back to guest.');
    }
    return effective;
  }

  /// Example profile. Replace the values with your logged-in session's.
  ///
  /// Hashing `id` is **recommended** — it keeps the raw member ID out of the SDK and
  /// off the Shoplive servers while staying stable per user. `id` is required.
  ///
  /// [ShopliveGender.undefined] means "not collected" and is not transmitted;
  /// [ShopliveGender.neutral] is a third gender value and **is** transmitted.
  static ShopliveProfileUser exampleProfile({String rawUserId = 'demo-user-0001', String name = 'Demo user'}) =>
      ShopliveProfileUser(
        id: hashUserId(rawUserId),
        name: name,
        age: 27,
        gender: ShopliveGender.undefined,
        rank: 1,
        custom: const {'grade': 'vip'},
      );

  /// SHA-256(raw + per-app salt). Use a salt of your own, not this one.
  static String hashUserId(String raw, {String salt = 'SHOPLIVE_DEMO_SALT'}) =>
      sha256.convert(utf8.encode(raw + salt)).toString();
}
