import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/services/tts.dart';

import '../../helpers.dart';

// The guided reader's haptics (DESIGN_SYSTEM.md §8, Haptics): a step's tick
// for each Next, and the finish's haptic alone for the press that finishes
// the aliyah. In the week of Bereshit 5787, on its Monday.

const _step = 'HapticFeedbackType.selectionClick';

/// The haptics sent to the platform from now on, each by its type as
/// HapticFeedback sends it ('vibrate' for HapticFeedback.vibrate()).
List<String> _recordHaptics(WidgetTester tester) {
  final sent = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') sent.add(call.arguments as String? ?? 'vibrate');
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return sent;
}

/// Opens aliyah [aliyah] of Bereshit, read aliyah by aliyah (Mikra, Mikra,
/// Targum), with [progress] and [settings].
Future<ProviderContainer> _open(
  WidgetTester tester, {
  int aliyah = 0,
  ProgressState? progress,
  AppSettings settings = const AppSettings(),
  TtsService? tts,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(
    tester,
    settings: settings.copyWith(
      onboardingComplete: true,
      notificationPromptShown: true,
      joinDate: LocalDate(2026, 10, 4),
      method: ReadingMethod.aliyahByAliyah,
    ),
    now: DateTime(2026, 10, 5, 10),
    progress: progress,
    overrides: [if (tts != null) ttsProvider.overrideWithValue(tts)],
  );
  c.read(routerProvider).go('/read/5787:1/$aliyah');
  await tester.pump();
  await tester.pump();
  for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
  return c;
}

Future<void> _press(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Next ticks, and the press that finishes the aliyah gives one success alone',
    (tester) async {
      final success = switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'HapticFeedbackType.mediumImpact',
        _ => 'HapticFeedbackType.lightImpact',
      };
      await _open(tester);
      final sent = _recordHaptics(tester);

      await _press(tester, 'Next');
      expect(sent, [_step], reason: 'Mikra to Mikra again');
      await _press(tester, 'Next');
      expect(sent, [_step, _step], reason: 'on to the Targum');

      sent.clear();
      await _press(tester, 'Finish');
      expect(find.text('Rishon is complete'), findsOneWidget);
      expect(sent, [success], reason: 'no step tick before it');
    },
    variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
  );

  testWidgets('the press that finishes the parsha gives one haptic, and no step tick', (tester) async {
    // Every aliyah read but Shevi'i, whose Hebrew is read twice: its Targum
    // finishes the week (with no repeat of its last verse after it).
    var week = WeekProgress(weekId: '5787:1');
    for (var a = 0; a < 6; a++) {
      week = week.withAliyah(a, LocalDate(2026, 10, 5));
    }
    final on = LocalDate(2026, 10, 5);
    week = week
        .withUnit(6, ReadingPass.mikra1, on)
        .withUnit(6, ReadingPass.mikra2, on)
        .withPosition(6, const [99, 99, 0]);
    final c = await _open(
      tester,
      aliyah: 6,
      progress: ProgressState(weeks: {'5787:1': week}),
      settings: const AppSettings().withRepeatLastVerse(false),
    );
    final sent = _recordHaptics(tester);

    await _press(tester, 'Finish');
    expect(c.read(progressProvider).week('5787:1').isComplete, isTrue);
    expect(sent, hasLength(1));
    expect(sent, isNot(contains(_step)));
  });

  testWidgets('Listen along going on by itself gives none; the reader’s Finish does', (tester) async {
    final tts = RecordingTts();
    await _open(tester, settings: const AppSettings(listenAlong: true), tts: tts);
    final sent = _recordHaptics(tester);

    await tester.tap(find.byTooltip('Listen'));
    // Mikra, Mikra again and the Targum, each after its breath.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Read the Targum'), findsOneWidget);
    expect(tts.spoken, isNotEmpty);
    expect(sent, isEmpty);

    await _press(tester, 'Finish');
    expect(sent, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('with Haptic feedback off, nothing is sent', (tester) async {
    await _open(tester, settings: const AppSettings(haptics: false));
    final sent = _recordHaptics(tester);

    await _press(tester, 'Next');
    await _press(tester, 'Next');
    await _press(tester, 'Finish');
    expect(find.text('Rishon is complete'), findsOneWidget);
    expect(sent, isEmpty);
  });

  testWidgets(
    'on a desktop, nothing is sent',
    (tester) async {
      await _open(tester);
      final sent = _recordHaptics(tester);

      await _press(tester, 'Next');
      await _press(tester, 'Next');
      await _press(tester, 'Finish');
      expect(find.text('Rishon is complete'), findsOneWidget);
      expect(sent, isEmpty);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}),
  );
}
