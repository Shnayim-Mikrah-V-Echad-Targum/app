import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/about/guide_screen.dart';
import 'package:shnayim_mikra/features/about/legal_screen.dart';
import 'package:shnayim_mikra/features/about/sources_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';

void main() {
  testWidgets('first launch shows onboarding', (tester) async {
    await pumpApp(tester, settings: const AppSettings());
    await tester.pumpAndSettle();
    expect(find.text("Start this week's parsha"), findsOneWidget);
  });

  testWidgets('the policies, sources and guide open before onboarding', (tester) async {
    final c = await pumpApp(tester, settings: const AppSettings());
    final router = c.read(routerProvider);
    await tester.pumpAndSettle();

    router.go('/legal/privacy');
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget);
    // Home is the welcome, until onboarding is done.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text("Start this week's parsha"), findsOneWidget);

    router.go('/sources');
    await tester.pumpAndSettle();
    expect(find.byType(SourcesScreen), findsOneWidget);
    router.go('/guide');
    await tester.pumpAndSettle();
    expect(find.byType(GuideScreen), findsOneWidget);

    router.go('/progress');
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
