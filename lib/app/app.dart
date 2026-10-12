import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/community/data/community_providers.dart';
import '../features/parsha/week_context.dart';
import '../features/settings/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../services/app_shortcuts.dart';
import '../services/feedback.dart' show StatusMessageArea;
import '../services/home_widget_sync.dart';
import '../services/notifications.dart';
import '../services/optional_fonts.dart';
import '../ui/theme/app_theme.dart';
import '../ui/widgets/fonts_change_scope.dart';
import 'celebrations.dart';
import 'device_accessibility.dart';
import 'pending_saves.dart';
import 'providers.dart';
import 'router.dart';
import 'shell.dart';
import 'system_bars.dart';
import 'window_title_bar.dart';

class ShnayimMikraApp extends ConsumerStatefulWidget {
  const ShnayimMikraApp({super.key});

  @override
  ConsumerState<ShnayimMikraApp> createState() => _ShnayimMikraAppState();
}

class _ShnayimMikraAppState extends ConsumerState<ShnayimMikraApp> with WidgetsBindingObserver {
  StreamSubscription<String>? _taps;
  PendingSaves? _pendingSaves;

  // The interface font the theme is built in: the one chosen, once it has
  // loaded, and until then the one shown before it. Text measured as it is
  // built (the navigation bar's labels, say) is then never measured in a
  // stand-in font, and nothing flashes in one.
  UiFont _uiFont = UiFont.standard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final notifications = ref.read(notificationServiceProvider);
    // Subscribed directly, so that a tap opening the same page as the last
    // one still opens it.
    _taps = notifications.taps.listen(_open);
    // main() loaded the opt-in fonts the settings choose, or gave up waiting
    // for them: this tries again for one that failed, and shows it once it
    // has loaded.
    _loadFonts();
    // The app starts on Today; a notification that launched it opens over
    // it. Shortcuts on the app's icon and taps on the home-screen widget open
    // once Today is up too, the one that launched the app first, so each has
    // somewhere to go back to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = notifications.launchRoute;
      notifications.launchRoute = null;
      if (route != null && route != '/today') _open(route);
      if (!mounted) return;
      ref.read(appShortcutsServiceProvider).listen(_openShortcut);
      ref.read(homeWidgetServiceProvider).listen(_openWidgetLink);
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
    _taps?.cancel();
    _pendingSaves?.dispose();
    super.dispose();
  }

  void _open(String route) {
    // Reminders exist only after onboarding, which must come first anyway.
    if (!mounted || !ref.read(settingsProvider).onboardingComplete) return;
    openFromOutside(ref.read(routerProvider), route);
  }

  // A font that couldn't load (a network blip on the web) is tried again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadFonts();
  }

  /// Loads the opt-in fonts the settings choose, if they haven't loaded, and
  /// builds the theme in the interface font once it has.
  void _loadFonts() {
    final settings = ref.read(settingsProvider);
    OptionalFonts.ensureAll(settings.optionalFonts).then((_) {
      if (mounted && OptionalFonts.isLoaded(ref.read(settingsProvider).uiFont.family)) setState(() {});
    });
  }

  /// Whether the device asks for less motion: Android's Remove animations
  /// and the like come as MediaQuery's disableAnimations, but iOS's Reduce
  /// Motion comes only as an accessibility feature of its own, which
  /// MediaQuery leaves out.
  static bool _deviceReducesMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) || View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;

  // MediaQuery, which rebuilds the app as the other features change, has no
  // field for iOS's Reduce Motion, so its change alone wouldn't.
  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  // The text theme follows the platform's language when the app does, and
  // so do the shortcuts' titles and the home-screen widget.
  @override
  void didChangeLocales(List<Locale>? locales) {
    ref.invalidate(appShortcutsProvider);
    ref.invalidate(homeWidgetSyncProvider);
    setState(() {});
  }

  void _openShortcut(AppShortcut shortcut) {
    // Shortcuts are offered only after onboarding, which must come first.
    if (!mounted || !ref.read(settingsProvider).onboardingComplete) return;
    // The platform can hand over a shortcut before the app hears it has
    // resumed, perhaps days after it last ran.
    ref.read(todayProvider.notifier).refresh();
    final route = shortcut.route(ref.read(currentWeekContextProvider), justRead: ref.read(weekJustReadProvider));
    openFromOutside(ref.read(routerProvider), route);
  }

  void _openWidgetLink(WidgetLink link) {
    // The widget shows nothing to tap before onboarding, which must come
    // first anyway.
    if (!mounted || !ref.read(settingsProvider).onboardingComplete) return;
    // As for a shortcut, the app may not yet have heard it has resumed.
    ref.read(todayProvider.notifier).refresh();
    openFromOutside(ref.read(routerProvider), link.route(ref.read(currentWeekContextProvider)));
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
    // shortcuts in the app's language, the home-screen widget up to date, and
    // the cloud backup (if enabled) in sync with progress. The sync is only
    // kept alive (listened to, not watched): its timestamp must not rebuild
    // the app.
    ref.watch(reminderSchedulerProvider);
    ref.watch(appShortcutsProvider);
    ref.watch(homeWidgetSyncProvider);
    // A book of the Torah finished anywhere in the app is celebrated once.
    ref.watch(celebrationListenerProvider);
    ref.listen(progressSyncProvider, (_, _) {});
    // Opt-in fonts load when first chosen (and at start, in initState): the
    // Rashi script only once it is turned on, and Rashi shown.
    ref.listen(settingsProvider.select((s) => (s.uiFont, s.scriptureFont, s.rashiScript && s.showsRashi)), (_, _) => _loadFonts());
    if (OptionalFonts.isLoaded(settings.uiFont.family)) _uiFont = settings.uiFont;

    final systemHighContrast = MediaQuery.highContrastOf(context);
    final deviceReducesMotion = _deviceReducesMotion(context);
    final reduceMotion = settings.reduceMotion || deviceReducesMotion;

    final hebrewUi = _hebrewUi(settings.language);

    // [mode] is always a concrete theme: when following the system, MaterialApp
    // picks among the light, dark and high-contrast themes built below.
    ThemeData themeFor(AppThemeMode mode) => AppTheme.build(
          mode: mode,
          uiFont: _uiFont,
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
      onNavigationNotification: (notification) => AppShell.reportBack(router, notification),
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
        // The device's own, for the switches that show the app's.
        return DeviceAccessibility(
          disableAnimations: deviceReducesMotion,
          boldText: mq.boldText,
          child: MediaQuery(
            data: mq.copyWith(
              boldText: mq.boldText || settings.boldText,
              disableAnimations: reduceMotion,
              highContrast: systemHighContrast || AppTheme.isHighContrast(settings.theme),
            ),
            child: SystemBars(
              child: WindowTitleBar(
                child: FontsChangeScope(
                  // Status messages set for pages as wide as the window: those
                  // over the tabs, and a phone's (the shell sets them for the
                  // pane beside the rail).
                  child: FocusHighlightScope(child: StatusMessageArea.window(child: child!)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
