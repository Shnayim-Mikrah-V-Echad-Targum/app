import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/reader/haftarah_screen.dart';
import 'package:shnayim_mikra/features/reader/listen_along.dart';
import 'package:shnayim_mikra/features/reader/listen_bar.dart';
import 'package:shnayim_mikra/features/reader/reader_screen.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/widgets/settings_widgets.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/services/tts.dart';

import '../../helpers.dart';

/// Speech on a device that has none: every queue fails.
class _FailingTts extends RecordingTts {
  @override
  Future<bool> speakQueue(List<String> items,
          {required String language, double rate = kDefaultSpeechRate, int startAt = 0, List<int>? groups}) =>
      Future.error(PlatformException(code: 'no-engine'));
}

void main() {
  final monday = DateTime(2026, 10, 12, 10); // the week of Noach, 5787

  Future<void> loadTexts(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> open(
    WidgetTester tester,
    String path,
    TtsService tts, {
    AppSettings settings = const AppSettings(onboardingComplete: true),
    DateTime? now,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: settings,
      now: now ?? monday,
      overrides: [ttsProvider.overrideWithValue(tts)],
    );
    c.read(routerProvider).go(path);
    await loadTexts(tester);
    return c;
  }

  // The full text's verses that are highlighted, by index.
  List<int> highlighted(WidgetTester tester) => [
        for (final (i, group) in tester.widgetList<VerseGroup>(find.byType(VerseGroup)).indexed)
          if (group.highlighted) i,
      ];

  // The verses of the guided reader or the haftarah that are highlighted.
  List<int> marked(WidgetTester tester) => [
        for (final (i, mark) in tester.widgetList<SpeakingVerseMark>(find.byType(SpeakingVerseMark)).indexed)
          if (mark.active) i,
      ];

  final player = find.byType(ListenBar);
  Finder inPlayer(String tooltip) => find.descendant(of: player, matching: find.byTooltip(tooltip));

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  group('in the full text, Listen', () {
    testWidgets('highlights each verse as it is read, with its Targum, and goes on from the same verse after a pause',
        (tester) async {
      final tts = HeldTts();
      await open(tester, '/read/5787:2/0?mode=full', tts);
      expect(player, findsNothing);
      await tester.tap(find.byTooltip('Listen'));
      await tester.pumpAndSettle();

      // Genesis 6:9, then its Onkelos, both its verse's.
      expect(player, findsOneWidget);
      expect(tts.last, startsWith('אלה תולדת נח'));
      expect(highlighted(tester), [0]);
      tts.finish();
      await tester.pumpAndSettle();
      expect(tts.last, startsWith('אלן תולדת נח'));
      expect(highlighted(tester), [0]);
      tts.finish();
      await tester.pumpAndSettle();
      expect(tts.last, startsWith('ויולד נח שלשה בנים'));
      expect(highlighted(tester), [1]);
      final verse = tts.spoken.length;

      await tester.tap(inPlayer('Pause'));
      await tester.pumpAndSettle();
      expect(inPlayer('Resume'), findsOneWidget);
      expect(highlighted(tester), [1], reason: 'the verse it paused at stays marked');
      await tester.tap(inPlayer('Resume'));
      await tester.pumpAndSettle();
      expect(tts.spoken.length, verse + 1);
      expect(tts.spoken.last, tts.spoken[verse - 1], reason: 'the same verse, from its start');
      expect(highlighted(tester), [1]);

      // The player's controls are named, and big enough to take a tap.
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await tester.tap(inPlayer('Stop'));
      await tester.pumpAndSettle();
      expect(player, findsNothing);
      expect(highlighted(tester), isEmpty);
      expect(find.byTooltip('Listen'), findsOneWidget);
    });

    testWidgets('moves verse by verse, and is played and paused, from the keyboard', (tester) async {
      final tts = HeldTts();
      await open(tester, '/read/5787:2/0?mode=full', tts);
      await press(tester, LogicalKeyboardKey.keyL);
      expect(highlighted(tester), [0]);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(highlighted(tester), [2]);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(highlighted(tester), [1]);
      // Each move reads the verse from its Mikra.
      expect(tts.last, startsWith('ויולד נח שלשה בנים'));

      await press(tester, LogicalKeyboardKey.keyL);
      expect(inPlayer('Resume'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.keyL);
      expect(inPlayer('Pause'), findsOneWidget);
      expect(highlighted(tester), [1]);
    });

    testWidgets('starts at the first verse in view, and the text follows the voice', (tester) async {
      final tts = HeldTts();
      await open(tester, '/read/5787:2/0?mode=full', tts);
      // Scrolled so that the fourth verse (6:12) is the first in view.
      unawaited(Scrollable.ensureVisible(tester.element(find.byType(VerseGroup).at(3))));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Listen'));
      await tester.pumpAndSettle();
      expect(highlighted(tester), [3]);

      // The voice goes on past the screen's foot, and the text with it.
      for (var i = 0; i < 40 && highlighted(tester).single < 9; i++) {
        tts.finish();
        await tester.pumpAndSettle();
      }
      expect(highlighted(tester), [9]);
      final reading = tester.getRect(find.byType(VerseGroup).at(9));
      expect(reading.top, greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom));
      expect(reading.top, lessThan(tester.getRect(player).top - 100));
    });

    testWidgets('in focus mode, ↓ and ↑ move the voice, which stays the focused verse, paused or not',
        (tester) async {
      final tts = HeldTts();
      await open(tester, '/read/5787:2/0?mode=full', tts,
          settings: const AppSettings(onboardingComplete: true, focusMode: true));
      await tester.tap(find.byTooltip('Listen'));
      await tester.pumpAndSettle();
      await tester.tap(inPlayer('Pause'));
      await tester.pumpAndSettle();
      final said = tts.spoken.length;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(highlighted(tester), [1], reason: 'one verse highlighted, the one the voice is at');
      expect(inPlayer('Resume'), findsOneWidget, reason: 'still paused');
      expect(tts.spoken.length, said);
      final verses = tester.widgetList<ScriptureVerse>(find.byType(ScriptureVerse)).toList();
      expect([for (final v in verses.take(4)) v.dimmed], [true, true, false, false]);

      await tester.tap(inPlayer('Resume'));
      await tester.pumpAndSettle();
      expect(tts.last, startsWith('ויולד נח שלשה בנים'), reason: 'goes on from the verse ↓ reached');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(highlighted(tester), [2]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(highlighted(tester), [1]);
      expect(tts.last, startsWith('ויולד נח שלשה בנים'));

      // A tap reads from the verse tapped.
      await Scrollable.ensureVisible(tester.element(find.byType(VerseGroup).at(3)), alignment: 0.3);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VerseGroup).at(3));
      await tester.pumpAndSettle();
      expect(highlighted(tester), [3]);
      expect(tts.last, startsWith('וירא אלהים את הארץ'));
    });

    testWidgets('says so where the device cannot speak', (tester) async {
      await open(tester, '/read/5787:2/0?mode=full', _FailingTts());
      await tester.tap(find.byTooltip('Listen'));
      await tester.pumpAndSettle();
      expect(find.text('Text-to-speech isn’t available on this device.'), findsOneWidget);
      expect(player, findsNothing);
      expect(highlighted(tester), isEmpty);
      expect(find.byTooltip('Listen'), findsOneWidget);
    });

    testWidgets('in focus mode, the verse being read is the focused one, and none of those dimmed', (tester) async {
      final tts = HeldTts();
      await open(tester, '/read/5787:2/0?mode=full', tts,
          settings: const AppSettings(onboardingComplete: true, focusMode: true));
      await tester.tap(find.byTooltip('Listen'));
      await tester.pumpAndSettle();
      tts.finish();
      await tester.pumpAndSettle();
      tts.finish();
      await tester.pumpAndSettle();
      expect(highlighted(tester), [1]);
      final verses = tester.widgetList<ScriptureVerse>(find.byType(ScriptureVerse)).toList();
      // The second verse and its Targum, in full ink; the first, dimmed.
      expect([for (final v in verses.take(4)) v.dimmed], [true, true, false, false]);
    });
  });

  group('in the guided reader, Listen', () {
    testWidgets('highlights each verse of a section as it is read', (tester) async {
      final tts = HeldTts();
      await open(tester, '/read/5787:2/0', tts,
          settings: const AppSettings(onboardingComplete: true, method: ReadingMethod.sectionBySection));
      await tester.tap(find.byTooltip('Listen'));
      await tester.pumpAndSettle();
      expect(marked(tester), [0]);
      tts.finish();
      await tester.pumpAndSettle();
      expect(marked(tester), [1]);
      // Next stops it, as it always has.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(player, findsNothing);
      expect(marked(tester), isEmpty);
    });

    testWidgets('with Listen along, reads Mikra, Mikra and Targum hands-free, and leaves Finish to the reader',
        (tester) async {
      final tts = RecordingTts();
      final c = await open(tester, '/read/5787:2/0', tts,
          settings: const AppSettings(
            onboardingComplete: true,
            method: ReadingMethod.aliyahByAliyah,
            listenAlong: true,
          ));
      expect(find.text('Read the Hebrew'), findsOneWidget);
      await tester.tap(find.byTooltip('Listen'));
      await tester.pump();
      await tester.pump();
      final verses = tts.spoken.length;
      expect(verses, greaterThan(1));
      // A breath between readings, the player still there.
      expect(find.text('Read the Hebrew'), findsOneWidget);
      expect(player, findsOneWidget);

      // On after its breath, faded in, and read: the next breath is under
      // way (this speech says everything at once).
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Read the Hebrew again'), findsOneWidget);
      expect(tts.spoken.length, 2 * verses);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Read the Targum'), findsOneWidget);
      expect(tts.spoken.length, 3 * verses);
      // The Targum read, it stops: the reader finishes the aliyah.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Read the Targum'), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);
      expect(player, findsNothing);

      // Each reading recorded as Next records it, and no more.
      final week = c.read(progressProvider).week('5787:2');
      expect(week.isUnitDone(0, ReadingPass.mikra1), isTrue);
      expect(week.isUnitDone(0, ReadingPass.mikra2), isTrue);
      expect(week.isUnitDone(0, ReadingPass.targum), isFalse);
    });

    testWidgets('in the breath between readings, back reads the last verse again, and on goes to the next reading',
        (tester) async {
      final tts = RecordingTts();
      await open(tester, '/read/5787:2/0', tts,
          settings: const AppSettings(
            onboardingComplete: true,
            method: ReadingMethod.aliyahByAliyah,
            listenAlong: true,
          ));
      await tester.tap(find.byTooltip('Listen'));
      await tester.pump();
      await tester.pump();
      final verses = tts.spoken.length;
      final lastVerse = tts.spoken.last;

      // Back: the step's last verse once more, and then the breath again.
      expect(tester.widget<IconButton>(find.descendant(of: player, matching: find.widgetWithIcon(IconButton, Icons.skip_previous_rounded))).onPressed, isNotNull);
      await tester.tap(inPlayer('Previous verse'));
      await tester.pump();
      await tester.pump();
      expect(tts.spoken.length, verses + 1);
      expect(tts.spoken.last, lastVerse);
      expect(find.text('Read the Hebrew'), findsOneWidget, reason: 'still the first reading');

      // On: the next reading at once, without its breath.
      await tester.tap(inPlayer('Next verse'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Read the Hebrew again'), findsOneWidget);
      expect(tts.spoken.length, 2 * verses + 1);
      await tester.tap(inPlayer('Stop'));
      await tester.pumpAndSettle();
    });

    testWidgets('the display sheet turns Listen along on, where the haftarah\'s has no such switch', (tester) async {
      final c = await open(tester, '/read/5787:2/0', RecordingTts());
      await tester.tap(find.byTooltip('Display settings'));
      await tester.pumpAndSettle();
      final row = find.widgetWithText(SwitchRow, 'Listen along');
      await tester.scrollUntilVisible(row, 100, scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first);
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).listenAlong, isTrue);
      Navigator.pop(tester.element(find.byType(BottomSheet)));
      await tester.pumpAndSettle();

      c.read(routerProvider).go('/haftarah/5787:2');
      await loadTexts(tester);
      await tester.tap(find.byTooltip('Display settings'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Listen along', skipOffstage: false), findsNothing);
    });

    testWidgets('paused in the breath between readings, waits there', (tester) async {
      final tts = RecordingTts();
      await open(tester, '/read/5787:2/0', tts,
          settings: const AppSettings(
            onboardingComplete: true,
            method: ReadingMethod.aliyahByAliyah,
            listenAlong: true,
          ));
      await tester.tap(find.byTooltip('Listen'));
      await tester.pump();
      await tester.pump();
      await tester.tap(inPlayer('Pause'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Read the Hebrew'), findsOneWidget);
      expect(inPlayer('Resume'), findsOneWidget);

      await tester.tap(inPlayer('Resume'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Read the Hebrew again'), findsOneWidget);
      await tester.tap(inPlayer('Stop'));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('a rate chosen from the player is kept, and the verse is read again at it', (tester) async {
    final tts = HeldTts();
    final c = await open(tester, '/read/5787:2/0?mode=full', tts);
    await tester.tap(find.byTooltip('Listen'));
    await tester.pumpAndSettle();
    final said = tts.spoken.length;
    expect(
      tester.getSemantics(find.descendant(of: player, matching: find.text('Normal'))),
      isSemantics(label: 'Speech rate: Normal'),
    );
    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.4×').last);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).speechRate, 0.65);
    expect(tts.spoken.length, said + 1);
    expect(find.descendant(of: player, matching: find.text('1.4×')), findsOneWidget);
  });

  testWidgets("the haftarah's verses are highlighted as they are read, and the voice goes with the page",
      (tester) async {
    final tts = HeldTts();
    final c = await open(
      tester,
      '/today/haftarah/5787:1',
      tts,
      settings: AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4)),
      now: DateTime(2026, 10, 9, 10),
    );
    await tester.tap(find.byTooltip('Listen'));
    await tester.pumpAndSettle();
    expect(player, findsOneWidget);
    expect(marked(tester), [0]);
    tts.finish();
    await tester.pumpAndSettle();
    expect(marked(tester), [1]);
    await tester.tap(inPlayer('Next verse'));
    await tester.pumpAndSettle();
    expect(marked(tester), [2]);
    await tester.tap(inPlayer('Previous verse'));
    await tester.pumpAndSettle();
    expect(marked(tester), [1]);

    c.read(routerProvider).go('/today');
    await tester.pumpAndSettle();
    expect(find.byType(HaftarahScreen), findsNothing);
    expect(tts.currentIndex.value, isNull, reason: 'leaving the page stops the voice');
    expect(tester.takeException(), isNull);
  });

  group('on the haftarah\'s page', () {
    Future<ProviderContainer> openHaftarah(WidgetTester tester, TtsService tts,
            {AppSettings settings = const AppSettings(onboardingComplete: true)}) =>
        open(tester, '/haftarah/5787:1', tts,
            settings: settings.copyWith(joinDate: LocalDate(2026, 10, 4)), now: DateTime(2026, 10, 9, 10));

    testWidgets('Listen starts at the first verse in view', (tester) async {
      final tts = HeldTts();
      await openHaftarah(tester, tts);
      // Scrolled so that the fifth verse is the first in view.
      unawaited(Scrollable.ensureVisible(tester.element(find.byType(SpeakingVerseMark).at(4))));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Listen'));
      await tester.pumpAndSettle();
      expect(marked(tester), [4]);
    });

    testWidgets('the keys play, pause and move verse by verse, as the reader\'s do', (tester) async {
      final tts = HeldTts();
      await openHaftarah(tester, tts);
      await press(tester, LogicalKeyboardKey.keyL);
      expect(player, findsOneWidget);
      expect(marked(tester), [0]);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(marked(tester), [2]);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(marked(tester), [1]);

      await press(tester, LogicalKeyboardKey.keyL);
      expect(inPlayer('Resume'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.keyL);
      expect(inPlayer('Pause'), findsOneWidget);
      expect(marked(tester), [1]);
    });

    testWidgets('on the web, L alone plays and pauses, where single keys are on', (tester) async {
      ReaderScreen.singleKeyPlatform = true;
      addTearDown(() => ReaderScreen.singleKeyPlatform = false);
      final tts = HeldTts();
      await openHaftarah(tester, tts, settings: const AppSettings(onboardingComplete: true, singleKeyShortcuts: true));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pumpAndSettle();
      expect(player, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pumpAndSettle();
      expect(inPlayer('Resume'), findsOneWidget);
    });
  });

  testWidgets('the rate the Settings slider stepped back to is marked, and choosing it starts nothing again',
      (tester) async {
    final tts = HeldTts();
    // 10% and seven steps of 5%, as the slider sets it.
    const stepped = 0.1 + 7 * 0.05;
    expect(stepped, isNot(0.45));
    final c = await open(tester, '/read/5787:2/0?mode=full', tts,
        settings: const AppSettings(onboardingComplete: true, speechRate: stepped));
    await tester.tap(find.byTooltip('Listen'));
    await tester.pumpAndSettle();
    final said = tts.spoken.length;
    await tester.tap(find.descendant(of: player, matching: find.text('Normal')));
    await tester.pumpAndSettle();
    final checked = find.byIcon(Icons.radio_button_checked);
    expect(checked, findsOneWidget);
    expect(find.descendant(of: find.ancestor(of: checked, matching: find.byType(Row)).first, matching: find.text('Normal')),
        findsOneWidget);
    expect(find.text('Normal'), findsNWidgets(2), reason: 'the menu has no second Normal');

    await tester.tap(find.text('Normal').last);
    await tester.pumpAndSettle();
    expect(tts.spoken.length, said, reason: 'the verse being read goes on');
    expect(c.read(settingsProvider).speechRate, stepped);
  });

  test('the player offers the rate set, among its own', () {
    expect(speechRatesWith(0.45), kSpeechRates);
    expect(speechRatesWith(0.1 + 7 * 0.05), kSpeechRates);
    expect(sameSpeechRate(0.1 + 7 * 0.05, 0.45), isTrue);
    expect(sameSpeechRate(0.5, 0.45), isFalse);
    expect(speechRatesWith(0.5), [0.25, 0.35, 0.45, 0.5, 0.55, 0.65, 0.8, 1.0]);
  });

  test('a rate is shown relative to the default, normal', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect([for (final r in kSpeechRates) speechRateLabel(en, r)], ['0.6×', '0.8×', 'Normal', '1.2×', '1.4×', '1.8×', '2.2×']);
    // As the Settings slider steps to it.
    expect(speechRateLabel(en, 0.1 + 7 * 0.05), 'Normal');
    expect(speechRateLabel(en, 0.1), '0.2×');
    expect(speechRateLabel(en, 0.9), '2.0×');

    // In Hebrew, the multiple keeps its sign after it, as a left-to-right run.
    final he = lookupAppLocalizations(const Locale('he'));
    expect(speechRateLabel(he, kDefaultSpeechRate), 'רגיל');
    expect(speechRateLabel(he, 0.55), '\u20661.2×\u2069');
    expect(he.speechRateValue(speechRateLabel(he, kDefaultSpeechRate)), 'קצב הקראה: רגיל');
  });

  test("a queue's verses: where one starts, or the next after it", () {
    final queue = SpeechQueue(language: 'he-IL')
      ..add(0, 'mikra 1')
      ..add(0, 'targum 1')
      ..add(1, '  ')
      ..add(2, 'mikra 3');
    expect(queue.items, ['mikra 1', 'targum 1', 'mikra 3']);
    expect(queue.verses, [0, 0, 2]);
    expect(queue.startOf(0), 0);
    expect(queue.startOf(1), 2, reason: 'a verse with nothing to say starts at the next');
    expect(queue.startOf(5), 2);
  });
}
