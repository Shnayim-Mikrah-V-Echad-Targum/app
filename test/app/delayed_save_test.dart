import 'dart:convert';
import 'dart:ui' show AppExitResponse;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/delayed_save.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';

final _monday = LocalDate(2026, 10, 12);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  AppSettings? savedSettings() => switch (prefs.getString(SettingsController.storageKey)) {
        null => null,
        final raw => AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>),
      };

  ProgressState? savedProgress() => switch (prefs.getString(ProgressController.storageKey)) {
        null => null,
        final raw => ProgressState.fromJson(jsonDecode(raw) as Map<String, dynamic>),
      };

  group('DelayedSave', () {
    test('writes once a change has rested, and only the last of a burst, encoded once', () {
      fakeAsync((async) {
        final save = DelayedSave(prefs, 'key');
        var encoded = 0;
        for (var n = 1; n <= 3; n++) {
          save.save(() {
            encoded++;
            return {'n': n};
          });
          async.elapse(DelayedSave.delay - const Duration(milliseconds: 100));
        }
        expect(prefs.getString('key'), isNull, reason: 'still changing');
        expect(save.isPending, isTrue);

        async.elapse(const Duration(milliseconds: 100));
        expect(prefs.getString('key'), '{"n":3}');
        expect(encoded, 1);
        expect(save.isPending, isFalse);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('flush writes what is waiting at once, and nothing when nothing is', () async {
      final save = DelayedSave(prefs, 'key');
      await save.flush();
      expect(prefs.containsKey('key'), isFalse);

      save.save(() => [1, 2]);
      final flushing = save.flush();
      expect(prefs.getString('key'), '[1,2]', reason: 'in storage as soon as flush returns');
      await flushing;
      expect(save.isPending, isFalse);
    });
  });

  group('the settings and progress controllers', () {
    test('save a moment after a change, and at once when disposed', () {
      fakeAsync((async) {
        final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
        c.read(settingsProvider.notifier).update((s) => s.copyWith(showTranslation: true));
        c.read(progressProvider.notifier).markUnit('5787:2', 0, ReadingPass.mikra1, _monday);
        expect(c.read(settingsProvider).showTranslation, isTrue, reason: 'the state changes at once');
        expect(savedSettings(), isNull);
        expect(savedProgress(), isNull);

        async.elapse(DelayedSave.delay);
        expect(savedSettings()!.showTranslation, isTrue);
        expect(savedProgress()!.week('5787:2').isUnitDone(0, ReadingPass.mikra1), isTrue);

        // A step through the reader, then the app goes away before it rests.
        c.read(progressProvider.notifier).savePosition('5787:2', 0, const [3, 2, 0]);
        c.read(settingsProvider.notifier).update((s) => s.copyWith(readingScale: 1.2));
        c.dispose();
        expect(savedProgress()!.week('5787:2').positions[0], [3, 2, 0]);
        expect(savedSettings()!.readingScale, 1.2);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('the app', () {
    Future<void> lifecycle(WidgetTester tester, AppLifecycleState state) =>
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/lifecycle',
          const StringCodec().encodeMessage(state.toString()),
          (_) {},
        );

    testWidgets('saves what is waiting when it loses focus, is hidden, or is asked to exit', (tester) async {
      final c = await pumpApp(tester);
      addTearDown(() => lifecycle(tester, AppLifecycleState.resumed));
      prefs = c.read(sharedPreferencesProvider);
      final settings = c.read(settingsProvider.notifier);
      final progress = c.read(progressProvider.notifier);

      settings.update((s) => s.copyWith(showTranslation: true));
      expect(savedSettings()!.showTranslation, isFalse, reason: 'still waiting');
      await lifecycle(tester, AppLifecycleState.inactive);
      expect(savedSettings()!.showTranslation, isTrue);

      await lifecycle(tester, AppLifecycleState.resumed);
      progress.markUnit('5787:2', 0, ReadingPass.mikra1, _monday);
      expect(savedProgress(), isNull);
      await lifecycle(tester, AppLifecycleState.inactive);
      await lifecycle(tester, AppLifecycleState.hidden);
      expect(savedProgress()!.week('5787:2').isUnitDone(0, ReadingPass.mikra1), isTrue);

      // Closing the window on a desktop.
      await lifecycle(tester, AppLifecycleState.inactive);
      await lifecycle(tester, AppLifecycleState.resumed);
      progress.savePosition('5787:2', 1, const [4, 0, 0]);
      expect(await tester.binding.handleRequestAppExit(), AppExitResponse.exit);
      expect(savedProgress()!.week('5787:2').positions[1], [4, 0, 0]);
    });
  });
}
