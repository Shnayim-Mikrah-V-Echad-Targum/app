import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/features/onboarding/onboarding_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/widgets/lines.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';

import '../../helpers.dart';

/// The welcome's entrance (docs/DESIGN_SYSTEM.md §8 and §9 Onboarding): the
/// frame and title, the divider, the English name and body, then the way on
/// and the disclaimer, over 900 ms; tappable, focusable and heard from its
/// first frame; once a run; and whole at once with Reduce Motion.
void main() {
  setUp(OnboardingScreen.replayEntrance);

  /// The opacity [finder]'s widget is painted at: the product of the fades
  /// above it.
  double opacityOf(WidgetTester tester, Finder finder) {
    var opacity = 1.0;
    tester.element(finder).visitAncestorElements((e) {
      final w = e.widget;
      if (w is FadeTransition) opacity *= w.opacity.value;
      if (w is Opacity) opacity *= w.opacity;
      return true;
    });
    return opacity;
  }

  final title = find.byType(TitlePageFrame);
  final start = find.descendant(of: find.byType(OnboardingScreen), matching: find.byType(FilledButton));
  final restore = find.widgetWithText(TextButton, 'I already use Shnayim Mikra');
  // The English name (English UI only) and the body, the frame's last text.
  final name = find.byWidgetPredicate((w) => w is BalancedText && w.text == 'Shnayim Mikra v’Echad Targum');
  final body = find.descendant(of: title, matching: find.byType(BalancedText)).last;
  final disclaimer = find.byWidgetPredicate((w) => w is BalancedText && w.text.startsWith('Customs vary'));
  double divider(WidgetTester tester) => tester.widget<SeferDivider>(find.byType(SeferDivider)).progress;

  /// How far the title page stands below its place.
  double rise(WidgetTester tester) => tester
      .widget<Transform>(find.ancestor(of: title, matching: find.byType(Transform)).first)
      .transform
      .getTranslation()
      .y;

  /// The welcome as each part of it is painted: the frame and title, the
  /// divider's progress, the English name and body, the way on and the
  /// disclaimer.
  ({double frame, double divider, double text, double ways}) stages(WidgetTester tester) => (
        frame: opacityOf(tester, title),
        divider: divider(tester),
        text: opacityOf(tester, body),
        ways: opacityOf(tester, start),
      );

  /// Launches the app onto the welcome with [settings], and returns the
  /// welcome's [stages] in the first frame that shows it.
  Future<({double frame, double divider, double text, double ways})> launch(WidgetTester tester,
      {AppSettings settings = const AppSettings()}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ({double frame, double divider, double text, double ways})? first;
    void watch(Duration _) {
      if (find.byType(OnboardingScreen).evaluate().isEmpty) {
        SchedulerBinding.instance.addPostFrameCallback(watch);
      } else {
        first = stages(tester);
      }
    }

    SchedulerBinding.instance.addPostFrameCallback(watch);
    await pumpApp(tester, settings: settings, now: captureNow);
    return first!;
  }

  testWidgets('arrives in stages over 900 ms, from a bare page', (tester) async {
    final first = await launch(tester);
    expect(first, (frame: 0.0, divider: 0.0, text: 0.0, ways: 0.0));

    // pumpApp leaves it 100 ms in: the frame and title on their way, rising
    // into place, nothing else yet.
    final early = stages(tester);
    expect(early.frame, inExclusiveRange(0, 1));
    expect(early.divider, 0);
    expect(early.text, 0);
    expect(early.ways, 0);
    expect(rise(tester), greaterThan(0));

    // 300 ms: the frame and title in place, the divider drawing.
    await tester.pump(const Duration(milliseconds: 200));
    expect(stages(tester).frame, 1);
    expect(rise(tester), 0);
    expect(stages(tester).divider, inExclusiveRange(0, 1));
    expect(stages(tester).text, 0);

    // 500 ms: the English name and body fading in with it.
    await tester.pump(const Duration(milliseconds: 200));
    expect(stages(tester).divider, inExclusiveRange(0, 1));
    expect(stages(tester).text, inExclusiveRange(0, 1));
    expect(opacityOf(tester, name), stages(tester).text);
    expect(stages(tester).ways, 0);

    // 700 ms: the divider drawn, the text in, the way on fading in.
    await tester.pump(const Duration(milliseconds: 200));
    expect(stages(tester).divider, 1);
    expect(stages(tester).text, 1);
    expect(stages(tester).ways, inExclusiveRange(0, 1));
    expect(opacityOf(tester, restore), stages(tester).ways);
    expect(opacityOf(tester, disclaimer), stages(tester).ways);

    // 900 ms: whole, and still.
    await tester.pump(const Duration(milliseconds: 200));
    expect(stages(tester), (frame: 1.0, divider: 1.0, text: 1.0, ways: 1.0));
    expect(rise(tester), 0);
  });

  testWidgets('can be heard, focused and tapped before it is seen', (tester) async {
    final semantics = tester.ensureSemantics();
    await launch(tester);
    expect(opacityOf(tester, start), 0);
    expect(opacityOf(tester, body), 0);
    expect(find.bySemanticsLabel('Shnayim Mikra v’Echad Targum'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Read the parsha twice')), findsOneWidget);
    expect(find.bySemanticsLabel('I already use Shnayim Mikra'), findsOneWidget);
    expect(tester.getSemantics(start), isSemantics(isButton: true, isFocusable: true, isEnabled: true));

    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('plays once a run, not again when the welcome is built anew', (tester) async {
    await launch(tester);
    await tester.pumpAndSettle();
    // Back from the first step, the welcome whole as it was left (its page
    // stays beneath the step's).
    await tester.tap(start);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(stages(tester), (frame: 1.0, divider: 1.0, text: 1.0, ways: 1.0));

    // Built anew from the start, as in another language: the run has seen
    // it already.
    await tester.pumpWidget(const SizedBox());
    final again = await launch(tester);
    expect(again, (frame: 1.0, divider: 1.0, text: 1.0, ways: 1.0));
  });

  testWidgets('with the system\'s Reduce Motion, is whole from its first frame', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final first = await launch(tester);
    expect(first, (frame: 1.0, divider: 1.0, text: 1.0, ways: 1.0));
    expect(rise(tester), 0);
  });

  testWidgets('ends at once when motion is reduced as it plays', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(), now: captureNow);
    await tester.pump(const Duration(milliseconds: 200));
    expect(stages(tester).divider, inExclusiveRange(0, 1), reason: 'under way, some 300 ms in');

    c.read(settingsProvider.notifier).update((s) => s.copyWith(reduceMotion: true));
    await tester.pump();
    expect(stages(tester), (frame: 1.0, divider: 1.0, text: 1.0, ways: 1.0));
    expect(rise(tester), 0);
  });

  for (final hebrew in [false, true]) {
    testWidgets('with Reduce Motion${hebrew ? ', in Hebrew' : ''}, is whole from its first frame', (tester) async {
      final first = await launch(
        tester,
        settings: AppSettings(reduceMotion: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.system),
      );
      expect(first, (frame: 1.0, divider: 1.0, text: 1.0, ways: 1.0));
      expect(rise(tester), 0);
    });
  }
}
