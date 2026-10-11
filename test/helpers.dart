import 'dart:convert';
import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/app.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/jewish_holidays.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/data/parsha_repository.dart';
import 'package:shnayim_mikra/features/community/data/backend.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/services/notifications.dart';
import 'package:shnayim_mikra/services/optional_fonts.dart';
import 'package:shnayim_mikra/services/reminder_planner.dart';
import 'package:shnayim_mikra/services/tts.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';

ParshaRepository? _repo;

Future<void>? _fonts;

/// Registers every font in FontManifest.json, and every font the app loads
/// on demand (see [OptionalFonts]), so widget tests lay text out with real
/// glyph metrics instead of the test font's uniform squares. Call it from
/// `setUpAll`; it loads the fonts only once per test file.
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
      // Through OptionalFonts, so that the app finds them already loaded.
      for (final family in OptionalFonts.families) {
        await OptionalFonts.ensure(family);
      }
    }();

Future<ParshaRepository> loadRepo() async => _repo ??= await ParshaRepository.load();

/// The day of the capture harness (test/screens/capture_test.dart) and of
/// the goldens (test/goldens/): Friday 9 October 2026 (28 Tishrei 5787), in
/// the week of Bereshit. Sunday was Simchat Torah in the Diaspora, so the
/// reading week began on Monday.
final captureNow = DateTime(2026, 10, 9, 11);

/// When the reader of [captureProgress] joined: Simchat Torah, before the
/// week of Bereshit.
final captureJoinDate = LocalDate(2026, 10, 4);

/// The reader of [captureNow]: Rishon and Sheni of Bereshit read in all three
/// readings on Monday and Tuesday, and Shlishi twice on Wednesday, its
/// Targum still to read.
ProgressState captureProgress() {
  final mon = LocalDate(2026, 10, 5);
  var w = WeekProgress(weekId: '5787:1');
  for (final p in ReadingPass.values) {
    w = w.withUnit(0, p, mon).withUnit(1, p, mon.addDays(1));
  }
  w = w.withUnit(2, ReadingPass.mikra1, mon.addDays(2)).withUnit(2, ReadingPass.mikra2, mon.addDays(2));
  return ProgressState(weeks: {'5787:1': w});
}

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

/// The Sunday of Vayera 5786, when the reader of [secondYearProgress]
/// joined.
final secondYearJoinDate = LocalDate(2025, 11, 2);

/// A reader in their second year: they joined on [secondYearJoinDate] and
/// read every aliyah of 5786 on its planned day, from Vayera to Vezot
/// HaBerakhah, but for Vayakhel-Pekudei, finished on the Monday after its
/// Shabbat. Before [historyNow] and the week of Bereshit 5787.
Map<String, WeekProgress> secondYearProgress() {
  const planner = ReadingPlanner(schedule: ParshaSchedule(israel: false));
  final weeks = <String, WeekProgress>{};
  for (var week = planner.schedule.weekFor(secondYearJoinDate);
      week.occasion < LocalDate(2026, 10, 5);
      week = planner.schedule.nextWeek(week)) {
    final plan = planner.planFor(week);
    final late = week.portion.number == 22;
    var w = WeekProgress(weekId: plan.weekId);
    for (final day in plan.days) {
      for (final a in day.aliyot) {
        w = w.withAliyah(a, late ? week.occasion.addDays(2) : day.date);
      }
    }
    for (final a in plan.shabbatAliyot) {
      w = w.withAliyah(a, week.occasion);
    }
    weeks[plan.weekId] = w;
  }
  return weeks;
}

/// The device's clock, moved on from Shabbat or Yom Tov (outside Israel,
/// which has more of them) to the same time on the next weekday: the
/// reading day those days count toward. A test that doesn't fix the clock
/// then sees the same Today whatever day it runs on, rather than Today's
/// rest on Shabbat.
DateTime _readingDayClock() {
  var now = DateTime.now();
  while (JewishHolidays.isRestDay(rolloverDate(now), israel: false)) {
    now = now.add(const Duration(days: 1));
  }
  return now;
}

