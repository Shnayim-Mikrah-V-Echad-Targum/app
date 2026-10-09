import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/community/data/community_providers.dart';
import '../features/settings/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../services/notifications.dart';
import '../ui/theme/app_theme.dart';
import 'providers.dart';
import 'router.dart';

class ShnayimMikraApp extends ConsumerStatefulWidget {
  const ShnayimMikraApp({super.key});

  @override
  ConsumerState<ShnayimMikraApp> createState() => _ShnayimMikraAppState();
}

class _ShnayimMikraAppState extends ConsumerState<ShnayimMikraApp> {
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    final notifications = ref.read(notificationServiceProvider);
    // Subscribed directly, so that a tap opening the same page as the last
    // one still opens it.
    _taps = notifications.taps.listen(_open);
    // The app starts on Today; a notification that launched it opens over it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = notifications.launchRoute;
      notifications.launchRoute = null;
      if (route != null && route != '/today') _open(route);
    });
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  void _open(String route) {
    // Reminders exist only after onboarding, which must come first anyway.
    if (!mounted || !ref.read(settingsProvider).onboardingComplete) return;
    openFromOutside(ref.read(routerProvider), route);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    // Keep scheduled reminders in sync with settings and progress, and the
    // cloud backup (if enabled) in sync with progress. The sync is only kept
    // alive (listened to, not watched): its timestamp must not rebuild the app.
    ref.watch(reminderSchedulerProvider);
    ref.listen(progressSyncProvider, (_, _) {});

    final platform = MediaQuery.platformBrightnessOf(context);
    final systemHighContrast = MediaQuery.highContrastOf(context);
    final reduceMotion = settings.reduceMotion || MediaQuery.disableAnimationsOf(context);

    ThemeData themeFor(AppThemeMode mode) => AppTheme.build(
          scheme: AppTheme.scheme(mode, platform),
          uiFont: settings.uiFont,
          highContrast: AppTheme.isHighContrast(mode),
          reduceMotion: reduceMotion,
        );

    final followSystem = settings.theme == AppThemeMode.system;
    final ThemeData light;
    final ThemeData dark;
    if (followSystem) {
      light = themeFor(AppThemeMode.light);
      dark = themeFor(AppThemeMode.dark);
    } else {
      light = dark = themeFor(settings.theme);
    }

    final locale = switch (settings.language) {
      AppLanguage.system => null,
      AppLanguage.english => const Locale('en'),
      AppLanguage.hebrew => const Locale('he'),
    };

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
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
      highContrastTheme: followSystem ? themeFor(AppThemeMode.highContrastLight) : null,
      highContrastDarkTheme: followSystem ? themeFor(AppThemeMode.highContrastDark) : null,
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
          child: child!,
        );
      },
    );
  }
}
