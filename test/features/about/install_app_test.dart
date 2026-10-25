import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/services/web_install.dart';
import 'package:shnayim_mikrah/ui/widgets/common.dart';
import 'package:shnayim_mikrah/ui/widgets/paper_group.dart';

import '../../helpers.dart';

/// The browser's offer to install, as web/index.html keeps it: [canPrompt]
/// until made, then [outcome]; [standalone] where the app runs installed.
class FakeWebInstall extends WebInstall {
  FakeWebInstall({
    this.canPrompt = false,
    this.standalone = false,
    this.outcome = InstallOutcome.accepted,
    this.userAgent = '',
  });

  /// The user agent the browser gives, for the guide's choice of browser.
  final String userAgent;

  @override
  InstallBrowser? get browser => browserFrom(userAgent);


  @override
  bool canPrompt;

  @override
  bool standalone;

  @override
  bool installed = false;

  InstallOutcome outcome;
  int prompts = 0;
  final listeners = <void Function()>[];

  @override
  Future<InstallOutcome> prompt() async {
    if (!canPrompt) return InstallOutcome.unavailable;
    prompts++;
    canPrompt = false;
    if (outcome == InstallOutcome.accepted) installed = true;
    return outcome;
  }

  @override
  void Function() listen(void Function() onChange) {
    listeners.add(onChange);
    return () => listeners.remove(onChange);
  }

  /// The browser's beforeinstallprompt, as it comes later.
  void offer() {
    canPrompt = true;
    for (final listener in [...listeners]) {
      listener();
    }
  }
}

