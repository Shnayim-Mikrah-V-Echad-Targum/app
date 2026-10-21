import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener, WidgetsBinding, basicLocaleListResolution;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../app/city_providers.dart';
import '../app/providers.dart';
import '../core/calendar/hebrew_date.dart';
import '../core/calendar/jewish_holidays.dart';
import '../core/calendar/local_date.dart';
import '../core/calendar/parsha_schedule.dart';
import '../core/calendar/zmanim.dart';
import '../core/text/hebrew_text.dart';
import '../data/parsha_repository.dart';
import '../features/parsha/week_context.dart';
import '../features/progress/domain/progress_models.dart';
import '../features/progress/domain/reading_plan.dart';
import '../features/settings/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../ui/l10n.dart' show AliyahNames;
import 'app_shortcuts.dart';

/// The App Group the iOS widget extension shares with the app, where the
/// timeline is saved (ios/Runner/Runner.entitlements and
/// ios/ParshaWidget/ParshaWidget.entitlements).
const kWidgetAppGroup = 'group.org.shnayimmikrah.app';

/// The key the timeline is saved under, which both widgets read.
const kWidgetTimelineKey = 'parsha_widget';

/// The Android widget (android/app/src/main/kotlin/.../ParshaWidgetProvider.kt).
const kAndroidWidgetProvider = 'org.shnayimmikrah.shnayim_mikrah.ParshaWidgetProvider';

/// The iOS widget's kind (ios/ParshaWidget/ParshaWidget.swift).
const kIOSWidgetKind = 'ParshaWidget';

/// Where a tap on the home-screen widget leads. Like a shortcut on the app's
/// icon, a link names a page rather than a week: the widget can be days old
/// when it is tapped, so each opens the current week as it is then.
enum WidgetLink {
  /// The widget itself: Today.
  today('today'),

  /// Its Continue: the reader, where Today's button continues.
  continueReading('continue');

  const WidgetLink(this.path);

  final String path;

  static const scheme = 'shnayimmikrah';

  /// The link the widget opens. The `homeWidget` query marks it as the
  /// widget's for home_widget on iOS, which hands the app only such links.
  Uri get uri => Uri.parse('$scheme://widget/$path?homeWidget');

  static WidgetLink? fromUri(Uri? uri) {
    if (uri == null || uri.scheme != scheme || uri.host != 'widget') return null;
    for (final link in values) {
      if (uri.path == '/${link.path}') return link;
    }
    return null;
  }

  /// The page this link opens in the current week [week]: Continue opens
  /// the reader as Today's button and the Continue reading shortcut do.
  String route(WeekContext week) => switch (this) {
        today => '/today',
        continueReading => AppShortcut.continueReading.route(week),
      };
}

/// What a day of the widget's timeline is, which decides what it shows: a
/// reading day has the week's progress and the day's reading, and a day of
/// rest only a greeting, as Today then rests.
enum WidgetDayKind {
  weekday,

  /// The reading day before Shabbat.
  erevShabbat,

  /// The reading day before a Yom Tov that is not Shabbat.
  erevYomTov,

  shabbat,

  /// Yom Tov, Shabbat or not; Yom Kippur and Rosh Hashanah too.
  yomTov,

  /// A reading day within a pause.
  paused,

  /// Tisha B'Av, with no reading planned on it: the week's progress, as
  /// Today keeps its rings, but no reading asked for and no Continue.
  tishaBav;

  bool get rests => this == shabbat || this == yomTov;
}

/// One week of the widget's timeline: its parsha's names, and its progress
/// as it stands now.
@immutable
class WidgetWeek {
  const WidgetWeek({
    required this.id,
    required this.hebrew,
    required this.name,
    required this.spoken,
    required this.progress,
    required this.spokenProgress,
    required this.mikrah1,
    required this.mikrah2,
    required this.targum,
    this.next,
  });

  final String id;

  /// The parsha's Hebrew name, pointed if the reader shows vowels.
  final String hebrew;

  /// Its transliterated name, in the reader's style, which the widget shows
  /// in the English UI alone.
  final String name;

  /// How a screen reader names it: in the Hebrew UI its Hebrew name, and in
  /// the English UI its transliterated one.
  final String spoken;

