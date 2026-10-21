import 'package:flutter/gestures.dart' show PointerDeviceKind, PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/services/tts.dart';

import '../helpers.dart';
import 'semantics_stream.dart';

/// The reader's semantics updates, as a desktop's accessibility bridge takes
/// them (see [SemanticsStream]): stepping through verses, the full text, the
/// display sheet and its switches, and Listen leave nothing the platform's
/// tree can't take, as the PC test of build #49 found with Narrator on, from
/// the first time the display sheet opened. Nor does any node change parent.
void main() {
  SemanticsStreamBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  /// Settles a page that loads its texts from assets, which takes real time.
  Future<void> loadTexts(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      if (i > 4 && find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  testWidgets('the reader, its display sheet and Listen, on a Windows PC', (tester) async {
    final handle = tester.ensureSemantics();
    final stream = SemanticsStream.start();
    tester.view.physicalSize = const Size(1700, 980);
    tester.view.devicePixelRatio = 1.25;
    addTearDown(tester.view.reset);
    final tts = HeldTts();
    final c = await pumpApp(
      tester,
      settings: const AppSettings(onboardingComplete: true, notificationPromptShown: true),
      now: DateTime(2026, 10, 19, 10),
      overrides: [ttsProvider.overrideWithValue(tts)],
    );
    await tester.pumpAndSettle();

    final seen = <String, List<String>>{};
    void step(String what) {
      seen[what] = [...stream.problems, ...stream.moves];
      stream
        ..problems.clear()
        ..moves.clear();
    }

    Future<void> click(Finder finder) async {
      await tester.tap(finder, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
    }

    c.read(routerProvider).go('/read/5787:2/2');
    await loadTexts(tester);
    step('open the reader');
    await click(find.text('Next'));
    step('a verse on');
    await click(find.text('Back'));
    step('a verse back');
    await click(find.byTooltip('More options'));
    await click(find.text('Full text'));
    await loadTexts(tester);
    step('the full text');

    await click(find.byTooltip('Display settings'));
    step('open the display sheet');
    final sheet = find.byType(BottomSheet);
    await tester.sendEventToBinding(PointerScrollEvent(position: tester.getCenter(sheet), scrollDelta: const Offset(0, 200)));
    await tester.pumpAndSettle();
    step('scroll the sheet');
    final rashi = find.descendant(of: sheet, matching: find.text('Show Rashi alongside'));
    await tester.scrollUntilVisible(rashi, 100, scrollable: find.descendant(of: sheet, matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    await tester.tap(rashi, kind: PointerDeviceKind.mouse);
    await loadTexts(tester);
    step('Rashi on');
    await click(rashi);
    step('Rashi off');
    await click(rashi);
    step('Rashi on again');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    step('close the sheet');

    await click(find.byTooltip('Listen'));
    step('start Listen');
    for (var i = 0; i < 4; i++) {
      tts.finish();
      await tester.pumpAndSettle();
    }
    step('Listen reads on');
    await click(find.byTooltip('Stop').first);
    step('stop Listen');

    expect(stream.updates, greaterThan(10), reason: 'the updates were heard');
    expect({for (final MapEntry(:key, :value) in seen.entries) if (value.isNotEmpty) key: value}, isEmpty);
    handle.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  // Every slider the app has, on a page and in a sheet, as it opens.
  testWidgets("the display settings' sliders, and the haftarah's display sheet", (tester) async {
    final handle = tester.ensureSemantics();
    final stream = SemanticsStream.start();
    tester.view.physicalSize = const Size(1700, 980);
    tester.view.devicePixelRatio = 1.25;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, now: DateTime(2026, 10, 19, 10));
    await tester.pumpAndSettle();
    c.read(routerProvider).go('/settings/display');
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsWidgets);
    c.read(routerProvider).go('/today/haftarah/5787:2');
    await loadTexts(tester);
    await tester.tap(find.byTooltip('Display settings'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    await tester.scrollUntilVisible(find.descendant(of: sheet, matching: find.byType(Slider)), 200,
        scrollable: find.descendant(of: sheet, matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(stream.problems, isEmpty);
    expect(stream.moves, isEmpty);
    handle.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