/// The web's ways to install the app (docs/DESIGN_SYSTEM.md §9 About,
/// Install the app, and Today): in About, in Settings, in their sheets, and
/// Today's card on a phone; none off the web, nor in the app installed.
void main() {
  group('the ways to install', () {
    test('are the browser’s dialog where it offers one, and the device’s own way', () {
      List<InstallOption> options(TargetPlatform platform, {bool canPrompt = false}) =>
          installOptionsFor(platform, standalone: false, installed: false, canPrompt: canPrompt);
      expect(options(TargetPlatform.android, canPrompt: true), [InstallOption.prompt, InstallOption.guide]);
      expect(options(TargetPlatform.android), [InstallOption.guide]);
      expect(options(TargetPlatform.iOS), [InstallOption.guide]);
      // An iPhone's browsers have no dialog the app can open.
      expect(options(TargetPlatform.iOS, canPrompt: true), [InstallOption.guide]);
      expect(options(TargetPlatform.windows, canPrompt: true), [InstallOption.prompt, InstallOption.guide, InstallOption.windows]);
      expect(options(TargetPlatform.windows), [InstallOption.guide, InstallOption.windows]);
      expect(options(TargetPlatform.macOS, canPrompt: true), [InstallOption.prompt, InstallOption.guide]);
      expect(options(TargetPlatform.linux), [InstallOption.guide]);
    });

    test('are none where the app runs installed, or has just been', () {
      for (final platform in TargetPlatform.values) {
        expect(installOptionsFor(platform, standalone: true, installed: false, canPrompt: true), isEmpty);
        expect(installOptionsFor(platform, standalone: false, installed: true, canPrompt: true), isEmpty);
      }
    });

    test('are none off the web', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(webInstallProvider), isNull);
      expect(container.read(installOptionsProvider), isEmpty);
    });
  });

  Future<ProviderContainer> open(
    WidgetTester tester,
    String route, {
    FakeWebInstall? install,
    double width = 412,
    AppLanguage language = AppLanguage.english,
    Map<String, Object> stored = const {},
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, language: language),
      now: captureNow,
      stored: stored,
      overrides: [if (install != null) webInstallProvider.overrideWithValue(install)],
    );
    c.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    return c;
  }

  List<String> rowTitles(WidgetTester tester, Finder within) => [
        for (final row in tester.widgetList<PaperRow>(find.descendant(of: within, matching: find.byType(PaperRow))))
          row.title,
      ];

  final card = find.text('Add Shnayim Mikrah to your home screen, and open it like any app.');

  // A chip of the guide, by its label.
  ChoiceChip chip(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)));

  testWidgets('off the web, nothing offers to install the app', (tester) async {
    final c = await open(tester, '/today');
    expect(card, findsNothing);
    c.read(routerProvider).go('/settings/about');
    await tester.pumpAndSettle();
    expect(find.text('Install the app'), findsNothing);
    c.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    expect(find.text('Install the app'), findsNothing);
  });

  testWidgets('nor does anything in the app installed from the web', (tester) async {
    final install = FakeWebInstall(canPrompt: true, standalone: true);
    final c = await open(tester, '/today', install: install);
    expect(card, findsNothing);
    c.read(routerProvider).go('/settings/about');
    await tester.pumpAndSettle();
    expect(find.text('Install the app'), findsNothing);
    c.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    expect(find.text('Install the app'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('on Android, About offers Add to home screen, which asks the browser, and the guide', (tester) async {
    final install = FakeWebInstall(canPrompt: true);
    await open(tester, '/settings/about', install: install);
    expect(find.text('Install the app'), findsOneWidget);
    final group = find.ancestor(of: find.text('Add to home screen'), matching: find.byType(PaperGroup));
    expect(rowTitles(tester, group), ['Add to home screen', 'Save as an app']);
    final add = tester.widget<PaperRow>(find.widgetWithText(PaperRow, 'Add to home screen'));
    expect(add.subtitle, 'Opens from your home screen, like any app');
    expect(add.chevron, isFalse, reason: 'it does what it says, in place');
    expect(tester.widget<PaperRow>(find.widgetWithText(PaperRow, 'Save as an app')).subtitle, 'Step by step, in the browser you use');
    expect(find.text('Android app (APK)'), findsNothing, reason: 'not offered until it is ready');

    await tester.tap(find.text('Add to home screen'));
    await tester.pumpAndSettle();
    expect(install.prompts, 1);
    // Installed: nothing more is offered.
    expect(find.text('Install the app'), findsNothing);
    expect(find.text('Save as an app'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the browser’s offer, coming later, is offered as it comes', (tester) async {
    final install = FakeWebInstall();
    await open(tester, '/settings/about', install: install);
    expect(find.text('Add to home screen'), findsNothing);
    expect(find.text('Save as an app'), findsOneWidget);
    install.offer();
    await tester.pumpAndSettle();
    expect(find.text('Add to home screen'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Settings’ Install the app opens the ways in a sheet, which makes way for the guide', (tester) async {
    final install = FakeWebInstall(canPrompt: true);
    await open(tester, '/settings', install: install);
    final row = find.widgetWithText(PaperRow, 'Install the app');
    expect(row, findsOneWidget);
    expect(tester.widget<PaperRow>(row).subtitle, 'Open Shnayim Mikrah like any other app');
    // In the About group, after About.
    expect(tester.getTopLeft(row).dy, greaterThan(tester.getTopLeft(find.text('About this app')).dy));

    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(rowTitles(tester, find.byType(BottomSheet)), ['Add to home screen', 'Save as an app']);

    await tester.tap(find.text('Save as an app'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget, reason: 'in place of the first');
    expect(find.text('Install the app'), findsOneWidget, reason: 'the row beneath, not the sheet');
    expect(find.text('Save Shnayim Mikrah as an app'), findsOneWidget);
    // On Android, in Chrome, as the browser says it is.
    expect(chip(tester, 'Android').selected, isTrue);
    expect(chip(tester, 'Chrome').selected, isTrue);
    expect(find.text('Tap More (⋮) beside the address bar.'), findsOneWidget);
    expect(find.textContaining('Where only a shortcut is offered'), findsOneWidget);
    expect(kReleasesPage, Uri.parse('https://github.com/Shnayim-Mikrah-V-Echad-Targum/app/releases'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the guide opens at the browser in use, and has each browser’s steps on each device', (tester) async {
    final install = FakeWebInstall(userAgent: 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/25.0 Chrome/121.0 Mobile Safari/537.36');
    await open(tester, '/settings/about', install: install);
    await tester.tap(find.text('Save as an app'));
    await tester.pumpAndSettle();
    expect(chip(tester, 'Samsung Internet').selected, isTrue);
    expect(find.text('Tap “Add page to”, then “Home screen”.'), findsOneWidget);

    await tester.tap(find.text('Firefox'));
    await tester.pumpAndSettle();
    expect(find.text('Tap “Add app to Home screen” (or “Install”).'), findsOneWidget);

    // On an iPhone, Samsung Internet isn't offered: the iPhone's own comes first.
    await tester.tap(find.text('iPhone / iPad'));
    await tester.pumpAndSettle();
    expect(find.text('Samsung Internet'), findsNothing);
    expect(chip(tester, 'Firefox').selected, isTrue, reason: 'Firefox is there too');
    expect(find.text('Tap the menu (☰).'), findsOneWidget);
    expect(find.textContaining('iOS 16.4 or later'), findsOneWidget);
    expect(find.textContaining('keeps its own reading'), findsOneWidget);

    // Firefox on a computer saves no site as an app, and says where to.
    await tester.tap(find.text('Computer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Firefox on a computer doesn’t save sites as apps'), findsOneWidget);
    await tester.tap(find.text('Edge'));
    await tester.pumpAndSettle();
    expect(find.textContaining('“Install this site as an app”'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test('the browser is told by its own token in the user agent', () {
    const ua = {
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1': InstallBrowser.safari,
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/130.0 Mobile/15E148 Safari/604.1': InstallBrowser.chrome,
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/132.0 Mobile/15E148 Safari/605.1.15': InstallBrowser.firefox,
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) EdgiOS/130.0 Version/18.0 Mobile/15E148 Safari/604.1': InstallBrowser.edge,
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 DuckDuckGo/7 Safari/605.1.15': InstallBrowser.duckDuckGo,
      'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36': InstallBrowser.chrome,
      'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36 EdgA/130.0': InstallBrowser.edge,
      'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36 OPR/85.0': InstallBrowser.opera,
      'Mozilla/5.0 (Android 14; Mobile; rv:132.0) Gecko/132.0 Firefox/132.0': InstallBrowser.firefox,
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36 Edg/130.0': InstallBrowser.edge,
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15': InstallBrowser.safari,
    };
    for (final MapEntry(key: agent, value: browser) in ua.entries) {
      expect(browserFrom(agent), browser, reason: agent);
    }
    // Brave says so only by navigator.brave.
    expect(browserFrom(ua.keys.elementAt(5), brave: true), InstallBrowser.brave);
    expect(browserFrom(''), isNull);
    for (final device in InstallDevice.values) {
      expect(browsersOn(device), isNotEmpty);
    }
  });

  testWidgets('on an iPhone, Today offers it once, with Safari’s steps, and put away it stays away', (tester) async {
    final install = FakeWebInstall();
    final c = await open(tester, '/today', install: install);
    expect(card, findsOneWidget);
    expect(tester.widget<NoticeBanner>(find.ancestor(of: card, matching: find.byType(NoticeBanner))).icon, Icons.install_mobile);

    await tester.tap(find.widgetWithText(TextButton, 'Install'));
    await tester.pumpAndSettle();
    expect(find.text('Save Shnayim Mikrah as an app'), findsOneWidget);
    expect(chip(tester, 'iPhone / iPad').selected, isTrue);
    expect(chip(tester, 'Safari').selected, isTrue);
    for (final step in [
      'Tap Share in Safari’s toolbar, or in its More menu (⋯) if it isn’t there.',
      'Choose “Add to Home Screen”, scrolling down if you need to.',
      'Tap Add. Shnayim Mikrah is now on your home screen.',
    ]) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.textContaining('keeps its own reading'), findsOneWidget);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(card, findsOneWidget, reason: 'closed, the guide leaves the card');

    await tester.tap(find.widgetWithText(TextButton, 'Install'));
    await tester.pumpAndSettle();
    final done = find.text('Done — don’t show again');
    await tester.ensureVisible(done);
    await tester.pumpAndSettle();
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(find.text('Save Shnayim Mikrah as an app'), findsNothing);
    expect(card, findsNothing);
    expect(c.read(sharedPreferencesProvider).getBool(InstallCardDismissed.storageKey), isTrue);
    // About still offers the guide.
    c.read(routerProvider).go('/settings/about');
    await tester.pumpAndSettle();
    expect(find.text('Save as an app'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('put away, the card never comes back', (tester) async {
    await open(tester, '/today', install: FakeWebInstall(), stored: {InstallCardDismissed.storageKey: true});
    expect(card, findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Today’s card is for a phone-sized screen alone, and its Install asks the browser where it can',
      (tester) async {
    final install = FakeWebInstall(canPrompt: true);
    await open(tester, '/today', install: install, width: 800);
    expect(card, findsNothing);
    await open(tester, '/today', install: install);
    expect(card, findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Install'));
    await tester.pumpAndSettle();
    expect(install.prompts, 1);
    expect(card, findsNothing, reason: 'installed');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('on Windows, the Windows app’s one line, to copy, and the releases page for the MSI', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final install = FakeWebInstall(canPrompt: true);
    await open(tester, '/settings/about', install: install, width: 1000);
    final group = find.ancestor(of: find.text('Windows app'), matching: find.byType(PaperGroup));
    expect(rowTitles(tester, group), ['Install on this computer', 'Save as an app', 'Windows app']);
    expect(tester.widget<PaperRow>(find.widgetWithText(PaperRow, 'Install on this computer')).subtitle,
        'Opens in a window of its own, like any app');

    await tester.tap(find.text('Windows app'));
    await tester.pumpAndSettle();
    const line =
        'Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://shnayimmikrah.org/install.ps1 | iex';
    expect(kWindowsInstallCommand, line);
    expect(find.text(line), findsOneWidget);
    expect(find.textContaining('Open PowerShell, paste this line and press Enter.'), findsOneWidget);
    expect(find.text('Or download the installer (MSI) from the releases page.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Open the releases page'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Copy'));
    await tester.pump();
    expect(copied, line);
    expect(find.widgetWithText(TextButton, 'Copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.widgetWithText(TextButton, 'Copy'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('in Hebrew, the ways read in Hebrew, and the line to paste reads left to right', (tester) async {
    await open(tester, '/settings/about', install: FakeWebInstall(), language: AppLanguage.hebrew, width: 1000);
    expect(find.text('התקנת האפליקציה'), findsOneWidget);
    await tester.tap(find.text('אפליקציה ל־Windows'));
    await tester.pumpAndSettle();
    final line = find.text(kWindowsInstallCommand);
    expect(Directionality.of(tester.element(line)), TextDirection.ltr);
    expect(find.text('העתקה'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
