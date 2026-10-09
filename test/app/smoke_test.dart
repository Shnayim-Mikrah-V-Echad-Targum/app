import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';

void main() {
  testWidgets('first launch shows onboarding', (tester) async {
    await pumpApp(tester, settings: const AppSettings());
    await tester.pumpAndSettle();
    expect(find.text("Start this week's parsha"), findsOneWidget);
  });

  testWidgets('today screen renders', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    // The default test window is tablet-sized, so navigation is a rail.
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Parshat Bereshit').evaluate().isNotEmpty || find.textContaining('Parshat').evaluate().isNotEmpty, isTrue);
  });
}
