import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/ui/widgets/app_mark.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget mark, {double devicePixelRatio = 1}) async {
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Center(child: mark)));
  }

  String asset(WidgetTester tester) => (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName;

  testWidgets('is drawn at its size with corners a quarter of it', (tester) async {
    await pump(tester, const AppMark());
    expect(tester.getSize(find.byType(AppMark)), const Size(40, 40));
    expect(tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius, BorderRadius.circular(10));

    await pump(tester, const AppMark(size: 72));
    expect(tester.getSize(find.byType(AppMark)), const Size(72, 72));
    expect(tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius, BorderRadius.circular(18));
  });

  testWidgets('uses the smallest rendering that covers the pixels drawn', (tester) async {
    // 40 at 3x is 120 px, which the 128 px rendering covers.
    for (final dpr in [1.0, 2.0, 3.0]) {
      await pump(tester, const AppMark(), devicePixelRatio: dpr);
      expect(asset(tester), AppMark.small, reason: '$dpr');
    }
    await pump(tester, const AppMark(size: 72), devicePixelRatio: 2);
    expect(asset(tester), AppMark.master);
    // Scaled down with mipmaps, so the letters stay whole.
    expect(tester.widget<Image>(find.byType(Image)).filterQuality, FilterQuality.medium);
  });

  testWidgets('is decorative unless it is given a label', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const AppMark());
    expect(find.bySemanticsLabel('Shnayim Mikra'), findsNothing);
    expect(tester.widget<Image>(find.byType(Image)).excludeFromSemantics, isTrue);

    await pump(tester, const AppMark(semanticLabel: 'Shnayim Mikra'));
    expect(
      tester.getSemantics(find.byType(RawImage)),
      isSemantics(label: 'Shnayim Mikra', isImage: true, isHeader: false),
    );
    handle.dispose();
  });
}
