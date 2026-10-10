import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

void main() {
  Future<void> openGuide(WidgetTester tester, AppLanguage language) async {
    tester.view.physicalSize = const Size(412, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: AppSettings(onboardingComplete: true, language: language));
    c.read(routerProvider).go('/guide');
    await tester.pumpAndSettle();
  }

  testWidgets('How it works gives every time to finish, and the special cases', (tester) async {
    await openGuide(tester, AppLanguage.english);
    expect(find.widgetWithText(AppBar, 'How it works'), findsOneWidget);
    // Before the meal, then until Mincha, then through Tuesday night, then
    // until Simchat Torah.
    final when = find.textContaining('Ideally finish before the Shabbat-day meal; if not, after the meal until Mincha.');
    expect(when, findsOneWidget);
    expect(find.textContaining('until Simchat Torah (SA 285:4; MB 285:12).'), findsOneWidget);
    expect(find.textContaining('may read Rashi in a language they understand (MB 285:5; Rav Moshe Feinstein)'), findsOneWidget);
    expect(find.textContaining("along with the ba'al koreh, word for word, counts as one of the readings (MB 285:14)"),
        findsOneWidget);
    expect(find.textContaining('do so as a voluntary mitzvah.'), findsOneWidget);
  });

  testWidgets('in Hebrew, איך זה עובד gives the same times and sources', (tester) async {
    await openGuide(tester, AppLanguage.hebrew);
    expect(find.widgetWithText(AppBar, 'איך זה עובד'), findsOneWidget);
    expect(find.textContaining('אחרי הסעודה עד מנחה'), findsOneWidget);
    expect(find.textContaining('(מ״ב רפה, ה; הרב משה פיינשטיין)'), findsOneWidget);
    expect(find.textContaining('(מ״ב רפה, יד)'), findsOneWidget);
  });
}
