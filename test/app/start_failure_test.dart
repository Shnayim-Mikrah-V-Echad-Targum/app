import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shnayim_mikrah/app/config.dart';
import 'package:shnayim_mikrah/app/start_failure.dart';
import 'package:shnayim_mikrah/l10n/app_localizations_en.dart';
import 'package:shnayim_mikrah/l10n/app_localizations_he.dart';
import 'package:shnayim_mikrah/services/recent_errors.dart';
import 'package:shnayim_mikrah/ui/theme/focus.dart';
import 'package:shnayim_mikrah/ui/theme/palette.dart';

/// The page the app shows in its place when it can't start (lib/main.dart),
/// with no theme or translations of the app's around it.
void main() {
  final en = AppLocalizationsEn();
  final he = AppLocalizationsHe();

  /// Two errors, as the app reports them on the way.
  RecentErrors errors() => RecentErrors()
    ..add(FlutterErrorDetails(
      exception: const FormatException('Unexpected character (at character 1)'),
      stack: StackTrace.current,
    ))
    ..add(FlutterErrorDetails(
      exception: FlutterError('Unable to load asset: "assets/data/parshiyot.json".'),
      stack: StackTrace.current,
    ));

  Future<void> pump(WidgetTester tester, {VoidCallback? onRetry, RecentErrors? recent}) async {
    await tester.pumpWidget(StartFailureApp(onRetry: onRetry, errors: recent ?? errors()));
    await tester.pump();
  }

  /// The surface the page paints.
  Color surface(WidgetTester tester) =>
      tester.widget<ColoredBox>(find.ancestor(of: find.byType(SafeArea), matching: find.byType(ColoredBox)).first).color;

  // As the device is set.
  void device(WidgetTester tester, {List<Locale>? locales, Brightness? brightness, FakeAccessibilityFeatures? features}) {
    if (locales != null) tester.platformDispatcher.localesTestValue = locales;
    if (brightness != null) tester.platformDispatcher.platformBrightnessTestValue = brightness;
    if (features != null) tester.platformDispatcher.accessibilityFeaturesTestValue = features;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }

  testWidgets('says in English that the app couldn’t open, and what may help', (tester) async {
    await pump(tester);
    expect(find.text(en.startFailedTitle), findsOneWidget);
    expect(find.text('${en.startFailedReopen} ${en.startFailedWriteToUs}'), findsOneWidget);
    expect(find.text(en.copySupportDetails), findsOneWidget);
    // Off the web there is nothing to try again: the app is closed and
    // opened again.
    expect(find.text(en.actionRetry), findsNothing);
    expect(tester.widget<Directionality>(find.byType(Directionality).first).textDirection, TextDirection.ltr);
  });

  testWidgets('names the support address where the build has one', (tester) async {
    AppConfig.debugSupportEmail = 'help@example.org';
    addTearDown(() => AppConfig.debugSupportEmail = null);
    await pump(tester);
    expect(find.text('${en.startFailedReopen} ${en.startFailedWriteTo('help@example.org')}'), findsOneWidget);
  });

  testWidgets('copies the version and what went wrong, and says so', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Shnayim Mikrah',
      packageName: 'org.shnayimmikrah.app',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
    device(tester, features: const FakeAccessibilityFeatures(supportsAnnounce: true));
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final recent = errors();
    await pump(tester, recent: recent);
    await tester.tap(find.text(en.copySupportDetails));
    await tester.pump();
    expect(copied, recent.report(version: '1.2.3 (45)'));
    expect(copied, contains('Unable to load asset'));
    expect(find.text(en.supportDetailsCopied), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect([for (final a in tester.takeAnnouncements()) a.message], [en.supportDetailsCopied]);
  });

  testWidgets('where nothing is announced, the copied button is a live region', (tester) async {
    device(tester, features: const FakeAccessibilityFeatures(supportsAnnounce: false));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final semantics = tester.ensureSemantics();
    await pump(tester);
    expect(tester.getSemantics(find.text(en.copySupportDetails)).flagsCollection.isLiveRegion, isFalse);
    await tester.tap(find.text(en.copySupportDetails));
    await tester.pump();
    expect(tester.getSemantics(find.text(en.supportDetailsCopied)).flagsCollection.isLiveRegion, isTrue);
    expect(tester.takeAnnouncements(), isEmpty);
    semantics.dispose();
  });

  testWidgets('shows the first line of each error beneath, left to right', (tester) async {
    device(tester, locales: const [Locale('he', 'IL')]);
    await pump(tester);
    final details = find.text(
      'FormatException: Unexpected character (at character 1)\nUnable to load asset: "assets/data/parshiyot.json".',
    );
    expect(details, findsOneWidget);
    expect(Directionality.of(tester.element(details)), TextDirection.ltr, reason: 'English, as the errors are');
    expect(tester.getTopLeft(details).dy, greaterThan(tester.getBottomLeft(find.text(he.copySupportDetails)).dy));
  });

  testWidgets('shows no details while nothing has been reported', (tester) async {
    await pump(tester, recent: RecentErrors());
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.text(en.copySupportDetails), findsOneWidget);
  });

  group('in the device’s language', () {
    test('the first of the device’s languages that the app has', () {
      expect(StartFailureApp.hebrewFor(const [Locale('he', 'IL')]), isTrue);
      // Older Android reports Hebrew as iw, which Locale reads as he.
      expect(StartFailureApp.hebrewFor(const [Locale('iw')]), isTrue);
      expect(StartFailureApp.hebrewFor(const [Locale('fr'), Locale('he')]), isTrue);
      expect(StartFailureApp.hebrewFor(const [Locale('en', 'GB'), Locale('he')]), isFalse);
      expect(StartFailureApp.hebrewFor(const [Locale('fr')]), isFalse);
      expect(StartFailureApp.hebrewFor(const []), isFalse);
    });

    testWidgets('in Hebrew, right to left', (tester) async {
      device(tester, locales: const [Locale('fr', 'FR'), Locale('he', 'IL')]);
      await pump(tester);
      expect(find.text(he.startFailedTitle), findsOneWidget);
      expect(find.text('${he.startFailedReopen} ${he.startFailedWriteToUs}'), findsOneWidget);
      expect(find.text(he.copySupportDetails), findsOneWidget);
      expect(Directionality.of(tester.element(find.text(he.startFailedTitle))), TextDirection.rtl);
    });

    testWidgets('following the device as it changes', (tester) async {
      await pump(tester);
      tester.platformDispatcher.localesTestValue = const [Locale('he')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester.binding.handleLocaleChanged();
      await tester.pump();
      expect(find.text(he.startFailedTitle), findsOneWidget);
    });
  });

  testWidgets('on the web, offers Try again first, by touch and by keyboard', (tester) async {
    var retries = 0;
    await pump(tester, onRetry: () => retries++);
    expect(find.text('${en.startFailedReload} ${en.startFailedWriteToUs}'), findsOneWidget);
    final retry = find.text(en.actionRetry);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    // Before Copy, in reading order: above it, where they don't fit side by
    // side.
    final (first, then) = (tester.getRect(retry), tester.getRect(find.text(en.copySupportDetails)));
    expect(first.top < then.top || (first.top == then.top && first.left < then.left), isTrue);
    await tester.tap(retry);
    expect(retries, 1);
    // Tab reaches it, and Enter and Space press it.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(retries, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(retries, 3);
  });

  testWidgets('its buttons are at least 48 high, are buttons to screen readers, and the sentence a heading',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, onRetry: () {});
    for (final label in [en.actionRetry, en.copySupportDetails]) {
      final button = find.ancestor(of: find.text(label), matching: find.byType(FocusableActionDetector));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48), reason: label);
      expect(
        tester.getSemantics(find.text(label)),
        matchesSemantics(
          label: label,
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
        reason: label,
      );
    }
    expect(tester.getSemantics(find.text(en.startFailedTitle)).flagsCollection.isHeader, isTrue);
    semantics.dispose();
  });

  testWidgets('rings a button focused from the keyboard, outside it', (tester) async {
    await pump(tester, onRetry: () {});
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    ShapeBorder shape() => (tester
            .widget<DecoratedBox>(find.ancestor(of: find.text(en.actionRetry), matching: find.byType(DecoratedBox)).first)
            .decoration as ShapeDecoration)
        .shape;
    expect(shape(), isNot(isA<FocusRingBorder>()));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(shape(), isA<FocusRingBorder>().having((s) => s.ring, 'ring', Palettes.seferLight.focus));
  });

  testWidgets('paints the device’s light, dark or high-contrast palette', (tester) async {
    for (final (brightness, highContrast, scheme) in [
      (Brightness.light, false, Palettes.light),
      (Brightness.dark, false, Palettes.dark),
      (Brightness.light, true, Palettes.hcLight),
      (Brightness.dark, true, Palettes.hcDark),
    ]) {
      device(tester, brightness: brightness, features: FakeAccessibilityFeatures(highContrast: highContrast));
      await pump(tester);
      expect(surface(tester), scheme.surface, reason: '$brightness, high contrast $highContrast');
      final title = tester.widget<Text>(find.text(en.startFailedTitle));
      expect(title.style?.color, scheme.onSurfaceVariant);
    }
  });

  testWidgets('a Text button’s label is underlined in high contrast, not a Tonal one’s', (tester) async {
    device(tester, features: const FakeAccessibilityFeatures(highContrast: true));
    await pump(tester, onRetry: () {});
    TextDecoration? decoration(String label) => tester.widget<Text>(find.text(label)).style?.decoration;
    expect(decoration(en.copySupportDetails), TextDecoration.underline);
    expect(decoration(en.actionRetry), isNot(TextDecoration.underline));
  });

  for (final (locales, scale) in [
    (const [Locale('en', 'US')], 3.0),
    (const [Locale('he', 'IL')], 3.0),
    (const [Locale('en', 'US')], 2.0),
  ]) {
    testWidgets('fits ${scale.toInt()}00% text on a 320 dp phone, ${locales.first.languageCode}, scrolling to the rest',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      device(tester, locales: locales);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      AppConfig.debugSupportEmail = 'support@shnayimmikrah.org';
      addTearDown(() => AppConfig.debugSupportEmail = null);
      await pump(tester, onRetry: () {});
      expect(tester.takeException(), isNull);
      // Every button within the screen's width.
      for (final button in tester.widgetList<FocusableActionDetector>(find.byType(FocusableActionDetector))) {
        final rect = tester.getRect(find.byWidget(button));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -2000));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
