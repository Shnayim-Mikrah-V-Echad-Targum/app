import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/widgets/sefer_tag.dart';

import '../../helpers.dart';

/// The account card of a moderator at the largest text sizes, in the bundled
/// fonts (DESIGN_SYSTEM.md §6.20, §9 Account): its Moderator tag shares the
/// row with the 56 px initial and the edit button, and keeps its words whole.
void main() {
  setUpAll(loadBundledFonts);

  for (final (scale, width) in [(3.0, 320.0), (2.0, 360.0)]) {
    for (final hebrew in [false, true]) {
      testWidgets('${hebrew ? 'he' : 'en'}: at ${(scale * 100).round()}% on a ${width.round()} dp phone, '
          'the moderator\'s tag keeps its words whole, its shield by its first line', (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final forums = DemoForumRepository();
        await forums.verifyCode('rivka@example.org', '123456');
        await forums.updateDisplayName('Rivka Levi');
        final c = await pumpApp(
          tester,
          forums: forums,
          settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.english),
        );
        c.read(routerProvider).go('/community/account');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'nothing overflows');

        final label = hebrew ? 'צוות ניהול' : 'Moderator';
        final tag = find.byType(SeferTag);
        expect(find.descendant(of: tag, matching: find.text(label)), findsOneWidget);
        expectWordsWhole(tester, label);
        // Within the card, between the initial and the edit button.
        final card = tester.getRect(find.ancestor(of: tag, matching: find.byType(Card)).first);
        expect(card.contains(tester.getTopLeft(tag)) && card.contains(tester.getBottomRight(tag)), isTrue);

        // The shield is level with the word's first line.
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: find.text(label), matching: find.byType(RichText)).first,
        );
        final first = paragraph.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 1)).first;
        final lineCentre = paragraph.localToGlobal(Offset(0, (first.top + first.bottom) / 2)).dy;
        final shield = tester.getCenter(find.descendant(of: tag, matching: find.byIcon(Icons.shield_outlined))).dy;
        expect(shield, moreOrLessEquals(lineCentre, epsilon: 1.5));
      });
    }
  }
}