  /// "2 of 7 aliyot".
  final String progress;

  /// The week's rings in words, as their label gives them: "2 of 7 aliyot.
  /// First reading: 3 of 7. …".
  final String spokenProgress;

  /// How many of the seven aliyot each reading has covered.
  final int mikrah1;
  final int mikrah2;
  final int targum;

  /// Where the reading continues, as Today's button names it ("Continue ·
  /// Shlishi, Targum"); null once the week is complete.
  final String? next;

  Map<String, Object?> toJson() => {
        'id': id,
        'he': hebrew,
        'name': name,
        'say': spoken,
        'progress': progress,
        'sayProgress': spokenProgress,
        'm1': mikrah1,
        'm2': mikrah2,
        't': targum,
        if (next != null) 'next': next,
      };
}

/// One day of the widget's timeline, by the day the app keeps (the date,
/// which turns at 3 a.m.), or part of one: shown until [until], if given, and
/// then the next entry.
@immutable
class WidgetDay {
  const WidgetDay({
    required this.date,
    required this.week,
    required this.kind,
    required this.eyebrow,
    required this.line,
    this.until,
  });

  final LocalDate date;

  /// When the entry gives way to the next before the day turns: at midday
  /// on Friday and on the eve of Yom Tov, when the eyebrow turns to Erev
  /// Shabbat or Erev Yom Tov, and with a city for Shabbat times, as candles
  /// are lit on the eve of a day of rest and at nightfall as it ends, as
  /// Today turns then.
  final DateTime? until;

  /// The index of its week in [WidgetTimeline.weeks].
  final int week;

  final WidgetDayKind kind;
  final String eyebrow;

  /// The day's reading ("Today: Shlishi"), or on a day of rest its greeting.
  final String line;

  Map<String, Object?> toJson() => {
        'date': date.toIso(),
        if (until != null) 'until': until!.millisecondsSinceEpoch,
        'week': week,
        'kind': kind.name,
        'eyebrow': eyebrow,
        'line': line,
      };
}

/// What the home-screen widgets show, worked out by the app for each day
/// from today through the Shabbat of next week (and any Yom Tov straight
/// after it): a widget can't run the app's code on its own, so it picks the
/// entry for the day as it comes, with the progress as it stood when the app
/// last ran (it changes only while the app runs, which sends a new timeline
/// then). Every string is already in the app's language.
@immutable
class WidgetTimeline {
  const WidgetTimeline({
    required this.rtl,
    required this.stale,
    required this.weeks,
    required this.days,
    this.rests = const {},
  });

  /// Whether the app shows in Hebrew, which the widget then follows.
  final bool rtl;

  /// The line a widget shows once its days are over.
  final String stale;

  final List<WidgetWeek> weeks;
  final List<WidgetDay> days;

  /// The days of rest for some months after [days], each with its greeting:
  /// a widget left that long without the app still rests on them, with the
  /// candles and the greeting, rather than ask for the app on Shabbat.
  final Map<LocalDate, String> rests;

  Map<String, Object?> toJson() => {
        'v': 1,
        'rtl': rtl,
        'open': WidgetLink.today.uri.toString(),
        'continue': WidgetLink.continueReading.uri.toString(),
        'stale': stale,
        'weeks': [for (final w in weeks) w.toJson()],
        'days': [for (final d in days) d.toJson()],
        'rest': {for (final MapEntry(key: date, value: greeting) in rests.entries) date.toIso(): greeting},
      };

  String encode() => jsonEncode(toJson());
}

/// When candles are lit, the sun sets and Shabbat ends in the reader's
/// city, in minutes after midnight on the device's clock, on a day it keeps
/// the city's. Sunset begins Tisha B'Av on its eve.
typedef RestTimes = ({int? candleLighting, int? sunset, int? nightfall});

