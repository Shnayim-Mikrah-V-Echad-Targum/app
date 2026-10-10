import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

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

  for (final reduceMotion in [false, true]) {
    testWidgets('new discussion: the forum picker opens at once and picks, reduceMotion $reduceMotion',
        (tester) async {
      final c = await openRoute(
        tester,
        '/community',
        settings: AppSettings(onboardingComplete: true, reduceMotion: reduceMotion),
        now: DateTime(2026, 10, 12, 10),
      );
      c.read(routerProvider).go('/community/new?forum=questions');
      await tester.pumpAndSettle();
      final picker = find.byType(DropdownMenu<int>);
      expect(find.descendant(of: picker, matching: find.text('Questions & answers')), findsOneWidget);

      // No fade or reveal: the menu is all there, in place, on the first frame.
      await tester.tap(picker);
      await tester.pump();
      final entry = find.widgetWithText(MenuItemButton, 'Divrei Torah');
      expect(entry, findsOneWidget);
      final fades = tester.widgetList<FadeTransition>(find.ancestor(of: entry, matching: find.byType(FadeTransition)));
      expect(fades.map((f) => f.opacity.value), everyElement(1));
      final rect = tester.getRect(entry);
      await tester.pumpAndSettle();
      expect(tester.getRect(entry), rect);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.descendant(of: picker, matching: find.text('Divrei Torah')), findsOneWidget);
      expect(find.byType(MenuItemButton), findsNothing);
    });
  }

  testWidgets('new discussion: the forum picker opens from the keyboard', (tester) async {
    final c = await openRoute(tester, '/community', now: DateTime(2026, 10, 12, 10));
    c.read(routerProvider).go('/community/new?forum=questions');
    await tester.pumpAndSettle();
    final field = find.descendant(of: find.byType(DropdownMenu<int>), matching: find.byType(EditableText));
    // Focusable, but read-only: it picks from the list, never takes typing.
    expect(tester.widget<EditableText>(field).readOnly, isTrue);
    tester.widget<EditableText>(field).focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.widgetWithText(MenuItemButton, 'Divrei Torah'), findsOneWidget);
  });
}
