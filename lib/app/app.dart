import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/community/data/community_providers.dart';
import '../features/parsha/week_context.dart';
import '../features/settings/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../services/app_shortcuts.dart';
import '../services/notifications.dart';
import '../ui/theme/app_theme.dart';
import 'pending_saves.dart';
import 'providers.dart';
import 'router.dart';
import 'system_bars.dart';
import 'window_title_bar.dart';

class ShnayimMikraApp extends ConsumerStatefulWidget {
  const ShnayimMikraApp({super.key});

  @override
  ConsumerState<ShnayimMikraApp> createState() => _ShnayimMikraAppState();
}

class _ShnayimMikraAppState extends ConsumerState<ShnayimMikraApp> with WidgetsBindingObserver {
  PendingSaves? _pendingSaves;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Shortcuts on the app's icon open once Today is up, the one that
    // launched the app first, so each has somewhere to go back to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(appShortcutsServiceProvider).listen(_openShortcut);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The saves of the settings and progress in use (only tests swap them).
    final container = ProviderScope.containerOf(context);
    if (_pendingSaves?.container != container) {
      _pendingSaves?.dispose();
      _pendingSaves = PendingSaves(container);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingSaves?.dispose();
    super.dispose();
  }

  // The text theme follows the platform's language when the app does, and
  // so do the shortcuts' titles.
  @override
  void didChangeLocales(List<Locale>? locales) {
    ref.invalidate(appShortcutsProvider);
    setState(() {});
  }

  void _openShortcut(AppShortcut shortcut) {
    // Shortcuts are offered only after onboarding, which must come first.
    if (!mounted || !ref.read(settingsProvider).onboardingComplete) return;
    openFromOutside(ref.read(routerProvider), shortcut.route(ref.read(currentWeekContextProvider)));
  }

  /// Whether the app shows in Hebrew, resolved the way MaterialApp resolves
  /// its locale.
  bool _hebrewUi(AppLanguage language) => switch (language) {
        AppLanguage.english => false,
        AppLanguage.hebrew => true,
        AppLanguage.system => basicLocaleListResolution(
                  WidgetsBinding.instance.platformDispatcher.locales,
                  AppLocalizations.supportedLocales,
                ).languageCode ==
                'he',
      };

  @override
  Widget build(BuildContext context) {
    // Only what the app as a whole is built from: its themes are costly to
    // build, and every other setting is watched where it is used.
    final settings = ref.watch(settingsProvider.select((s) => (
          theme: s.theme,
          uiFont: s.uiFont,
          reduceMotion: s.reduceMotion,
          boldText: s.boldText,
          language: s.language,
        )));
    final router = ref.watch(routerProvider);
    // Keep scheduled reminders in sync with settings and progress, the icon's
    // shortcuts in the app's language, and the cloud backup (if enabled) in
    // sync with progress. The sync is only kept alive (listened to, not
    // watched): its timestamp must not rebuild the app.
    ref.watch(reminderSchedulerProvider);
    ref.watch(appShortcutsProvider);
    ref.listen(progressSyncProvider, (_, _) {});
    ref.listen(notificationTapsProvider, (_, next) {
      final route = next.value;
      if (route != null) router.go(route);
    });

    final systemHighContrast = MediaQuery.highContrastOf(context);
    final reduceMotion = settings.reduceMotion || MediaQuery.disableAnimationsOf(context);

    final hebrewUi = _hebrewUi(settings.language);

    // [mode] is always a concrete theme: when following the system, MaterialApp
    // picks among the light, dark and high-contrast themes built below.
    ThemeData themeFor(AppThemeMode mode) => AppTheme.build(
          mode: mode,
          uiFont: settings.uiFont,
          hebrewUi: hebrewUi,
          reduceMotion: reduceMotion,
        );

    final followSystem = settings.theme == AppThemeMode.system;
    final ThemeData light;
    final ThemeData dark;
    ThemeData? highContrastLight;
    ThemeData? highContrastDark;
    // The theme MaterialApp shows, picked as it picks one. Its surface is the
    // colour the platform gives the app: the web's theme-color (the browser's
    // toolbar, or the installed app's title bar) and Android's recents.
    final ThemeData shown;
    if (followSystem) {
      light = themeFor(AppThemeMode.light);
      dark = themeFor(AppThemeMode.dark);
      highContrastLight = themeFor(AppThemeMode.highContrastLight);
      highContrastDark = themeFor(AppThemeMode.highContrastDark);
      final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
      shown = systemHighContrast
          ? (platformDark ? highContrastDark : highContrastLight)
          : (platformDark ? dark : light);
    } else {
      light = dark = shown = themeFor(settings.theme);
    }

    final locale = switch (settings.language) {
      AppLanguage.system => null,
      AppLanguage.english => const Locale('en'),
      AppLanguage.hebrew => const Locale('he'),
    };

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      color: shown.colorScheme.surface,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: light,
      darkTheme: dark,
      // When following the system, honor the OS high-contrast request too.
      highContrastTheme: highContrastLight,
      highContrastDarkTheme: highContrastDark,
      themeMode: followSystem
          ? ThemeMode.system
          : (light.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            boldText: mq.boldText || settings.boldText,
            disableAnimations: reduceMotion,
            highContrast: systemHighContrast || AppTheme.isHighContrast(settings.theme),
          ),
          child: SystemBars(child: WindowTitleBar(child: FocusHighlightScope(child: child!))),
        );
      },
    );
  }
}
