import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/reader/pass_track.dart';
import 'package:shnayim_mikra/features/reader/reader_flow.dart';
import 'package:shnayim_mikra/ui/theme/sefer_colors.dart';

import '../../helpers.dart';

void main() {
  const m1 = StepKind.mikra1, m2 = StepKind.mikra2, targum = StepKind.targum, rashi = StepKind.rashi;
  const third = StepKind.thirdHebrew, repeat = StepKind.repeatLast;

  /// The track's three labels, each with whether it is checked, and whether
  /// it is set in bold as the reading under way.
  Future<List<(String, {bool checked, bool bold})>> labels(WidgetTester tester, List<StepKind> steps, int step) async {
    await pumpThemed(tester, PassTrack(steps: steps, step: step));
    final texts = tester.widgetList<Text>(find.descendant(of: find.byType(PassTrack), matching: find.byType(Text)));
    return [
      for (final t in texts)
        (
          t.data!,
          checked: find
              .descendant(
                of: find.ancestor(of: find.byWidget(t), matching: find.byType(Row)).first,
                matching: find.byIcon(Icons.check),
              )
              .evaluate()
              .isNotEmpty,
          bold: t.style?.fontWeight == FontWeight.w700,
        ),
    ];
  }

  testWidgets('the readings before the one under way are checked, and it is bold', (tester) async {
    expect(await labels(tester, [m1, m2, targum], 0), [
      ('1 · Mikra', checked: false, bold: true),
      ('2 · Mikra', checked: false, bold: false),
      ('3 · Targum', checked: false, bold: false),
    ]);
    expect(await labels(tester, [m1, m2, targum], 2), [
      ('1 · Mikra', checked: true, bold: false),
      ('2 · Mikra', checked: true, bold: false),
      ('3 · Targum', checked: false, bold: true),
    ]);
  });

  testWidgets('the third reading is named for what is read in it', (tester) async {
    // Rashi in place of the Targum; and, where Rashi is silent, the Hebrew.
    expect((await labels(tester, [m1, m2, rashi], 0)).last.$1, '3 · Rashi');
    expect((await labels(tester, [m1, m2, third], 0)).last.$1, '3 · Mikra');
    // The Targum and Rashi both: the one under way.
    expect((await labels(tester, [m1, m2, targum, rashi], 1)).last.$1, '3 · Targum');
    expect(await labels(tester, [m1, m2, targum, rashi], 3), [
      ('1 · Mikra', checked: true, bold: false),
      ('2 · Mikra', checked: true, bold: false),
      ('3 · Rashi', checked: false, bold: true),
    ]);
    // Numbers 32:3 read on its own: its Hebrew again, after its Targum.
    expect((await labels(tester, [m1, m2, targum, third], 3)).last, ('3 · Mikra', checked: false, bold: true));
  });

  testWidgets('ending with the last verse once more comes after all three readings', (tester) async {
    expect(await labels(tester, [m1, m2, targum, repeat], 3), [
      ('1 · Mikra', checked: true, bold: false),
      ('2 · Mikra', checked: true, bold: false),
      ('3 · Targum', checked: true, bold: false),
    ]);
  });

  testWidgets('each bar is in its ring colour once reached, and on the track before', (tester) async {
    await pumpThemed(tester, const PassTrack(steps: [m1, m2, targum], step: 1));
    final sefer = SeferColors.of(tester.element(find.byType(PassTrack)));
    final bars = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
    expect([for (final b in bars) (b.decoration! as BoxDecoration).color], [
      sefer.ringMikra1,
      sefer.ringMikra2,
      sefer.ringTrack,
    ]);
  });

  test('a step belongs to its reading', () {
    expect([for (final k in StepKind.values) PassTrack.segmentOf(k)], [0, 1, 2, 2, 2, 3]);
  });
}