/// The widget's timeline as of [now] (see [WidgetTimeline]), in [l]'s
/// language, for a reader with [settings] and [progress], planned by
/// [planner]. [restTimes] gives the city's times on a day, where the app
/// follows them (see [restDayProvider]).
WidgetTimeline widgetTimeline({
  required DateTime now,
  required AppLocalizations l,
  required AppSettings settings,
  required ParshaRepository repo,
  required ReadingPlanner planner,
  required ProgressState progress,
  RestTimes? Function(LocalDate day)? restTimes,
}) {
  final schedule = planner.schedule;
  final israel = settings.oneDayYomTov;
  final rtl = l.localeName.startsWith('he');
  // The aliyot named as Today's card names them.
  final names = AliyahNames(l);
  final rashi = settings.usesRashi && !settings.usesOnkelos;

  String passName(ReadingPass pass) => switch (pass) {
        ReadingPass.mikrah1 => l.passMikrah1,
        ReadingPass.mikrah2 => l.passMikrah2,
        ReadingPass.targum => rashi ? l.passRashi : l.passTargum,
      };

  final contexts = <String, WeekContext>{};
  WeekContext contextFor(ReadingWeek week, LocalDate today) {
    final base = contexts[week.id] ??= () {
      final plan = planner.planFor(week);
      final info = repo.portion(week.portion);
      return WeekContext(
        week: week,
        plan: plan,
        portion: info,
        progress: progress.week(plan.weekId),
        today: today,
        status: null,
        haftarah: repo.haftarahFor(week.portion, week.occasion, settings.nusach),
        aliyahVerses: [for (var a = 0; a < kAliyot; a++) repo.aliyahVerseCount(info, a)],
        joinDate: settings.joinDate,
      );
    }();
    if (base.today == today) return base;
    return WeekContext(
      week: base.week,
      plan: base.plan,
      portion: base.portion,
      progress: base.progress,
      today: today,
      status: null,
      haftarah: base.haftarah,
      aliyahVerses: base.aliyahVerses,
      joinDate: base.joinDate,
    );
  }

  // Where the reading continues, exactly as Today's button names it.
  String? continueLabel(WeekContext ctx) {
    final next = ctx.nextAliyah;
    if (next == null) return null;
    final aliyah = names.aliyah(next);
    final p = ctx.progress;
    if (!p.isStarted) return l.startAt(aliyah);
    if (!ReadingPass.values.any((pass) => p.isUnitDone(next, pass))) return l.continueAt(aliyah);
    return l.continueAtPass(aliyah, passName(ReadingPass.values.firstWhere((pass) => !p.isUnitDone(next, pass))));
  }

  final weeks = <WidgetWeek>[];
  final weekIndex = <String, int>{};
  // A quiet Tisha B'Av has its week to itself, without Continue, as Today
  // has no button that day: the widgets show Continue wherever a week has
  // one.
  int indexOf(ReadingWeek week, LocalDate day, {bool quiet = false}) =>
      weekIndex[quiet ? '${week.id} quiet' : week.id] ??= () {
        final ctx = contextFor(week, day);
        final p = ctx.progress;
        int count(ReadingPass pass) => [for (var a = 0; a < kAliyot; a++) a].where((a) => p.isUnitDone(a, pass)).length;
        final counts = [for (final pass in ReadingPass.values) count(pass)];
        final info = ctx.portion;
        final name = info.displayName(ashkenazi: settings.ashkenaziNames);
        final hebrew = settings.showNikud
            ? HebrewText.forDisplay(info.nameHe, nikud: true, teamim: false)
            : HebrewText.stripNikud(info.nameHe);
        final progressLine = l.aliyotProgress(p.completedAliyot, kAliyot);
        weeks.add(WidgetWeek(
          id: ctx.id,
          hebrew: hebrew,
          name: name,
          spoken: rtl ? HebrewText.stripNikud(info.nameHe) : name,
          progress: progressLine,
          spokenProgress: [
            progressLine,
            for (final (i, pass) in ReadingPass.values.indexed) '${passName(pass)}: ${l.countOfTotal(counts[i], kAliyot)}',
          ].join('. '),
          mikrah1: counts[0],
          mikrah2: counts[1],
          targum: counts[2],
          next: p.isComplete || quiet ? null : continueLabel(ctx),
        ));
        return weeks.length - 1;
      }();

  // The day's reading, as Today's card gives it, on one line.
  String readingLine(WeekContext ctx, {required bool paused}) {
    if (ctx.progress.isComplete) return l.widgetWeekComplete;
    if (paused) return l.widgetPaused;
    final due = ctx.dueAliyot();
    if (ctx.behindBy() > 0 && due.isNotEmpty) return l.widgetCatchUp(names.aliyotSpan(due));
    final day = ctx.plan.dayFor(ctx.today);
    if (day == null) return l.widgetNothingToday;
    if (day.aliyot.every(ctx.progress.isAliyahDone)) return l.todayDone;
    return l.widgetToday(names.aliyot(day.aliyot));
  }

  // The day of rest's greeting, as Today's.
  String greeting(LocalDate day) {
    final hebrew = HebrewDate.fromLocalDate(day);
    if (JewishHolidays.isYomKippur(hebrew)) return l.gmarChatimaTova;
    if (JewishHolidays.isRoshHashanah(hebrew)) return l.shanaTova;
    if (JewishHolidays.isYomTov(hebrew, israel: israel)) return l.chagSameach;
    return l.shabbatShalom;
  }

  DateTime at(LocalDate day, int minutes) => DateTime(day.year, day.month, day.day, 0, minutes);

  final first = rolloverDate(now);
  final current = schedule.weekFor(effectiveReadingDay(now, oneDayYomTov: israel));
  // Through next week's Shabbat, and a Yom Tov straight after it: a widget
  // whose days run out then rests on, rather than ask for the app.
  var last = schedule.nextWeek(current).occasion;
  while (JewishHolidays.isRestDay(last.addDays(1), israel: israel)) {
    last = last.addDays(1);
  }
  final days = <WidgetDay>[];
  void add(WidgetDay day) {
    // Already over.
    if (day.until != null && !day.until!.isAfter(now)) return;
    days.add(day);
  }

  for (var day = first; day <= last; day = day.addDays(1)) {
    // The parsha read today, or on the Shabbat this day comes before.
    final week = schedule.weekFor(day);
    // Tisha B'Av, with no reading planned on it: as Today, headed by the
    // fast, with no reading asked for.
    if (planner.isQuietTishaBav(day)) {
      add(WidgetDay(
        date: day,
        week: indexOf(week, day, quiet: true),
        kind: WidgetDayKind.tishaBav,
        eyebrow: l.tishaBavTitle,
        line: l.widgetTishaBav,
      ));
      continue;
    }
    final index = indexOf(week, day);
    final vezot = week.portion.isVezotHaberakhah;
    final eyebrow = vezot ? l.simchatTorahEyebrow : l.parshatHashavua;
    final tomorrow = day.addDays(1);
    if (JewishHolidays.isRestDay(day, israel: israel)) {
      final yomTov = JewishHolidays.isYomTov(HebrewDate.fromLocalDate(day), israel: israel);
      // The last day of rest ends at nightfall in the city.
      final nightfall = JewishHolidays.isRestDay(tomorrow, israel: israel) ? null : restTimes?.call(day)?.nightfall;
      add(WidgetDay(
        date: day,
        until: nightfall == null ? null : at(day, nightfall),
        week: index,
        kind: yomTov ? WidgetDayKind.yomTov : WidgetDayKind.shabbat,
        eyebrow: eyebrow,
        line: greeting(day),
      ));
      continue;
    }
    final eve = JewishHolidays.isRestDay(tomorrow, israel: israel);
    final paused = progress.pauses.any((p) => p.contains(day));
    final kind = paused
        ? WidgetDayKind.paused
        : !eve
            ? WidgetDayKind.weekday
            : tomorrow.isShabbat
                ? WidgetDayKind.erevShabbat
                : WidgetDayKind.erevYomTov;
    final line = readingLine(contextFor(week, day), paused: paused);
    // The day of rest begins as candles are lit in the city, and a quiet
    // Tisha B'Av at sunset, as Today turns then (FastBegunController).
    final fastEve = planner.isQuietTishaBav(tomorrow);
    final turn = eve
        ? restTimes?.call(day)?.candleLighting
        : fastEve
            ? restTimes?.call(day)?.sunset
            : null;
    final until = turn == null ? null : at(day, turn);
    // From midday on Friday, Today's eyebrow is Erev Shabbat, and on the eve
    // of Yom Tov, Erev Yom Tov.
    final erevYomTov = JewishHolidays.erevYomTov(day, israel: israel);
    final afternoon = vezot
        ? null
        : day.weekday == _friday
            ? l.erevShabbat
            : erevYomTov == null
                ? null
                : l.erevYomTov(erevYomTov.name);
    if (afternoon != null) {
      add(WidgetDay(date: day, until: at(day, 12 * 60), week: index, kind: kind, eyebrow: eyebrow, line: line));
      add(WidgetDay(date: day, until: until, week: index, kind: kind, eyebrow: afternoon, line: line));
    } else {
      add(WidgetDay(date: day, until: until, week: index, kind: kind, eyebrow: eyebrow, line: line));
    }
    if (fastEve && until != null) {
      add(WidgetDay(
        date: day,
        week: indexOf(schedule.weekFor(tomorrow), tomorrow, quiet: true),
        kind: WidgetDayKind.tishaBav,
        eyebrow: l.tishaBavTitle,
        line: l.widgetTishaBav,
      ));
    }
  }
  final rests = {
    for (var day = last.addDays(1); day <= last.addDays(kWidgetRestDays); day = day.addDays(1))
      if (JewishHolidays.isRestDay(day, israel: israel)) day: greeting(day),
  };
  return WidgetTimeline(rtl: rtl, stale: l.widgetStale, weeks: weeks, days: days, rests: rests);
}

