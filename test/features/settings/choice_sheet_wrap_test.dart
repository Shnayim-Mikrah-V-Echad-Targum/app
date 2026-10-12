import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/city_providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/data/city_directory.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

/// The Shabbat times' choice sheet, in the bundled fonts: at 200% text on a
/// phone a choice wraps with no word alone on its last line ("15 minutes /
/// before sunset", not "15 minutes before / sunset").
void main() {
  setUpAll(loadBundledFonts);

  for (final hebrew in [false, true]) {
    testWidgets('at 200% text, a candle-lighting choice leaves no word alone on its last line'
        '${hebrew ? ', Hebrew' : ''}', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final directory = CityDirectory.parse(File('assets/data/cities.json').readAsStringSync());
      final c = await pumpApp(
        tester,
        settings: AppSettings(
          onboardingComplete: true,
          joinDate: LocalDate(2026, 9, 1),
          city: directory.cities.firstWhere((c) => c.nameEn == 'Jerusalem'),
          language: hebrew ? AppLanguage.hebrew : AppLanguage.system,
        ),
        now: DateTime(2026, 10, 13, 10),
        overrides: [cityDirectoryProvider.overrideWith((ref) => directory)],
      );
      c.read(routerProvider).go('/settings/reading');
      await tester.pumpAndSettle();
      final row = find.text(hebrew ? 'הדלקת נרות' : 'Candle-lighting');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      var wrapped = 0;
      for (final minutes in [15, 18, 20, 22, 30, 40]) {
        final label = hebrew ? '$minutes דקות לפני השקיעה' : '$minutes minutes before sunset';
        final choice = find.descendant(of: find.byType(BottomSheet), matching: find.text(label));
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(choice);
        // The number and its unit are one word, held by a no-break space.
        final words = label.split(' ');
        final tops = <double>[];
        for (var i = 0, start = 0; i < words.length; start += words[i].length + 1, i++) {
          final selection = TextSelection(baseOffset: start, extentOffset: start + words[i].length);
          tops.add(paragraph.getBoxesForSelection(selection).first.top);
        }
        final lines = tops.toSet().length;
        if (lines > 1) wrapped++;
        if (lines > 1 && lines < words.length) {
          expect(tops.last, tops[tops.length - 2], reason: '$label: with the word before it');
        }
      }
      // In English every choice wraps on this phone.
      if (!hebrew) expect(wrapped, 6);
    });
  }
}
