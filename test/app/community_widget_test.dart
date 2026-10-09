import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';

import '../helpers.dart';

void main() {
  testWidgets('demo community: sign in with a code, accept guidelines, reply', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, now: DateTime(2026, 10, 12, 10));

    c.read(routerProvider).go('/community/account');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'reader@example.org');
    await tester.tap(find.text('Email me a code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('reader@example.org'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Signed in as'), findsOneWidget);

    c.read(routerProvider).go('/community/thread/1');
    await tester.pumpAndSettle();
    expect(find.text('Why read the Targum rather than a translation?'), findsWidgets);
    await tester.enterText(find.widgetWithText(TextField, 'Write a reply'), 'Thank you, this helped me.');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reply'));
    await tester.pumpAndSettle();

    // First post: the community guidelines.
    expect(find.text("I'll follow the community guidelines"), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Thank you, this helped me.'), findsOneWidget);
    expect(find.text('3 posts'), findsOneWidget);
  });
}
