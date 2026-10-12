import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

/// A week's status on Progress, in the bundled fonts: it wraps at the
/// reader's own text size, never set smaller to keep two words together,
/// and its lines are balanced, so that no word is left alone on the last
/// ("הושלם / מאוחר יותר", not "הושלם מאוחר / יותר"). The Torah map's
/// legend balances its names the same way.
void main() {
  setUpAll(loadBundledFonts);

  /// The top of each word of [label], set in [paragraph].
  List<double> wordTops(RenderParagraph paragraph, String label) {
    final words = label.split(' ');
    final tops = <double>[];
    for (var i = 0, start = 0; i < words.length; start += words[i].length + 1, i++) {
      final selection = TextSelection(baseOffset: start, extentOffset: start + words[i].length);
      tops.add(paragraph.getBoxesForSelection(selection).first.top);
    }
    return tops;
  }

  for (final (hebrew, label) in [(false, 'Made up later'), (true, 'הושלם מאוחר יותר')]) {
    for (final scale in [2.0, 3.0]) {
      testWidgets(
          'at ${(scale * 100).round()}% text, a week’s status wraps at its own size, no word alone on its last line'
          '${hebrew ? ', Hebrew' : ''}', (tester) async {
        tester.view.physicalSize = const Size(412, 2600);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final c = await pumpApp(
          tester,
          settings: AppSettings(
            onboardingComplete: true,
            joinDate: historyJoinDate,
            language: hebrew ? AppLanguage.hebrew : AppLanguage.system,
          ),
          now: historyNow,
          progress: historyProgress(),
        );
        c.read(routerProvider).go('/progress');
        await tester.pumpAndSettle();
        // Vayera, made up after its window.
        final status = find.text(label);
        await tester.ensureVisible(status);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(status);
        expect(tester.getSize(status).width, moreOrLessEquals(paragraph.size.width), reason: 'not scaled down');
        final tops = wordTops(paragraph, label);
        final lines = tops.toSet().length;
        // Wrapped, unless each word takes a line of its own.
        if (lines > 1 && lines < tops.length) {
          expect(tops.last, tops[tops.length - 2], reason: 'with the word before it');
        }
      });
    }
  }

  // On a phone the longest name, a week that can still be finished with the
  // next, takes two lines in English, and left "parsha" alone on the second.
  for (final (hebrew, label) in [
    (false, 'Can still be finished with the next parsha'),
    (true, 'עוד אפשר להשלים עם הפרשה הבאה'),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'at ${(scale * 100).round()}% text, the Torah map’s legend leaves no word alone on a name’s last line'
          '${hebrew ? ', Hebrew' : ''}', (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final c = await pumpApp(
          tester,
          settings: AppSettings(
            onboardingComplete: true,
            joinDate: historyJoinDate,
            language: hebrew ? AppLanguage.hebrew : AppLanguage.system,
          ),
          now: historyNow,
          progress: historyProgress(),
        );
        c.read(routerProvider).go('/progress');
        await tester.pumpAndSettle();
        final help = find.byIcon(Icons.info_outline).last;
        await tester.ensureVisible(help);
        await tester.pumpAndSettle();
        await tester.tap(help);
        await tester.pumpAndSettle();
        final name = find.text(label);
        await tester.ensureVisible(name);
        await tester.pumpAndSettle();
        final tops = wordTops(tester.renderObject<RenderParagraph>(name), label);
        if (scale == 1 && !hebrew) expect(tops.toSet(), hasLength(2), reason: 'two lines on a phone');
        expect(tops.last, tops[tops.length - 2], reason: 'with the word before it');
      });
    }
  }
}