/// Pumps the whole app with in-memory storage and the demo backend (or
/// [forums], when given), and notifications disabled (or [notifications]),
/// and any further [overrides]. Storage holds [settings], [progress] and
/// anything else in [stored], by key. The clock is [now], if given, and
/// otherwise the device's moved off any day of rest (see [_readingDayClock]).
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(onboardingComplete: true),
  DateTime? now,
  ProgressState? progress,
  Map<String, Object> stored = const {},
  ForumRepository? forums,
  NotificationService? notifications,
  List<Override> overrides = const [],
}) async {
  TodayController.autoRollover = false;
  if (now != null) {
    TodayController.now = () => now;
  } else if (identical(TodayController.now, DateTime.now)) {
    TodayController.now = _readingDayClock;
  }
  SharedPreferences.setMockInitialValues({
    'flutter.settings.v1': jsonEncode(settings.toJson()),
    if (progress != null) 'flutter.progress.v1': jsonEncode(progress.toJson()),
    for (final MapEntry(:key, :value) in stored.entries) 'flutter.$key': value,
  });
  final prefs = await SharedPreferences.getInstance();
  final repo = await tester.runAsync(loadRepo);
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    parshaRepositoryProvider.overrideWithValue(repo!),
    backendProvider.overrideWithValue(Backend(forums ?? DemoForumRepository())),
    notificationServiceProvider.overrideWithValue(notifications ?? NotificationService.disabled()),
    ...overrides,
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const ShnayimMikraApp()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}

/// Pumps the app on [route] in a [size] view at [textScale], with
/// notifications disabled (or [notifications]), and waits for asset-backed
/// content (text previews, for example) to load.
Future<ProviderContainer> openRoute(
  WidgetTester tester,
  String route, {
  AppSettings settings = const AppSettings(onboardingComplete: true),
  DateTime? now,
  Size size = const Size(412, 915),
  double textScale = 1,
  NotificationService? notifications,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final container = await pumpApp(tester, settings: settings, now: now, notifications: notifications);
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

/// Text-to-speech that records what it is asked to say, and says nothing.
/// Override [ttsProvider] with it.
class RecordingTts extends TtsService {
  RecordingTts() : super(engine: _SilentEngine());

  /// Each text asked for, with its language.
  final spoken = <(String, String)>[];

  @override
  Future<bool?> hasHebrewVoice() async => true;

  /// Each text asked for, joined as one voice would read them in turn.
  String get spokenText => spoken.map((s) => s.$1).join(' ');

  @override
  Future<bool> speak(String text, {required String language, double rate = 0.45}) async {
    spoken.add((text, language));
    return true;
  }
}

class _SilentEngine extends Fake implements FlutterTts {
  @override
  void setStartHandler(VoidCallback callback) {}
  @override
  void setCompletionHandler(VoidCallback callback) {}
  @override
  void setCancelHandler(VoidCallback callback) {}
  @override
  void setErrorHandler(ErrorHandler handler) {}
  @override
  Future<dynamic> stop() async => 1;
}

/// Reminders as on a phone, where they are available: for pages that show
/// their settings. Schedules nothing.
class PhoneNotifications extends NotificationService {
  PhoneNotifications() : super.forTesting(_NoPlugin(), loadTimeZones: () async {});

  @override
  Future<void> reschedule(
          List<PlannedReminder> reminders, AppLocalizations l, ReminderCopy Function(PlannedReminder) describe) async {}
}

class _NoPlugin extends Fake implements FlutterLocalNotificationsPlugin {}

/// Finds a text that contains [words], any of whose spaces may be no-break
/// spaces, as a line of parts sets them to keep a clause together when a
/// part is too long for a line of its own (DotLine).
Finder findWords(String words) => find.textContaining(wordsRegExp(RegExp.escape(words)));

/// [pattern] with each space matching a no-break space too (see [findWords]).
RegExp wordsRegExp(String pattern) => RegExp(pattern.replaceAll(' ', '[ \u00A0]'));

/// Expects each word of [text], shown in a [Text], to stand on one line, as
/// a word too wide for its room, broken across lines, would not.
void expectWordsWhole(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)).first,
  );
  for (final word in RegExp(r'\S+').allMatches(text)) {
    final lines = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
      boxHeightStyle: BoxHeightStyle.max,
    );
    expect({for (final box in lines) box.top.round()}, hasLength(1), reason: '"${word.group(0)}" of "$text"');
  }
}
