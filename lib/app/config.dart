/// Build-time configuration, passed with `--dart-define` (see README).
abstract final class AppConfig {
  /// Supabase project URL for forums and sync. Empty → community features
  /// run in an on-device demo mode.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase publishable (anon) key — safe to ship in the app; all access
  /// is governed by row-level security.
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Where users can reach the maintainers. Empty → hidden.
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

  /// Public source code / issue tracker.
  static const sourceUrl = String.fromEnvironment(
    'SOURCE_URL',
    defaultValue: 'https://github.com/Shnayim-Mikrah-V-Echad-Targum/app',
  );

  static bool get hasBackend => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
