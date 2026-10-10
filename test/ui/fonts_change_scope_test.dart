import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/services/optional_fonts.dart';
import 'package:shnayim_mikra/ui/widgets/fonts_change_scope.dart';

import '../helpers.dart';

/// The app's assets, held back until [open] is completed, as over a slow
/// network.
class _GatedAssets extends CachingAssetBundle {
  final open = Completer<void>();

  @override
  Future<ByteData> load(String key) async {
    await open.future;
    return rootBundle.load(key);
  }
}

/// A font that arrives after the first layout: what measures text as it is
/// built must measure it again, and the app shows a chosen interface font
/// only once it has arrived. This file loads no fonts up front, so each
/// family is new to the engine when a test loads it.
void main() {
  setUp(OptionalFonts.reset);

  testWidgets('rebuilds what measures text when a font arrives', (tester) async {
    var builds = 0;
    late double measured;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: FontsChangeScope(
        child: Builder(builder: (context) {
          FontsChangeScope.watch(context);
          builds++;
          final painter = TextPainter(
            text: const TextSpan(text: 'Community', style: TextStyle(fontFamily: 'LateSans', fontSize: 20)),
            textDirection: TextDirection.ltr,
          )..layout();
          measured = painter.width;
          painter.dispose();
          return const SizedBox();
        }),
      ),
    ));
    final before = measured;
    expect(builds, 1);
    // The test font, standing in for a family not registered, draws each
    // letter one em wide.
    expect(before, 20.0 * 'Community'.length);

    await tester.runAsync(() async {
      final loader = FontLoader('LateSans')..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      await loader.load();
    });
    await tester.pump();
    expect(builds, 2);
    expect(measured, lessThan(before));
  });

  testWidgets('without a scope, asks nothing', (tester) async {
    await tester.pumpWidget(Builder(builder: (context) {
      FontsChangeScope.watch(context);
      return const SizedBox();
    }));
    expect(tester.takeException(), isNull);
  });

  // The theme switches, and the navigation bar measures its labels, with the
  // font itself rather than a stand-in.
  testWidgets('the app shows a chosen interface font once it has loaded', (tester) async {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Still on its way as the app starts (main() stops waiting after a while).
    final assets = _GatedAssets();
    final arriving = OptionalFonts.ensure('OpenDyslexic', bundle: assets);
    await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, uiFont: UiFont.openDyslexic));
    String? family() =>
        Theme.of(tester.element(find.byType(NavigationBar))).navigationBarTheme.labelTextStyle!.resolve({})!.fontFamily;
    expect(OptionalFonts.isLoaded('OpenDyslexic'), isFalse);
    expect(family(), isNot('OpenDyslexic'), reason: 'not drawn in a stand-in for it');

    await tester.runAsync(() async {
      assets.open.complete();
      await arriving;
    });
    await tester.pumpAndSettle();
    expect(family(), 'OpenDyslexic');

    // The labels' scale is the one their own font calls for.
    final bar = find.byType(NavigationBar);
    final context = tester.element(bar);
    final style = NavigationBarTheme.of(context).labelTextStyle!.resolve({WidgetState.selected})!;
    var widest = 0.0;
    for (final d in tester.widget<NavigationBar>(bar).destinations.cast<NavigationDestination>()) {
      final painter = TextPainter(text: TextSpan(text: d.label, style: style), textDirection: TextDirection.ltr)..layout();
      widest = widest > painter.width ? widest : painter.width;
      painter.dispose();
    }
    final fits = 412 / 5 / widest;
    final expected = fits >= 1 ? 1.0 : (fits < 0.7 ? 0.7 : fits);
    expect(MediaQuery.textScalerOf(context).scale(1), closeTo(expected, 0.001));
  });
}
