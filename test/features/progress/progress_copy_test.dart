import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

/// Progress describes the reading and the streak by the reader's own
/// settings.
void main() {
  Future<ProviderContainer> openProgress(WidgetTester tester, AppSettings settings) async {
    tester.view.physicalSize = const Size(412, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: settings, now: historyNow, progress: historyProgress());
    c.read(routerProvider).go('/progress');
    await tester.pumpAndSettle();
    return c;
  }

  final settings = AppSettings(onboardingComplete: true, joinDate: historyJoinDate);

  testWidgets('a Rashi reader has read the verses twice with Rashi', (tester) async {
    await openProgress(tester, settings.copyWith(secondReading: SecondReading.rashi));
    expect(find.textContaining(RegExp(r'^[\d,]+ verses read twice with Rashi$')), findsOneWidget);
  });

  testWidgets('a reader of Onkelos and Rashi has read the verses twice with both', (tester) async {
    await openProgress(tester, settings.copyWith(secondReading: SecondReading.onkelosAndRashi));
    expect(find.textContaining(RegExp(r'verses read twice with Onkelos and Rashi$')), findsOneWidget);
  });

  testWidgets('the streak counts late portions by the window the reader chose', (tester) async {
    await openProgress(tester, settings);
    expect(find.textContaining('or by Tuesday night, which still counts'), findsOneWidget);
    expect(find.textContaining(RegExp(r'verses read twice with Targum$')), findsOneWidget);
  });

  testWidgets('a Wednesday window is the end of Wednesday', (tester) async {
    await openProgress(tester, settings.copyWith(lateWindow: LateWindow.wednesday));
    expect(find.textContaining('or by the end of Wednesday, which still counts'), findsOneWidget);
    expect(find.textContaining('by Tuesday night'), findsNothing);
  });

  testWidgets('with no window, only portions finished before Shabbat count', (tester) async {
    await openProgress(tester, settings.copyWith(lateWindow: LateWindow.none));
    expect(find.text('Your parsha streak counts portions finished before Shabbat. Shabbat and Yom Tov never break a streak.'),
        findsOneWidget);
    expect(find.textContaining('which still counts'), findsNothing);
  });
}