/// How many days after its last a timeline gives the days of rest
/// ([WidgetTimeline.rests]): about four months.
const kWidgetRestDays = 120;

/// [LocalDate.weekday] of Friday, from Sunday's 0.
const _friday = 5;

/// The home-screen widgets on Android and iOS: what they show, sent as a
/// [WidgetTimeline], and the taps on them. Only Android and iOS have them.
class HomeWidgetService {
  HomeWidgetService._(this._now) : supported = true;

  /// For tests and the platforms without home-screen widgets.
  HomeWidgetService.disabled()
      : supported = false,
        _now = DateTime.now;

  /// Starts listening for taps on the widget, so that one that launched the
  /// app is held until [listen] is called. [now] is for tests.
  static Future<HomeWidgetService> create({@visibleForTesting DateTime Function() now = DateTime.now}) async {
    final platform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    if (!platform) return HomeWidgetService.disabled();
    final service = HomeWidgetService._(now);
    try {
      // iOS keeps the widget's data in the App Group both targets share.
      if (defaultTargetPlatform == TargetPlatform.iOS) await HomeWidget.setAppGroupId(kWidgetAppGroup);
      service._taps = HomeWidget.widgetClicked.listen(service._tap, onError: (Object e) {
        debugPrint('Home-screen widget taps unavailable: $e');
      });
      service._tap(await HomeWidget.initiallyLaunchedFromHomeWidget());
      return service;
    } catch (e) {
      debugPrint('Home-screen widget unavailable: $e');
      await service._taps?.cancel();
      return HomeWidgetService.disabled();
    }
  }

