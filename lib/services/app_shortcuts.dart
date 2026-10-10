import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show basicLocaleListResolution;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import '../app/providers.dart';
import '../features/parsha/week_context.dart';
import '../features/settings/app_settings.dart';
import '../l10n/app_localizations.dart';

/// A shortcut offered when the app's icon is long-pressed, on Android and
/// iOS.
///
/// A shortcut names a page, not a week: the platform keeps shortcuts while
/// the app isn't running, so each one opens the current week as it is when
/// it is chosen (see [route]), however long ago the app last ran.
enum AppShortcut {
  /// The reader, at the first aliyah not yet read.
  continueReading('continue_reading'),

  /// This week's page, to mark what was read from a printed Chumash.
  logFromBook('log_from_book'),

  /// The Parsha tab.
  thisWeek('this_week');

  const AppShortcut(this.type);

  /// The shortcut's id with the platform. Never change one: Android keeps
  /// it on a shortcut the user has pinned to the home screen.
  final String type;

  static AppShortcut? fromType(String type) {
    for (final shortcut in values) {
      if (shortcut.type == type) return shortcut;
    }
    return null;
  }

  String title(AppLocalizations l) => switch (this) {
        continueReading => l.shortcutContinueReading,
        logFromBook => l.shortcutLogFromBook,
        thisWeek => l.shortcutThisWeek,
      };

  /// The page this shortcut opens, in the week [week].
  String route(WeekContext week) => switch (this) {
        continueReading => '/read/${week.id}/${week.nextAliyah ?? 0}',
        logFromBook => '/week/${week.id}',
        thisWeek => '/parsha',
      };
}

/// The app's shortcuts on its icon. Only Android and iOS have them.
class AppShortcutsService {
  AppShortcutsService._(this._plugin, this._now);

  /// For tests and the platforms without shortcuts.
  AppShortcutsService.disabled()
      : _plugin = null,
        _now = DateTime.now;

  /// Starts listening for shortcuts, so that one chosen to launch the app is
  /// held until [listen] is called. [plugin] and [now] are for tests.
  static Future<AppShortcutsService> create({
    QuickActions plugin = const QuickActions(),
    @visibleForTesting DateTime Function() now = DateTime.now,
  }) async {
    final supported = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    if (!supported) return AppShortcutsService.disabled();
    final service = AppShortcutsService._(plugin, now);
    try {
      await plugin.initialize(service._choose);
      return service;
    } catch (e) {
      debugPrint('App shortcuts unavailable: $e');
      return AppShortcutsService.disabled();
    }
  }

  final QuickActions? _plugin;
  final DateTime Function() _now;

  bool get supported => _plugin != null;

  /// The native image each shortcut shows: the launcher icon on Android, and
  /// on iOS, which draws shortcut icons as templates, the mark alone
  /// (ios/Runner/Assets.xcassets, written by tool/branding/make_icon.py).
  static String get icon => defaultTargetPlatform == TargetPlatform.iOS ? 'ShortcutMark' : 'ic_launcher';

  ValueChanged<AppShortcut>? _open;
  AppShortcut? _waiting;
  (AppShortcut, DateTime)? _last;

  /// Hands every shortcut the user chooses to [open], beginning with one
  /// chosen before now (the one that launched the app).
  void listen(ValueChanged<AppShortcut> open) {
    _open = open;
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null) open(waiting);
  }

  /// Takes the shortcut the platform reports, by its [type].
  @visibleForTesting
  void choose(String type) => _choose(type);

  void _choose(String type) {
    final shortcut = AppShortcut.fromType(type);
    if (shortcut == null) return;
    // Android can report the shortcut that started the app twice: as the
    // activity attaches, and again when asked for it.
    final now = _now();
    final last = _last;
    _last = (shortcut, now);
    if (last != null && last.$1 == shortcut && now.difference(last.$2) < const Duration(seconds: 2)) return;
    final open = _open;
    if (open == null) {
      _waiting = shortcut;
    } else {
      open(shortcut);
    }
  }

  String? _shown;

  /// Replaces the shortcuts on the app's icon with [items], unless they are
  /// the ones already there.
  Future<void> show(List<ShortcutItem> items) async {
    final plugin = _plugin;
    if (plugin == null) return;
    final signature = [for (final i in items) '${i.type}:${i.localizedTitle}:${i.icon}'].join('|');
    if (signature == _shown) return;
    _shown = signature;
    try {
      if (items.isEmpty) {
        await plugin.clearShortcutItems();
      } else {
        await plugin.setShortcutItems(items);
      }
    } catch (e) {
      _shown = null;
      debugPrint('Could not set app shortcuts: $e');
    }
  }
}

final appShortcutsServiceProvider = Provider<AppShortcutsService>((ref) => AppShortcutsService.disabled());

/// Keeps the shortcuts on the app's icon in the app's language. They are
/// offered only after onboarding, which each would lead to until then.
///
/// The device's language isn't watched: the app invalidates this provider
/// when it changes.
final appShortcutsProvider = Provider<void>((ref) {
  final service = ref.watch(appShortcutsServiceProvider);
  if (!service.supported) return;
  final onboarded = ref.watch(settingsProvider.select((s) => s.onboardingComplete));
  final language = ref.watch(settingsProvider.select((s) => s.language));
  if (!onboarded) {
    service.show(const []);
    return;
  }
  // The language the app shows in, resolved as MaterialApp resolves it.
  final l = lookupAppLocalizations(switch (language) {
    AppLanguage.english => const Locale('en'),
    AppLanguage.hebrew => const Locale('he'),
    AppLanguage.system => basicLocaleListResolution(
        PlatformDispatcher.instance.locales,
        AppLocalizations.supportedLocales,
      ),
  });
  service.show([
    for (final shortcut in AppShortcut.values)
      ShortcutItem(type: shortcut.type, localizedTitle: shortcut.title(l), icon: AppShortcutsService.icon),
  ]);
});
