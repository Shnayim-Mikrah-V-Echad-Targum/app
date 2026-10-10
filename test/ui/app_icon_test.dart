import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/widgets/app_icon.dart';

import '../helpers.dart';

/// Whether [icon] is drawn flipped, as Material mirrors an icon in
/// right-to-left text.
bool _mirrored(WidgetTester tester, Finder icon) =>
    find.descendant(of: icon, matching: find.byType(Transform)).evaluate().isNotEmpty;

void main() {
  Future<void> pumpRtl(WidgetTester tester, Widget child) => tester.pumpWidget(
        Directionality(textDirection: TextDirection.rtl, child: Row(children: [child])),
      );

  testWidgets('the help icon keeps its question mark the right way round in right-to-left text', (tester) async {
    await pumpRtl(tester, const Icon(Icons.help_outline));
    expect(_mirrored(tester, find.byType(Icon)), isTrue, reason: 'as Material draws it, for Arabic');

    await pumpRtl(tester, const AppIcon(Icons.help_outline));
    expect(_mirrored(tester, find.byType(AppIcon)), isFalse, reason: 'Hebrew writes "?" as English does');
  });

  testWidgets('other icons still follow the direction of the text', (tester) async {
    await pumpRtl(tester, const AppIcon(Icons.chevron_right));
    expect(_mirrored(tester, find.byType(AppIcon)), isTrue);
    await pumpRtl(tester, const AppIcon(Icons.info_outline));
    expect(_mirrored(tester, find.byType(AppIcon)), isFalse);
  });

  testWidgets('in the Hebrew interface, no help icon is mirrored', (tester) async {
    // Tall enough to build the help row at the end of Settings.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew));
    for (final page in ['/today', '/settings', '/settings/about', '/community']) {
      c.read(routerProvider).go(page);
      await tester.pumpAndSettle();
      final help = find.byIcon(Icons.help_outline);
      expect(help, findsWidgets, reason: page);
      for (final icon in help.evaluate()) {
        expect(_mirrored(tester, find.byWidget(icon.widget)), isFalse, reason: page);
      }
    }
  });
}
