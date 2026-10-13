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
import 'package:shnayim_mikra/ui/theme/motion.dart';

import '../../helpers.dart';

// The guided reader's haptics (DESIGN_SYSTEM.md §8, Haptics): a step's tick
// for each Next, and the finish's haptic alone for the press that finishes
// the aliyah; for the parsha, the celebrate haptic, once, as its rings close.
// In the week of Bereshit 5787, on its Monday.

const _step = 'HapticFeedbackType.selectionClick';

/// HapticFeedback.vibrate(), Android's celebrate haptic.
const _celebrate = 'vibrate';

/// Bereshit with every aliyah read but Shevi'i, whose Hebrew is read twice:
/// its Targum finishes the week (with no repeat of its last verse after it).
ProgressState _allButShevii() {
  var week = WeekProgress(weekId: '5787:1');
  for (var a = 0; a < 6; a++) {
    week = week.withAliyah(a, LocalDate(2026, 10, 5));
  }
  final on = LocalDate(2026, 10, 5);
  week = week
      .withUnit(6, ReadingPass.mikra1, on)
      .withUnit(6, ReadingPass.mikra2, on)
      .withPosition(6, const [99, 99, 0]);
  return ProgressState(weeks: {'5787:1': week});
}

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
/// Targum), with [progress] and [settings]; in the full text if [full].
Future<ProviderContainer> _open(
  WidgetTester tester, {
  int aliyah = 0,
  bool full = false,
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
  c.read(routerProvider).go('/read/5787:1/$aliyah${full ? '?mode=full' : ''}');
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

  testWidgets(
    'the press that finishes the parsha gives the celebrate haptic alone, as the rings close, and once',
    (tester) async {
      final celebrate = switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'HapticFeedbackType.successNotification',
        _ => _celebrate,
      };
      final c = await _open(
        tester,
        aliyah: 6,
        progress: _allButShevii(),
        settings: const AppSettings().withRepeatLastVerse(false),
      );
      final sent = _recordHaptics(tester);

      await tester.tap(find.text('Finish'));
      await tester.pump();
      expect(c.read(progressProvider).week('5787:1').isComplete, isTrue);
      expect(sent, isEmpty, reason: 'neither a step nor a success at the press');
      await tester.pump(Motion.ring - const Duration(milliseconds: 20));
      expect(sent, isEmpty, reason: 'the rings are still closing');
      await tester.pump(const Duration(milliseconds: 40));
      expect(sent, [celebrate]);
      await tester.pumpAndSettle();
      expect(sent, [celebrate]);

      // Back to the Targum (Alt+↑, as the panel has no Back), and finished
      // again: an aliyah's success.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(find.text('Finish'), findsOneWidget);
      sent.clear();
      await _press(tester, 'Finish');
      expect(find.text('Parshat Bereshit is complete'), findsOneWidget);
      expect(sent, [
        if (defaultTargetPlatform == TargetPlatform.iOS) 'HapticFeedbackType.mediumImpact' else 'HapticFeedbackType.lightImpact',
      ]);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
  );

  testWidgets('under Reduce Motion, the celebrate haptic comes at once', (tester) async {
    await _open(
      tester,
      aliyah: 6,
      progress: _allButShevii(),
      settings: const AppSettings(reduceMotion: true).withRepeatLastVerse(false),
    );
    final sent = _recordHaptics(tester);

    await tester.tap(find.text('Finish'));
    await tester.pump();
    expect(sent, [_celebrate]);
    await tester.pumpAndSettle();
    expect(sent, [_celebrate]);
  });

  testWidgets('Mark as read that finishes the parsha celebrates once: at the press in the full text', (tester) async {
    await _open(
      tester,
      aliyah: 6,
      full: true,
      progress: _allButShevii(),
      settings: const AppSettings().withRepeatLastVerse(false),
    );
    final sent = _recordHaptics(tester);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    // The menu's, over the button at the aliyah's end.
    await tester.tap(find.text('Mark this aliyah as read').last);
    await tester.pump();
    expect(sent, [_celebrate], reason: 'no finished panel shows it');
    await tester.pumpAndSettle();
    expect(sent, [_celebrate]);
  });

  testWidgets('Mark as read that finishes the parsha celebrates once: as the panel’s rings close in the guided reader',
      (tester) async {
    await _open(
      tester,
      aliyah: 6,
      progress: _allButShevii(),
      settings: const AppSettings().withRepeatLastVerse(false),
    );
    final sent = _recordHaptics(tester);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark this aliyah as read'));
    await tester.pump();
    expect(sent, isEmpty);
    await tester.pumpAndSettle();
    expect(find.text('Parshat Bereshit is complete'), findsOneWidget);
    expect(sent, [_celebrate]);
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
