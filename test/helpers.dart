import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/app.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/data/parsha_repository.dart';
import 'package:shnayim_mikra/features/community/data/backend.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/services/notifications.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';

ParshaRepository? _repo;

Future<void>? _fonts;

/// Registers every font in FontManifest.json, so widget tests lay text out
/// with real glyph metrics instead of the test font's uniform squares. Call it
/// from `setUpAll`; it loads the fonts only once per test file.
///
/// NotoSans is also registered as Roboto, the family Material's typography
/// asks for when the theme names none, so text renders as it does on the web.
Future<void> loadBundledFonts() => _fonts ??= () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final entry in manifest.cast<Map<String, dynamic>>()) {
        final family = entry['family'] as String;
        final assets = [for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) font['asset'] as String];
        for (final name in [family, if (family == 'NotoSans') 'Roboto']) {
          final loader = FontLoader(name);
          for (final asset in assets) {
            loader.addFont(rootBundle.load(asset));
          }
          await loader.load();
        }
      }
    }();

Future<ParshaRepository> loadRepo() async => _repo ??= await ParshaRepository.load();

/// A history with every past state of the Torah map, as of [historyNow]: a
/// reader who joined on [historyJoinDate] read Bereshit and Chayei Sara on
/// time, finished Noach after its Shabbat, never finished Lech-Lecha, and
/// made Vayera up a week late. Toldot is this week's.
ProgressState historyProgress() {
  WeekProgress week(int parsha, LocalDate done) => WeekProgress(weekId: '5787:$parsha').withAll(done);
  final weeks = [
    week(1, LocalDate(2026, 10, 8)),
    week(2, LocalDate(2026, 10, 19)),
    week(4, LocalDate(2026, 11, 9)),
    week(5, LocalDate(2026, 11, 5)),
  ];
  return ProgressState(weeks: {for (final w in weeks) w.weekId: w});
}

/// Wednesday 11 November 2026, in the week of Toldot (see [historyProgress]).
final historyNow = DateTime(2026, 11, 11, 10);

/// Sunday 4 October 2026, Simchat Torah in the Diaspora.
final historyJoinDate = LocalDate(2026, 10, 4);

/// Pumps the whole app with in-memory storage and the demo backend (or
/// [forums], when given).
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(onboardingComplete: true),
  DateTime? now,
  ProgressState? progress,
  ForumRepository? forums,
}) async {
  TodayController.autoRollover = false;
  if (now != null) TodayController.now = () => now;
  SharedPreferences.setMockInitialValues({
    'flutter.settings.v1': jsonEncode(settings.toJson()),
    if (progress != null) 'flutter.progress.v1': jsonEncode(progress.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  final repo = await tester.runAsync(loadRepo);
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    parshaRepositoryProvider.overrideWithValue(repo!),
    backendProvider.overrideWithValue(Backend(forums ?? DemoForumRepository())),
    notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const ShnayimMikraApp()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}

/// Pumps the app on [route] in a [size] view at [textScale], and waits for
/// asset-backed content (text previews, for example) to load.
Future<ProviderContainer> openRoute(
  WidgetTester tester,
  String route, {
  AppSettings settings = const AppSettings(onboardingComplete: true),
  DateTime? now,
  Size size = const Size(412, 915),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final container = await pumpApp(tester, settings: settings, now: now);
  container.read(routerProvider).go(route);
  await tester.pumpAndSettle();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pumpAndSettle();
  return container;
}

/// Pumps [child] on a page in the app's [theme], in English or Hebrew, as the
/// app would show it, for widget tests that don't need the whole app.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  AppThemeMode theme = AppThemeMode.light,
  bool hebrew = false,
  UiFont uiFont = UiFont.standard,
  double textScale = 1,
}) =>
    tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(mode: theme, uiFont: uiFont, hebrewUi: hebrew, reduceMotion: false),
      // A test that pumps a second theme sees it at once.
      themeAnimationDuration: Duration.zero,
      locale: Locale(hebrew ? 'he' : 'en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, page) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: page!,
      ),
      home: Scaffold(body: child),
    ));