  final bool supported;
  final DateTime Function() _now;
  StreamSubscription<Uri?>? _taps;

  ValueChanged<WidgetLink>? _open;
  WidgetLink? _waiting;
  (WidgetLink, DateTime)? _last;

  /// Hands every link the user taps on the widget to [open], beginning with
  /// one tapped before now (the one that launched the app).
  void listen(ValueChanged<WidgetLink> open) {
    _open = open;
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null) open(waiting);
  }

  void _tap(Uri? uri) {
    final link = WidgetLink.fromUri(uri);
    if (link == null) return;
    // The same tap can arrive as the app starts and again as it resumes.
    final now = _now();
    final last = _last;
    _last = (link, now);
    if (last != null && last.$1 == link && now.difference(last.$2) < const Duration(seconds: 2)) return;
    final open = _open;
    if (open == null) {
      _waiting = link;
    } else {
      open(link);
    }
  }

  /// Pushes are at most this often: one change often brings others with it
  /// (a reading marked, the reading day, the streaks).
  static const throttle = Duration(seconds: 1);

  Timer? _timer;
  String? Function()? _payload;
  bool _force = false;
  bool _sent = false;
  String? _shown;

  /// Sends the timeline [payload] gives (null clears the widget) within
  /// [throttle], once no newer request has replaced it, unless it is the one
  /// already sent. With [force] it is sent even then, in case the platform
  /// lost it.
  void request(String? Function() payload, {bool force = false}) {
    if (!supported) return;
    _payload = payload;
    _force |= force;
    _timer ??= Timer(throttle, _send);
  }

  Future<void> _send() async {
    _timer = null;
    final payload = _payload;
    final force = _force;
    _payload = null;
    _force = false;
    if (payload == null) return;
    final json = payload();
    if (_sent && json == _shown && !force) return;
    _sent = true;
    _shown = json;
    try {
      await HomeWidget.saveWidgetData<String>(kWidgetTimelineKey, json);
      await HomeWidget.updateWidget(qualifiedAndroidName: kAndroidWidgetProvider, iOSName: kIOSWidgetKind);
    } catch (e) {
      _sent = false;
      debugPrint('Could not update the home-screen widget: $e');
    }
  }
}

