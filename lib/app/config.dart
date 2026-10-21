import 'package:flutter/foundation.dart';

/// Build-time configuration, passed with `--dart-define` (see README).
abstract final class AppConfig {
  /// Supabase project URL for forums and sync. Empty → community features
  /// run in an on-device demo mode.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase publishable (anon) key — safe to ship in the app; all access
  /// is governed by row-level security.
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Where users can reach the maintainers. Empty → hidden.
  static String get supportEmail => debugSupportEmail ?? _supportEmail;
  static const _supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

  /// Stands in for [supportEmail] in tests, which can't define it at build
  /// time.
  @visibleForTesting
  static String? debugSupportEmail;

  /// Public source code / issue tracker.
  static const sourceUrl = String.fromEnvironment(
    'SOURCE_URL',
    defaultValue: 'https://github.com/Shnayim-Mikrah-V-Echad-Targum/app',
  );

  /// Where the installed app can be had, offered on the web where reminders
  /// need it. Empty → not offered.
  static const installUrl = String.fromEnvironment('INSTALL_URL');

  /// The web app's public address, ending in a slash
  /// ('https://example.org/app/'), that links to its pages begin with, such
  /// as a discussion's Copy link. Empty → no links are offered.
  static String get webUrl {
    final url = debugWebUrl ?? _webUrl;
    return url.isEmpty || url.endsWith('/') ? url : '$url/';
  }

  static const _webUrl = String.fromEnvironment('WEB_URL');

  /// Stands in for [webUrl] in tests, which can't define it at build time.
  @visibleForTesting
  static String? debugWebUrl;

  static bool get hasBackend => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Whether the community is offered: everywhere but in a build made with
  /// `COMMUNITY=off`, as the pre-releases are until the accounts' database
  /// is ready. Off, the Community tab, the questions on a verse, the
  /// account and its sign-in, the week's discussion and the cloud backup
  /// are nowhere to be seen, and a link to any of them opens Today; About
  /// and the guide say that the community is coming. Absent, as in CI and
  /// the tests, the community is as it was: on Supabase where one is
  /// configured, and otherwise the on-device demo.
  static bool get communityEnabled => debugCommunity ?? _community != 'off';
  static const _community = String.fromEnvironment('COMMUNITY');

  /// Stands in for [communityEnabled] in tests, which can't define
  /// `COMMUNITY` at build time.
  @visibleForTesting
  static bool? debugCommunity;

  /// The releases the Windows app looks for updates among
  /// (lib/services/updates/): 'prerelease', which takes pre-releases too
  /// (the pre-releases' own builds), 'stable', or 'none'. Absent, it is
  /// 'none', and the app never asks: CI, pull requests, the stores' builds
  /// and the tests make no request.
  static const updateChannel = String.fromEnvironment('UPDATE_CHANNEL', defaultValue: 'none');
}
