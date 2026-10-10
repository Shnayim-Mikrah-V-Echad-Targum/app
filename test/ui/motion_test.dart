import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/services/feedback.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';

import '../helpers.dart';

/// docs/DESIGN_SYSTEM.md §8 and §6.19: motion tokens, page transitions, and
/// Reduce Motion reaching dialogs, sheets, snack bars, menus and ink.
ThemeData _theme({bool reduceMotion = false, AppThemeMode mode = AppThemeMode.light}) =>
    AppTheme.build(mode: mode, uiFont: UiFont.standard, hebrewUi: false, reduceMotion: reduceMotion);

/// A screen with one button that runs [onPressed] with the screen's context.
Widget _launcher(ThemeData theme, void Function(BuildContext) onPressed,
        {bool disableAnimations = false, TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
        child: Directionality(textDirection: direction, child: child!),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(onPressed: () => onPressed(context), child: const Text('Open')),
          ),
        ),
      ),
    );

void main() {
  group('Motion', () {
    test('tokens', () {
      expect(
        [Motion.short, Motion.medium, Motion.long, Motion.ring, Motion.frame].map((d) => d.inMilliseconds),
        [150, 250, 400, 600, 900],
      );
      expect(Motion.standard, const Cubic(0.2, 0, 0, 1));
      expect(Motion.decelerate, const Cubic(0.05, 0.7, 0.1, 1));
      expect(Motion.accelerate, const Cubic(0.3, 0, 0.8, 0.15));
    });

    for (final (setting, system, reduced) in [
      (false, false, false),
      (true, false, true),
      (false, true, true),
    ]) {
      testWidgets('setting $setting, system $system: reduced is $reduced', (tester) async {
        late Motion motion;
        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(disableAnimations: system),
          child: Theme(
            data: _theme(reduceMotion: setting),
            child: Builder(builder: (context) {
              motion = Motion.of(context);
              return const SizedBox();
            }),
          ),
        ));
        expect(motion.reduced, reduced);
        expect(motion.d(Motion.medium), reduced ? Duration.zero : Motion.medium);
        expect(motion.style, reduced ? AnimationStyle.noAnimation : isNull);
      });
    }

    test('interpolates by switching halfway', () {
      const on = Motion(reduced: true);
      const off = Motion();
      expect(off.lerp(on, 0.4), off);
      expect(off.lerp(on, 0.6), on);
      expect(off.copyWith(reduced: true), on);
    });
  });

  group('the theme', () {
    test('turns off ink splashes while motion is reduced', () {
      expect(_theme(reduceMotion: true).splashFactory, NoSplash.splashFactory);
      expect(_theme().splashFactory, isNot(NoSplash.splashFactory));
      expect(_theme(reduceMotion: true).extension<Motion>()!.reduced, isTrue);
      expect(_theme().extension<Motion>()!.reduced, isFalse);
    });

    test('page transitions: each platform its own, a fade on the web and desktop', () {
      final native = AppPageTransitions.theme(reduced: false, web: false).builders;
      expect(native[TargetPlatform.android], isA<FadeForwardsDirectionalPageTransitionsBuilder>());
      expect(native[TargetPlatform.fuchsia], isA<FadeForwardsDirectionalPageTransitionsBuilder>());
      expect(native[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>());
      expect(native[TargetPlatform.macOS], isA<CupertinoPageTransitionsBuilder>());
      expect(native[TargetPlatform.windows], isA<FadeRisePageTransitionsBuilder>());
      expect(native[TargetPlatform.linux], isA<FadeRisePageTransitionsBuilder>());
      expect(native[TargetPlatform.android]!.transitionDuration, const Duration(milliseconds: 450));
      expect(native[TargetPlatform.windows]!.transitionDuration, Motion.medium);

      final web = AppPageTransitions.theme(reduced: false, web: true).builders;
      for (final platform in TargetPlatform.values) {
        expect(web[platform], isA<FadeRisePageTransitionsBuilder>(), reason: platform.name);
      }

      final reduced = _theme(reduceMotion: true).pageTransitionsTheme.builders;
      for (final platform in TargetPlatform.values) {
        expect(reduced[platform]!.transitionDuration, Duration.zero, reason: platform.name);
      }
    });
  });

  group('page transitions', () {
    Future<void> push(WidgetTester tester, TargetPlatform platform,
        {bool reduceMotion = false, TextDirection direction = TextDirection.ltr}) async {
      final theme = _theme(reduceMotion: reduceMotion).copyWith(platform: platform);
      await tester.pumpWidget(_launcher(
        theme,
        (context) => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('Next'))),
        )),
        direction: direction,
      ));
      await tester.tap(find.text('Open'));
      await tester.pump();
      // The first frame lays the new page out offstage.
      await tester.pump();
    }

    double opacity(WidgetTester tester) =>
        tester.widget<FadeTransition>(find.ancestor(of: find.text('Next'), matching: find.byType(FadeTransition)).first)
            .opacity
            .value;

    testWidgets('desktop: the next page fades in, rising 8 px, over 250 ms', (tester) async {
      await push(tester, TargetPlatform.windows);
      final start = tester.getTopLeft(find.byType(Scaffold).last).dy;
      expect(opacity(tester), 0);
      // At the start, the page sits 8 px low; it lands on time.
      final transform = tester.widget<Transform>(
        find.ancestor(of: find.text('Next'), matching: find.byType(Transform)).first,
      );
      expect(transform.transform.getTranslation().y, 8);
      await tester.pump(const Duration(milliseconds: 125));
      expect(opacity(tester), allOf(greaterThan(0.5), lessThan(1)));
      await tester.pump(const Duration(milliseconds: 125));
      expect(opacity(tester), 1);
      expect(tester.getTopLeft(find.byType(Scaffold).last).dy, start - 8);
      // No zoom anywhere.
      expect(find.ancestor(of: find.text('Next'), matching: find.byType(ScaleTransition)), findsNothing);
    });

    testWidgets('reduced: the next page is there at once', (tester) async {
      await push(tester, TargetPlatform.windows, reduceMotion: true);
      expect(find.text('Next'), findsOneWidget);
      expect(find.ancestor(of: find.text('Next'), matching: find.byType(FadeTransition)), findsNothing);
      expect(find.ancestor(of: find.text('Next'), matching: find.byType(Transform)), findsNothing);
    });

    for (final direction in TextDirection.values) {
      testWidgets('Android, ${direction.name}: the next page arrives from the end', (tester) async {
        await push(tester, TargetPlatform.android, direction: direction);
        await tester.pump(const Duration(milliseconds: 100));
        final x = tester.getTopLeft(find.text('Next')).dx;
        // One slide and one fade: the predictive back transition, always
        // there to catch a back swipe, stands still.
        final above = find.ancestor(of: find.text('Next'), matching: find.byType(SlideTransition));
        expect(tester.widgetList<SlideTransition>(above).where((t) => t.position.value != Offset.zero), hasLength(1));
        final fades = find.ancestor(of: find.text('Next'), matching: find.byType(FadeTransition));
        expect(tester.widgetList<FadeTransition>(fades).where((t) => t.opacity.value < 1), hasLength(1));
        await tester.pumpAndSettle();
        final settled = tester.getTopLeft(find.text('Next')).dx;
        // Right of its place in English, left of it in Hebrew.
        expect(x, direction == TextDirection.ltr ? greaterThan(settled) : lessThan(settled));
        // The page beneath was pushed the other way; it is back when popped.
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final under = tester.getTopLeft(find.text('Open')).dx;
        await tester.pumpAndSettle();
        final home = tester.getTopLeft(find.text('Open')).dx;
        expect(under, direction == TextDirection.ltr ? lessThan(home) : greaterThan(home));
      });
    }
  });

  group('Android predictive back', () {
    Future<void> gesture(WidgetTester tester, String method, [Map<String, Object>? arguments]) =>
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/backgesture',
          const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
          (_) {},
        );

    Future<void> swipe(WidgetTester tester, double progress) => gesture(tester, 'updateBackGestureProgress', {
          'x': 400 * progress,
          'y': 300.0,
          'progress': progress,
          'swipeEdge': 0,
        });

    Future<ModalRoute<Object?>> pushNext(WidgetTester tester, TextDirection direction) async {
      final theme = _theme().copyWith(platform: TargetPlatform.android);
      await tester.pumpWidget(_launcher(
        theme,
        (context) => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('Next'))),
        )),
        direction: direction,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return ModalRoute.of(tester.element(find.text('Next')))!;
    }

    final predictive =
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_PredictiveBackSharedElementPageTransition');

    for (final direction in TextDirection.values) {
      testWidgets('${direction.name}: a back swipe previews the page beneath, and pops when released',
          (tester) async {
        final route = await pushNext(tester, direction);
        final settled = tester.getRect(find.text('Next'));
        expect(predictive, findsNothing);

        await gesture(tester, 'startBackGesture', {
          'touchOffset': [5.0, 300.0],
          'progress': 0.0,
          'swipeEdge': 0,
        });
        await tester.pump();
        expect(route.popGestureInProgress, isTrue);
        await swipe(tester, 0.35);
        await tester.pump();

        // The page follows the finger, in the framework's predictive
        // transition, and the page beneath shows.
        expect(route.animation!.value, closeTo(0.65, 0.001));
        expect(predictive, findsWidgets);
        expect(tester.getRect(find.text('Next')), isNot(settled));
        expect(find.text('Open'), findsOneWidget);

        await gesture(tester, 'commitBackGesture');
        await tester.pumpAndSettle();
        expect(find.text('Next'), findsNothing);
        expect(tester.getCenter(find.text('Open')), const Offset(400, 300));
        expect(predictive, findsNothing);
      });

      testWidgets('${direction.name}: a cancelled swipe puts the page back where it was', (tester) async {
        final route = await pushNext(tester, direction);
        final settled = tester.getRect(find.text('Next'));
        await gesture(tester, 'startBackGesture', {
          'touchOffset': [5.0, 300.0],
          'progress': 0.0,
          'swipeEdge': 0,
        });
        await tester.pump();
        await swipe(tester, 0.2);
        await tester.pump();
        await gesture(tester, 'cancelBackGesture');
        await tester.pumpAndSettle();
        expect(route.popGestureInProgress, isFalse);
        expect(route.isCurrent, isTrue);
        expect(tester.getRect(find.text('Next')), settled);
      });
    }
  });

  group('showAppDialog', () {
    Future<void> open(WidgetTester tester, {bool reduceMotion = false, bool disableAnimations = false}) async {
      await tester.pumpWidget(_launcher(
        _theme(reduceMotion: reduceMotion),
        (context) => showAppDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear this week?'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
          ),
        ),
        disableAnimations: disableAnimations,
      ));
      await tester.tap(find.text('Open'));
      await tester.pump();
    }

    (double, double) look(WidgetTester tester) {
      final dialog = find.byType(AlertDialog);
      final fade = tester.widget<FadeTransition>(find.ancestor(of: dialog, matching: find.byType(FadeTransition)).first);
      final scale = tester.widget<ScaleTransition>(find.ancestor(of: dialog, matching: find.byType(ScaleTransition)));
      return (fade.opacity.value, scale.scale.value);
    }

    testWidgets('fades in and grows from 98% over 150 ms, on paper', (tester) async {
      await open(tester);
      expect(look(tester), (0, 0.98));
      await tester.pump(const Duration(milliseconds: 75));
      final (opacity, scale) = look(tester);
      expect(opacity, allOf(greaterThan(0), lessThan(1)));
      expect(scale, allOf(greaterThan(0.98), lessThan(1)));
      await tester.pump(const Duration(milliseconds: 75));
      expect(look(tester), (1, 1));

      final material = tester.widget<Material>(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(Material)).first,
      );
      expect(material.color, Palettes.seferLight.paper);
      expect(
        (material.shape! as RoundedRectangleBorder).borderRadius,
        const BorderRadius.all(Radius.circular(16)),
      );
      expect(find.ancestor(of: find.byType(AlertDialog), matching: find.byType(SafeArea)), findsOneWidget);

      // The barrier dismisses it.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    for (final (name, setting, system) in [('the setting', true, false), ('the system', false, true)]) {
      testWidgets('appears at once when $name reduces motion', (tester) async {
        await open(tester, reduceMotion: setting, disableAnimations: system);
        expect(look(tester), (1, 1));
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        expect(find.byType(AlertDialog), findsNothing);
      });
    }

    testWidgets('keeps keyboard focus inside', (tester) async {
      await open(tester);
      await tester.pumpAndSettle();
      final route = ModalRoute.of(tester.element(find.byType(AlertDialog)))!;
      expect(route.traversalEdgeBehavior, TraversalEdgeBehavior.closedLoop);
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus!.context!;
        expect(find.descendant(of: find.byType(AlertDialog), matching: find.byWidget(focused.widget)), findsOneWidget);
      }
    });

    testWidgets("keeps the caller's theme", (tester) async {
      final dark = _theme(mode: AppThemeMode.dark);
      await tester.pumpWidget(MaterialApp(
        theme: _theme(),
        home: Scaffold(
          body: Theme(
            data: dark,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showAppDialog<void>(context: context, builder: (_) => const AlertDialog(title: Text('Dark'))),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(find.text('Dark'))).colorScheme, dark.colorScheme);
    });
  });

  group('showAppSheet', () {
    Future<void> open(WidgetTester tester, {bool reduceMotion = false, double width = 412}) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_launcher(
        _theme(reduceMotion: reduceMotion),
        (context) => showAppSheet<void>(
          context: context,
          builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
            const SheetTitle('When did you read it?'),
            ListTile(leading: const Icon(Icons.today), title: const Text('Today'), onTap: () {}),
          ]),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pump();
    }

    testWidgets('slides up on paper with a drag handle', (tester) async {
      await open(tester);
      final start = tester.getTopLeft(find.text('Today')).dy;
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Today')).dy, lessThan(start));
      final sheet = tester.widget<Material>(
        find.descendant(of: find.byType(BottomSheet), matching: find.byType(Material)).first,
      );
      expect(sheet.color, Palettes.seferLight.paper);
      expect(
        tester.getSize(find.descendant(of: find.byType(BottomSheet), matching: find.byType(Material)).first).width,
        412,
      );
    });

    testWidgets('appears at once while motion is reduced', (tester) async {
      await open(tester, reduceMotion: true);
      final start = tester.getTopLeft(find.text('Today')).dy;
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Today')).dy, start);
    });

    for (final (width, padding) in [(412.0, 24.0), (340.0, 16.0)]) {
      testWidgets('at $width dp, the title and rows start $padding in', (tester) async {
        await open(tester, width: width);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text('When did you read it?')).dx, padding);
        expect(tester.getTopLeft(find.byIcon(Icons.today)).dx, padding);
        final title = tester.getSemantics(find.text('When did you read it?')).getSemanticsData();
        expect(title.flagsCollection.isHeader, isTrue);
        expect(title.headingLevel, 2);
      });
    }

    testWidgets('is at most 640 wide, centred, on a wide screen', (tester) async {
      await open(tester, width: 1200);
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.descendant(of: find.byType(BottomSheet), matching: find.byType(Material)).first);
      expect(sheet.width, 640);
      expect(sheet.center.dx, 600);
    });
  });

  group('showStatus', () {
    Future<void> pump(WidgetTester tester, {bool reduceMotion = false, bool accessibleNavigation = false}) async {
      await tester.pumpWidget(MaterialApp(
        theme: _theme(reduceMotion: reduceMotion),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(accessibleNavigation: accessibleNavigation),
          child: child!,
        ),
        home: const Scaffold(body: SizedBox()),
      ));
    }

    BuildContext ctx(WidgetTester tester) => tester.element(find.byType(SizedBox).first);

    SnackBar bar(WidgetTester tester) => tester.widget<SnackBar>(find.byType(SnackBar));

    testWidgets('4 s for a plain message, 8 s with an action', (tester) async {
      await pump(tester);
      showStatus(ctx(tester), 'Marked as read');
      await tester.pump();
      expect(bar(tester).duration, const Duration(seconds: 4));
      expect(bar(tester).persist, isFalse);

      showStatus(ctx(tester), 'Marked as unread', action: SnackBarAction(label: 'Undo', onPressed: () {}));
      await tester.pumpAndSettle();
      expect(bar(tester).duration, const Duration(seconds: 8));
      expect(bar(tester).persist, isFalse);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a screen reader user keeps a message with an action', (tester) async {
      await pump(tester, accessibleNavigation: true);
      showStatus(ctx(tester), 'Marked as unread', action: SnackBarAction(label: 'Undo', onPressed: () {}));
      await tester.pumpAndSettle();
      expect(bar(tester).persist, isTrue);
      showStatus(ctx(tester), 'Marked as read');
      await tester.pumpAndSettle();
      expect(bar(tester).persist, isFalse);
    });

    testWidgets('slides in with motion, appears at once without', (tester) async {
      await pump(tester);
      showStatus(ctx(tester), 'One');
      await tester.pump();
      expect(bar(tester).animation!.value, 0);
      await tester.pump(Motion.medium);
      expect(bar(tester).animation!.value, 1);

      // Turning Reduce Motion on mid-message: the next one replaces it at once.
      await pump(tester, reduceMotion: true);
      await tester.pump(kThemeAnimationDuration);
      showStatus(ctx(tester), 'Two');
      await tester.pump();
      expect(find.text('One'), findsNothing);
      expect(bar(tester).animation!.value, 1);
      showStatus(ctx(tester), 'Three');
      await tester.pump();
      expect(find.text('Two'), findsNothing);
      expect(bar(tester).animation!.value, 1);

      // And off again: motion is back.
      await pump(tester);
      await tester.pump(kThemeAnimationDuration);
      showStatus(ctx(tester), 'Four');
      await tester.pump();
      expect(find.text('Three'), findsNothing);
      expect(bar(tester).animation!.value, 0);
      await tester.pumpAndSettle();
      expect(find.text('Four'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  for (final reduceMotion in [false, true]) {
    testWidgets('menus open ${reduceMotion ? 'at once' : 'with motion'}, reduceMotion $reduceMotion', (tester) async {
      final c = await pumpApp(tester, settings: AppSettings(onboardingComplete: true, reduceMotion: reduceMotion));
      c.read(routerProvider).go('/week/5787:1');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More options').first);
      await tester.pump();
      final route = ModalRoute.of(tester.element(find.byType(PopupMenuItem<String>).first))!;
      expect(route.animation!.value, reduceMotion ? 1 : 0);
    });
  }
}