final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) => HomeWidgetService.disabled());

/// The language the app shows in, resolved as MaterialApp resolves it.
AppLocalizations _appLocalizations(AppLanguage language) => lookupAppLocalizations(switch (language) {
      AppLanguage.english => const Locale('en'),
      AppLanguage.hebrew => const Locale('he'),
      AppLanguage.system => basicLocaleListResolution(
          WidgetsBinding.instance.platformDispatcher.locales,
          AppLocalizations.supportedLocales,
        ),
    });

/// Keeps the home-screen widgets up to date: sends them a new timeline
/// whenever what they show changes (the reading log, the reading day, the
/// settings they show it by), and again each time the app resumes. Before
/// onboarding they show only the app's name, as there is nothing to show.
///
/// The device's language isn't watched: the app invalidates this provider
/// when it changes.
final homeWidgetSyncProvider = Provider<void>((ref) {
  final service = ref.watch(homeWidgetServiceProvider);
  if (!service.supported) return;
  final s = ref.watch(settingsProvider.select((s) => (
        onboarded: s.onboardingComplete,
        language: s.language,
        nameStyle: s.nameStyle,
        nikud: s.showNikud,
        secondReading: s.secondReading,
        oneDayYomTov: s.oneDayYomTov,
        joinDate: s.joinDate,
        place: s.shabbatCity,
      )));
  String? Function() payload;
  if (!s.onboarded) {
    payload = () => null;
  } else {
    // The reading log, not the place saved in it (see
    // ProgressState.logRevision), but for whether this week is begun, which
    // turns Today's "Start" to "Continue".
    ref.watch(progressProvider.select((p) => p.logRevision));
    ref.watch(currentWeekContextProvider.select((c) => c.progress.isStarted));
    // The reading day, which turns at 3 a.m. and on resuming.
    ref.watch(todayProvider);
    final planner = ref.watch(plannerProvider);
    final repo = ref.watch(parshaRepositoryProvider);
    final settings = ref.read(settingsProvider);
    final progress = ref.read(progressProvider);
    final place = s.place;
    final citysTimes = place != null && timeZonesReady(ref);
    final clock = ref.watch(deviceClockProvider);
    // By the reader's customs, as Today rests by them.
    RestTimes? restTimes(LocalDate day) {
      if (!citysTimes || !Zmanim.keepsClock(place.city, day, clock(day))) return null;
      final times = place.on(day);
      return (
        candleLighting: times.minutesOf(times.candleLighting),
        sunset: times.minutesOf(times.sunset),
        nightfall: times.minutesOf(times.havdalah),
      );
    }

    final l = _appLocalizations(s.language);
    payload = () => widgetTimeline(
          now: TodayController.now(),
          l: l,
          settings: settings,
          repo: repo,
          planner: planner,
          progress: progress,
          restTimes: restTimes,
        ).encode();
  }
  service.request(payload);
  final lifecycle = AppLifecycleListener(onResume: () => service.request(payload, force: true));
  ref.onDispose(lifecycle.dispose);
});
