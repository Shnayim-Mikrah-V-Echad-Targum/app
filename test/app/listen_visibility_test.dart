import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/features/reader/haftarah_screen.dart';
import 'package:shnayim_mikrah/features/reader/listen_along.dart';
import 'package:shnayim_mikrah/features/reader/listen_bar.dart';
import 'package:shnayim_mikrah/features/reader/reader_screen.dart';
import 'package:shnayim_mikrah/features/reader/scripture_text.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/services/tts.dart';

import '../helpers.dart';

/// Speech whose answer to whether there is a Hebrew voice waits for the test
/// ([voice]), as the browser's does while it loads its voices, or an engine
/// still binding.
class _VoiceHeldTts extends HeldTts {
  final voice = Completer<bool?>();

  @override
  Future<bool?> hasHebrewVoice() => voice.future;
}

/// Listen goes with its page: it stops as another page covers the page or
/// its tab is left, and only its own speech; and it pauses as the app is
/// hidden, or as a call or another app's audio takes over (DESIGN.md §3).
void main() {
  // Friday of Bereshit 5787.
  final friday = DateTime(2026, 10, 9, 10);
  final joined = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4));

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
    AppSettings? settings,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: settings ?? joined,
      now: friday,
      overrides: [ttsProvider.overrideWithValue(tts)],
    );
    c.read(routerProvider).go(path);
    await loadTexts(tester);
    return c;
  }

  final player = find.byType(ListenBar);
  Finder inPlayer(String tooltip) => find.descendant(of: player, matching: find.byTooltip(tooltip));
  Finder tab(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  // Whether a queue is being spoken, not paused.
  bool speaking(TtsService tts) => tts.currentIndex.value != null && !tts.paused.value;

  // The verses of the full text that are highlighted, by index.
  List<int> highlighted(WidgetTester tester) => [
        for (final (i, group) in tester.widgetList<VerseGroup>(find.byType(VerseGroup)).indexed)
          if (group.highlighted) i,
      ];

  group('stopping a Listen stops only its own speech', () {
    test("another page's Listen, which has taken the voice over, goes on", () async {
      final tts = HeldTts();
      final haftarah = ListenController(tts);
      final reader = ListenController(tts);
      final never = ListenController(tts);
      SpeechQueue queue(String name) => SpeechQueue(language: 'he-IL')
        ..add(0, '$name 1')
        ..add(1, '$name 2');

      final readerEnd = reader.play(queue('reader'), rate: kDefaultSpeechRate);
      await pumpEventQueue();
      final haftarahEnd = haftarah.play(queue('haftarah'), rate: kDefaultSpeechRate);
      await pumpEventQueue();
      expect(await readerEnd, ListenEnd.stopped);
      expect(reader.active, isFalse);

      await reader.stop();
      await never.stop();
      await pumpEventQueue();
      expect(haftarah.active, isTrue);
      expect(speaking(tts), isTrue);
      expect(tts.spoken.last.$1, 'haftarah 1');

      await haftarah.stop();
      expect(await haftarahEnd, ListenEnd.stopped);
      expect(tts.currentIndex.value, isNull);
    });

    testWidgets("a reader opened and closed at once, never listening, leaves the haftarah's Listen", (tester) async {
      final tts = HeldTts();
      final c = await open(tester, '/today/haftarah/5787:1', tts);
      await tester.tap(find.byTooltip('Listen'));
      await tester.pumpAndSettle();
      expect(speaking(tts), isTrue);

      // Back before it has come over the haftarah, which it never covers.
      final router = c.read(routerProvider);
      router.push('/read/5787:1/0');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ReaderScreen), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      expect(find.byType(ReaderScreen), findsNothing);
      expect(speaking(tts), isTrue);
      expect(player, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Listen stops while its page is out of sight', () {
    testWidgets("on the haftarah's page, as another tab is chosen", (tester) async {
      final tts = HeldTts();
      await open(tester, '/parsha/haftarah/5787:1', tts);
      await tester.tap(find.byTooltip('Listen'));
      await tester.pumpAndSettle();
      expect(speaking(tts), isTrue);

      await tester.tap(tab('Progress'));
      await tester.pumpAndSettle();
      expect(tts.currentIndex.value, isNull, reason: 'the voice stops with the tab');

      await tester.tap(tab('Parsha'));
      await tester.pumpAndSettle();
      expect(find.byType(HaftarahScreen), findsOneWidget);
      expect(player, findsNothing);
      expect(find.byTooltip('Listen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in the reader, as a question on a verse opens over it', (tester) async {
      final tts = HeldTts();
      final c = await open(tester, '/read/5787:1/0?mode=full', tts);
      await tester.tap(find.byTooltip('Listen'));
      await tester.pumpAndSettle();
      expect(speaking(tts), isTrue);

      final router = c.read(routerProvider);
      router.push('/ask?verse=Genesis%201:1');
      await tester.pump();
      expect(tts.currentIndex.value, isNull, reason: 'stopped as the page begins to cover the reader');
      await tester.pumpAndSettle();

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(player, findsNothing);
      expect(highlighted(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });

    // The haftarah's page in a tab is covered in the root navigator, whose
    // route animations it never sees: its Listen stops as the tabs' page goes
    // offstage under the opaque page, which turns its tickers off.
    for (final path in ['/search', '/read/5787:1/0']) {
      testWidgets("on the haftarah's page in a tab, as $path opens over the tabs", (tester) async {
        final tts = HeldTts();
        final c = await open(tester, '/today/haftarah/5787:1', tts);
        await tester.tap(find.byTooltip('Listen'));
        await tester.pumpAndSettle();
        expect(speaking(tts), isTrue);

        final router = c.read(routerProvider);
        router.push(path);
        await loadTexts(tester);
        expect(tts.currentIndex.value, isNull, reason: 'the voice stops under the page');

        router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(HaftarahScreen), findsOneWidget);
        expect(player, findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('but not while a sheet is over the reader', (tester) async {
      final tts = HeldTts();
      await open(tester, '/read/5787:1/0?mode=full', tts);
      await tester.tap(find.byTooltip('Listen'));
      await tester.pumpAndSettle();
      final said = tts.spoken.length;

      await tester.tap(find.byTooltip('Display settings'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(speaking(tts), isTrue);
      expect(tts.spoken.length, said, reason: 'the verse goes on');

      Navigator.pop(tester.element(find.byType(BottomSheet)));
      await tester.pumpAndSettle();
      expect(player, findsOneWidget);
      expect(speaking(tts), isTrue);
    });
  });

  group('Listen pauses', () {
    Future<void> lifecycle(WidgetTester tester, AppLifecycleState state) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/lifecycle',
        const StringCodec().encodeMessage(state.toString()),
        (_) {},
      );
      await tester.pump();
    }

    Future<void> hide(WidgetTester tester) async {
      addTearDown(() => tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter/lifecycle',
            const StringCodec().encodeMessage(AppLifecycleState.resumed.toString()),
            (_) {},
          ));
      await lifecycle(tester, AppLifecycleState.inactive);
      await lifecycle(tester, AppLifecycleState.hidden);
    }

    Future<void> show(WidgetTester tester) async {
      await lifecycle(tester, AppLifecycleState.inactive);
      await lifecycle(tester, AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    // A call comes, as the platform tells it.
    Future<void> focusLost(WidgetTester tester) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        TtsService.audioSessionChannel.name,
        TtsService.audioSessionChannel.codec.encodeMethodCall(const MethodCall('focusLost')),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    for (final (cause, interrupt, resume) in [
      ('as the app is hidden', hide, show),
      ('as a call comes', focusLost, (WidgetTester _) async {}),
    ]) {
      group(cause, () {
        testWidgets('in the reader, at its verse, and goes on from the start of it', (tester) async {
          final tts = HeldTts();
          await open(tester, '/read/5787:1/0?mode=full', tts);
          await tester.tap(find.byTooltip('Listen'));
          await tester.pumpAndSettle();
          // Into the second verse, and its Targum.
          for (var i = 0; i < 3; i++) {
            tts.finish();
            await tester.pumpAndSettle();
          }
          expect(highlighted(tester), [1]);
          final said = tts.spoken.length;

          await interrupt(tester);
          expect(tts.paused.value, isTrue);
          await resume(tester);
          expect(inPlayer('Resume'), findsOneWidget);
          expect(highlighted(tester), [1], reason: 'the verse it paused at stays marked');

          await tester.tap(inPlayer('Resume'));
          await tester.pumpAndSettle();
          expect(speaking(tts), isTrue);
          expect(tts.spoken.length, said + 1);
          expect(tts.spoken.last, tts.spoken[said - 1]);
        });

        testWidgets("in Listen along's breath between readings, and waits there", (tester) async {
          final tts = RecordingTts();
          await open(tester, '/read/5787:1/0', tts,
              settings: joined.copyWith(method: ReadingMethod.aliyahByAliyah, listenAlong: true));
          await tester.tap(find.byTooltip('Listen'));
          await tester.pump();
          await tester.pump();

          await interrupt(tester);
          await resume(tester);
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

        testWidgets("on the haftarah's page", (tester) async {
          final tts = HeldTts();
          await open(tester, '/haftarah/5787:1', tts);
          await tester.tap(find.byTooltip('Listen'));
          await tester.pumpAndSettle();
          tts.finish();
          await tester.pumpAndSettle();
          final said = tts.spoken.length;

          await interrupt(tester);
          expect(tts.paused.value, isTrue);
          await resume(tester);
          expect(inPlayer('Resume'), findsOneWidget);

          await tester.tap(inPlayer('Resume'));
          await tester.pumpAndSettle();
          expect(tts.spoken.last, tts.spoken[said - 1], reason: 'the same verse, from its start');
        });
      });
    }

    // The browser can take a moment to load its voices, an engine to bind.
    group('a Listen still looking for its voice starts nothing', () {
      testWidgets('in the reader, as the app is hidden meanwhile', (tester) async {
        final tts = _VoiceHeldTts();
        await open(tester, '/read/5787:1/0?mode=full', tts);
        await tester.tap(find.byTooltip('Listen'));
        await tester.pump();
        await hide(tester);
        tts.voice.complete(true);
        await tester.pump();
        expect(tts.spoken, isEmpty);
        expect(tts.currentIndex.value, isNull);

        await show(tester);
        expect(player, findsNothing);
        expect(find.byTooltip('Listen'), findsOneWidget);
      });

      testWidgets("on the haftarah's page, as another tab is chosen meanwhile", (tester) async {
        final tts = _VoiceHeldTts();
        await open(tester, '/parsha/haftarah/5787:1', tts);
        await tester.tap(find.byTooltip('Listen'));
        await tester.pump();
        await tester.tap(tab('Progress'));
        await tester.pumpAndSettle();
        tts.voice.complete(true);
        await tester.pumpAndSettle();
        expect(tts.spoken, isEmpty);
        expect(tts.currentIndex.value, isNull);

        await tester.tap(tab('Parsha'));
        await tester.pumpAndSettle();
        expect(find.byType(HaftarahScreen), findsOneWidget);
        expect(player, findsNothing);
      });

      testWidgets("on the haftarah's page, as the app is hidden meanwhile", (tester) async {
        final tts = _VoiceHeldTts();
        await open(tester, '/haftarah/5787:1', tts);
        await tester.tap(find.byTooltip('Listen'));
        await tester.pump();
        await hide(tester);
        tts.voice.complete(true);
        await tester.pump();
        expect(tts.spoken, isEmpty);
        await show(tester);
        expect(player, findsNothing);
      });
    });

    testWidgets('a call while Listen is off, or paused, leaves it so', (tester) async {
      final tts = HeldTts();
      await open(tester, '/read/5787:1/0?mode=full', tts);
      await focusLost(tester);
      expect(player, findsNothing);

      await tester.tap(find.byTooltip('Listen'));
      await tester.pumpAndSettle();
      await tester.tap(inPlayer('Pause'));
      await tester.pumpAndSettle();
      await focusLost(tester);
      expect(inPlayer('Resume'), findsOneWidget, reason: 'still paused, not played');
      expect(tts.paused.value, isTrue);
    });
  });
}
