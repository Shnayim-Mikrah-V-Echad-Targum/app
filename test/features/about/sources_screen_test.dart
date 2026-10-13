import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/ui/widgets/ornaments.dart';

import '../../helpers.dart';

void main() {
  late List<String> launched;

  Future<void> openSources(WidgetTester tester) async {
    launched = [];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launch') launched.add((call.arguments as Map)['url'] as String);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    tester.view.physicalSize = const Size(412, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true));
    c.read(routerProvider).go('/sources');
    await tester.pumpAndSettle();
  }

  testWidgets('each source opens from anywhere on its card', (tester) async {
    await openSources(tester);
    expect(find.text('Learn more'), findsNothing);
    await tester.tap(find.text('Torat Emet edition, via Sefaria.'));
    expect(launched, ['https://www.sefaria.org/Onkelos_Genesis']);
    await tester.tap(find.text('Cities for Shabbat times'));
    expect(launched.last, 'https://www.geonames.org/');
  });

  testWidgets("a source's license is a label by its name, not a control", (tester) async {
    final handle = tester.ensureSemantics();
    await openSources(tester);
    expect(find.byType(Chip), findsNothing);
    final license = find.text('CC BY 4.0');
    expect(find.ancestor(of: license, matching: find.byType(ButtonStyleButton)), findsNothing);
    // Read in the card's link, not as an item of its own.
    final card = tester.getSemantics(license);
    expect(card, isSemantics(isLink: true));
    expect(card.label, startsWith('Cities for Shabbat times, CC BY 4.0\n'));
    handle.dispose();
  });

  testWidgets('the note on the adapted files closes the page, under a divider', (tester) async {
    await openSources(tester);
    final note = find.textContaining('distributed under their original licenses');
    expect(tester.getTopLeft(note).dy, greaterThan(tester.getBottomLeft(find.byType(SeferDivider)).dy));
  });
}
