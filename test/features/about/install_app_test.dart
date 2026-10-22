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
  FakeWebInstall({this.canPrompt = false, this.standalone = false, this.outcome = InstallOutcome.accepted});

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
      expect(options(TargetPlatform.android, canPrompt: true), [InstallOption.prompt, InstallOption.apk]);
      expect(options(TargetPlatform.android), [InstallOption.apk]);
      expect(options(TargetPlatform.iOS), [InstallOption.homeScreenSteps]);
      // An iPhone's browsers have no dialog the app can open.
      expect(options(TargetPlatform.iOS, canPrompt: true), [InstallOption.homeScreenSteps]);
      expect(options(TargetPlatform.windows, canPrompt: true), [InstallOption.prompt, InstallOption.windows]);
      expect(options(TargetPlatform.windows), [InstallOption.windows]);
      expect(options(TargetPlatform.macOS, canPrompt: true), [InstallOption.prompt]);
      expect(options(TargetPlatform.linux), isEmpty);
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

  testWidgets('on Android, About offers Add to home screen, which asks the browser, and the APK', (tester) async {
    final install = FakeWebInstall(canPrompt: true);
    await open(tester, '/settings/about', install: install);
    expect(find.text('Install the app'), findsOneWidget);
    final group = find.ancestor(of: find.text('Add to home screen'), matching: find.byType(PaperGroup));
    expect(rowTitles(tester, group), ['Add to home screen', 'Android app (APK)']);
    final add = tester.widget<PaperRow>(find.widgetWithText(PaperRow, 'Add to home screen'));
    expect(add.subtitle, 'Opens from your home screen, like any app');
    expect(add.chevron, isFalse, reason: 'it does what it says, in place');
    expect(tester.widget<PaperRow>(find.widgetWithText(PaperRow, 'Android app (APK)')).subtitle, 'Opens this website as an app');

    await tester.tap(find.text('Add to home screen'));
    await tester.pumpAndSettle();
    expect(install.prompts, 1);
    // Installed: nothing more is offered.
    expect(find.text('Install the app'), findsNothing);
    expect(find.text('Android app (APK)'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the browser’s offer, coming later, is offered as it comes', (tester) async {
    final install = FakeWebInstall();
    await open(tester, '/settings/about', install: install);
    expect(find.text('Add to home screen'), findsNothing);
    expect(find.text('Android app (APK)'), findsOneWidget);
    install.offer();
    await tester.pumpAndSettle();
    expect(find.text('Add to home screen'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Settings’ Install the app opens the ways in a sheet, which makes way for the APK’s', (tester) async {
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
    expect(rowTitles(tester, find.byType(BottomSheet)), ['Add to home screen', 'Android app (APK)']);

    await tester.tap(find.text('Android app (APK)'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget, reason: 'in place of the first');
    expect(find.text('Install the app'), findsOneWidget, reason: 'the row beneath, not the sheet');
    expect(find.textContaining('opens this website as an app, with an icon of its own'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Open the releases page'), findsOneWidget);
    expect(kReleasesPage, Uri.parse('https://github.com/Shnayim-Mikrah-V-Echad-Targum/app/releases'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('on an iPhone, Today offers it once, with Safari’s steps, and put away it stays away', (tester) async {
    final install = FakeWebInstall();
    final c = await open(tester, '/today', install: install);
    expect(card, findsOneWidget);
    expect(tester.widget<NoticeBanner>(find.ancestor(of: card, matching: find.byType(NoticeBanner))).icon, Icons.install_mobile);

    await tester.tap(find.widgetWithText(TextButton, 'Install'));
    await tester.pumpAndSettle();
    expect(find.text('Add to Home Screen'), findsOneWidget);
    for (final step in [
      'Tap Share in Safari’s toolbar, or in its More menu if it isn’t there.',
      'Choose “Add to Home Screen”, scrolling down if you need to.',
      'Tap Add. Shnayim Mikrah is now on your home screen.',
    ]) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.textContaining('keeps its own reading'), findsOneWidget);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.ancestor(of: card, matching: find.byType(NoticeBanner)), matching: find.byTooltip('Dismiss')));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(c.read(sharedPreferencesProvider).getBool(InstallCardDismissed.storageKey), isTrue);
    // About still offers the steps.
    c.read(routerProvider).go('/settings/about');
    await tester.pumpAndSettle();
    expect(find.text('Add to Home Screen'), findsOneWidget);
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
    expect(rowTitles(tester, group), ['Install on this computer', 'Windows app']);
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
