import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shnayim_mikrah/app/config.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/features/about/updates_section.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/services/recent_errors.dart';
import 'package:shnayim_mikrah/services/updates/update_core.dart';
import 'package:shnayim_mikrah/services/updates/updates.dart';
import 'package:shnayim_mikrah/ui/widgets/common.dart';
import 'package:shnayim_mikrah/ui/widgets/paper_group.dart';
import 'package:shnayim_mikrah/ui/widgets/progress_widgets.dart' show ParshaRings;
import 'package:shnayim_mikrah/ui/widgets/update_banner.dart';

import '../../helpers.dart';
import '../../services/updates/update_fixtures.dart';

/// The Windows app's updates as the reader meets them (docs/DESIGN_SYSTEM.md
/// §9 About, Updates, and Today): About's Updates, the offer on Today, the
/// install, and that a build without UPDATE_CHANNEL never asks GitHub
/// anything.
void main() {
  setUp(() => PackageInfo.setMockInitialValues(
        appName: 'Shnayim Mikrah',
        packageName: 'org.shnayimmikrah.app',
        version: '0.0.1',
        buildNumber: '1',
        buildSignature: '',
      ));
  tearDown(recentErrors.clear);

  final windows = TargetPlatformVariant.only(TargetPlatform.windows);
  // Wednesday 21 October 2026, a reading day.
  final wednesday = DateTime(2026, 10, 21, 10);
  final script = utf8.encode('# install.ps1 of v0.0.2\n');

  /// GitHub with v0.0.2, a pre-release, whose script is [scriptBytes] (its
  /// own unless given) and whose checksums are right.
  FakeUpdateHttp github({List<int>? scriptBytes, int releasesStatus = 200}) => FakeUpdateHttp({
        kReleasesApi: UpdateResponse(
          releasesStatus,
          body: utf8.encode(jsonEncode([releaseJson('v0.0.2', prerelease: true), releaseJson('v0.0.1', prerelease: true)])),
        ),
        assetUrl('v0.0.2', 'SHA256SUMS.txt'): UpdateResponse(
          200,
          body: utf8.encode('${sha256Hex(script)}  install.ps1\n${'d' * 64}  ShnayimMikrah-0.0.2-windows-x64.msi\n'),
        ),
        assetUrl('v0.0.2', 'install.ps1'): UpdateResponse(200, body: scriptBytes ?? script),
      });

  /// The Windows app on the pre-release channel, with [http] as GitHub, on
  /// [route] at [now].
  Future<(ProviderContainer, FakeInstaller, List<String>)> open(
    WidgetTester tester,
    String route, {
    required FakeUpdateHttp http,
    DateTime? now,
    AppSettings settings = const AppSettings(onboardingComplete: true),
    Map<String, Object> stored = const {},
    UpdateChannel channel = UpdateChannel.prerelease,
    double height = 1400,
  }) async {
    tester.view.physicalSize = Size(412, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final installer = FakeInstaller();
    final exits = <String>[];
    final c = await pumpApp(
      tester,
      settings: settings,
      now: now ?? wednesday,
      stored: stored,
      overrides: <Override>[
        updateChannelProvider.overrideWithValue(channel),
        updateHttpProvider.overrideWithValue(http),
        updateInstallerProvider.overrideWithValue(installer),
        updateAppExitProvider.overrideWithValue(() async => exits.add('exit')),
      ],
    );
    c.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    return (c, installer, exits);
  }

  final ready = find.text('Version 0.0.2 is ready to install');
  final install = find.widgetWithText(TextButton, 'Install');

  testWidgets('a build without UPDATE_CHANNEL never asks GitHub anything, nor shows Updates', (tester) async {
    expect(AppConfig.updateChannel, 'none', reason: 'the tests are built without it, as CI is');
    final http = github();
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The channel the build gives: none.
    final c = await pumpApp(
      tester,
      now: wednesday,
      overrides: [
        updateHttpProvider.overrideWithValue(http),
        updateInstallerProvider.overrideWithValue(FakeInstaller()),
      ],
    );
    await tester.pumpAndSettle();
    expect(c.read(updateChannelProvider), UpdateChannel.none);
    expect(c.read(updateServiceProvider), isNull);
    c.read(routerProvider).go('/settings/about');
    await tester.pumpAndSettle();
    expect(find.byType(UpdatesSection), findsOneWidget);
    expect(find.text('Check now'), findsNothing);
    expect(await c.read(updateControllerProvider.notifier).checkNow(), UpdateCheckResult.failed);
    expect(await c.read(updateControllerProvider.notifier).install(), isFalse);
    await tester.pumpAndSettle();
    expect(http.requested, isEmpty);
  }, variant: windows);

  testWidgets('nor does the app anywhere but on Windows, whatever its channel', (tester) async {
    final http = github();
    final (c, _, _) = await open(tester, '/settings/about', http: http);
    expect(c.read(updateServiceProvider), isNull);
    expect(find.text('Check now'), findsNothing);
    await c.read(updateControllerProvider.notifier).checkNow();
    expect(http.requested, isEmpty);
  });

  testWidgets('looks by itself once the app is up, and offers the new version on Today', (tester) async {
    final http = github();
    final (c, _, _) = await open(tester, '/today', http: http);
    expect(http.requested, [kReleasesApi]);
    expect(ready, findsOneWidget);
    expect(install, findsOneWidget);
    final banner = tester.widget<NoticeBanner>(find.ancestor(of: ready, matching: find.byType(NoticeBanner)));
    expect(banner.icon, Icons.system_update_alt_outlined);
    // At the top of the reading column, over the week's title page.
    expect(tester.getTopLeft(ready).dy, lessThan(tester.getTopLeft(find.byType(ParshaRings).first).dy));
    // What it found is kept, so that it is offered as the app opens again,
    // without asking again within 12 hours.
    final record = UpdateRecord.fromJson(jsonDecode(c.read(sharedPreferencesProvider).getString(UpdateRecord.storageKey)!));
    expect(record.offer?.tag, 'v0.0.2');
    expect(record.lastSuccess, wednesday);

    // Put away on Today for the session; About still offers it.
    await tester.tap(find.descendant(of: find.byType(UpdateBanner), matching: find.byTooltip('Dismiss')));
    await tester.pumpAndSettle();
    expect(ready, findsNothing);
    c.read(routerProvider).go('/settings/about');
    await tester.pumpAndSettle();
    expect(ready, findsOneWidget);
  }, variant: windows);

  testWidgets('offers again what it found, as the app opens, and doesn’t ask before 12 hours are up', (tester) async {
    final http = github();
    final found = const UpdateRecord().succeeded(
      wednesday.subtract(const Duration(hours: 2)),
      offer: Release.fromJson(releaseJson('v0.0.2', prerelease: true)),
    );
    await open(tester, '/today', http: http, stored: {UpdateRecord.storageKey: jsonEncode(found.toJson())});
    expect(ready, findsOneWidget);
    expect(http.requested, isEmpty);
  }, variant: windows);

  testWidgets('never offers the version running, nor an older one, kept from before', (tester) async {
    final http = github();
    final found = const UpdateRecord().succeeded(
      wednesday.subtract(const Duration(hours: 2)),
      offer: Release.fromJson(releaseJson('v0.0.1', prerelease: true)),
    );
    await open(tester, '/today', http: http, stored: {UpdateRecord.storageKey: jsonEncode(found.toJson())});
    expect(find.byType(UpdateBanner), findsNothing);
    expect(find.textContaining('ready to install'), findsNothing);
  }, variant: windows);

  testWidgets('never looks, nor offers, on Shabbat, nor on Friday after midday', (tester) async {
    final found = const UpdateRecord().succeeded(
      DateTime(2026, 10, 20, 9),
      offer: Release.fromJson(releaseJson('v0.0.2', prerelease: true)),
    );
    for (final now in [DateTime(2026, 10, 23, 13), DateTime(2026, 10, 24, 12), DateTime(2026, 10, 25, 2)]) {
      final http = github();
      final (c, _, _) = await open(
        tester,
        '/today',
        http: http,
        now: now,
        stored: {UpdateRecord.storageKey: jsonEncode(found.toJson())},
      );
      expect(http.requested, isEmpty, reason: '$now');
      expect(find.textContaining('ready to install'), findsNothing, reason: '$now');
      c.read(routerProvider).go('/settings/about');
      await tester.pumpAndSettle();
      expect(find.text('Updates wait until after Shabbat and Yom Tov.'), findsOneWidget, reason: '$now');
      expect(find.textContaining('ready to install'), findsNothing, reason: '$now');
      // Check now waits too.
      final checkNow = tester.widget<PaperRow>(find.widgetWithText(PaperRow, 'Check now'));
      expect(checkNow.onTap, isNull, reason: '$now');
      expect(await c.read(updateControllerProvider.notifier).checkNow(), UpdateCheckResult.quiet);
      expect(await c.read(updateControllerProvider.notifier).install(), isFalse);
      expect(http.requested, isEmpty, reason: '$now');
    }
  }, variant: windows);

  testWidgets('About, Updates: the version, Check now and the last check, What’s new and the switch', (tester) async {
    final http = github();
    final (c, _, _) = await open(
      tester,
      '/settings/about',
      http: http,
      settings: const AppSettings(onboardingComplete: true, autoUpdateCheck: false),
    );
    // Off, it hasn't looked.
    expect(http.requested, isEmpty);
    final rows = tester
        .widgetList<PaperRow>(
          find.descendant(of: find.byType(UpdatesSection), matching: find.byWidgetPredicate((w) => w is PaperRow)),
        )
        .toList();
    expect([for (final r in rows) r.title], ['This version', 'Check now', 'What’s new', 'Check automatically']);
    expect(rows[0].value, '0.0.1 (preview)');
    expect(rows[1].subtitle, 'Not checked yet');
    expect(rows[2].subtitle, 'The release notes, on GitHub');
    expect(rows[3].subtitle, 'At most twice a day, and never on Shabbat or Yom Tov');

    await tester.tap(find.text('Check now'));
    await tester.pumpAndSettle();
    expect(http.requested, [kReleasesApi]);
    expect(ready, findsOneWidget);
    expect(tester.widget<PaperRow>(find.widgetWithText(PaperRow, 'Check now')).subtitle, 'Last checked just now');

    // The switch is the setting.
    await tester.tap(find.text('Check automatically'));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).autoUpdateCheck, isTrue);
    expect(AppSettings.fromJson(c.read(settingsProvider).toJson()).autoUpdateCheck, isTrue);
  }, variant: windows);

  testWidgets('Check now says when this is the latest version', (tester) async {
    final http = FakeUpdateHttp({
      kReleasesApi: UpdateResponse(200, body: utf8.encode(jsonEncode([releaseJson('v0.0.1', prerelease: true)]))),
    });
    await open(
      tester,
      '/settings/about',
      http: http,
      settings: const AppSettings(onboardingComplete: true, autoUpdateCheck: false),
    );
    await tester.tap(find.text('Check now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('This is the latest version.'), findsOneWidget);
    expect(find.textContaining('ready to install'), findsNothing);
  }, variant: windows);

  testWidgets('a check that fails says so calmly, with Copy details for support', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final http = github(releasesStatus: 500);
    await open(
      tester,
      '/settings/about',
      http: http,
      settings: const AppSettings(onboardingComplete: true, autoUpdateCheck: false),
    );
    await tester.tap(find.text('Check now'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t check for updates. Please try again later.'), findsOneWidget);
    final copy = find.widgetWithText(TextButton, 'Copy details for support');
    expect(copy, findsOneWidget);
    await tester.tap(copy);
    await tester.pump();
    expect(copied, contains('Shnayim Mikrah 0.0.1 (1) on windows'));
    expect(copied, contains('UpdateException(httpStatus): HTTP 500 from api.github.com'));
    expect(copied, contains('while checking for updates'));
  }, variant: windows);

  testWidgets('Install asks, downloads and checks the script, starts it, saves, and closes the app', (tester) async {
    final http = github();
    final (c, installer, exits) = await open(tester, '/today', http: http);
    // A change the settings are holding back.
    c.read(settingsProvider.notifier).update((s) => s.copyWith(showStreaks: false));
    await tester.tap(install);
    await tester.pumpAndSettle();
    expect(find.text('Install version 0.0.2?'), findsOneWidget);
    expect(
      find.text('Shnayim Mikrah will close, install the new version and open again. Your reading and settings stay as they are.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Install'));
    // The app closes as the spinner turns: it never settles.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(installer.started, [('v0.0.2', script)]);
    expect(http.requested.skip(1), [assetUrl('v0.0.2', 'SHA256SUMS.txt'), assetUrl('v0.0.2', 'install.ps1')]);
    expect(exits, ['exit']);
    final saved = AppSettings.fromJson(
      jsonDecode(c.read(sharedPreferencesProvider).getString(SettingsController.storageKey)!) as Map<String, dynamic>,
    );
    expect(saved.showStreaks, isFalse, reason: 'saved before the app closes');
  }, variant: windows);

  testWidgets('Cancel installs nothing', (tester) async {
    final http = github();
    final (_, installer, exits) = await open(tester, '/today', http: http);
    await tester.tap(install);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(installer.started, isEmpty);
    expect(exits, isEmpty);
    expect(http.requested, [kReleasesApi]);
  }, variant: windows);

  testWidgets('a script that isn’t the one listed is never run, and Today says so, with Copy details and Try again',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final http = github(scriptBytes: utf8.encode('Remove-Item -Recurse \$HOME'));
    final (_, installer, exits) = await open(tester, '/today', http: http);
    await tester.tap(install);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Install'));
    await tester.pumpAndSettle();
    expect(installer.started, isEmpty);
    expect(exits, isEmpty);
    final failed = find.text('The update couldn’t be prepared, and nothing was changed.');
    expect(failed, findsOneWidget);
    expect(ready, findsNothing, reason: 'in its place');
    expect(tester.widget<NoticeBanner>(find.ancestor(of: failed, matching: find.byType(NoticeBanner))).liveRegion, isTrue);

    await tester.tap(find.widgetWithText(TextButton, 'Copy details for support'));
    await tester.pump();
    expect(copied, contains('UpdateException(checksumMismatch): install.ps1 has SHA-256'));
    expect(copied, contains('while preparing the update to v0.0.2'));
    await tester.pumpAndSettle();

    // Again, it asks GitHub again, and still runs nothing.
    await tester.tap(find.widgetWithText(TextButton, 'Try again'));
    await tester.pumpAndSettle();
    expect(http.requested.where((u) => u == assetUrl('v0.0.2', 'install.ps1')), hasLength(2));
    expect(installer.started, isEmpty);
    expect(failed, findsOneWidget);
  }, variant: windows);

  testWidgets('says “Preparing the update…” while it downloads', (tester) async {
    final http = github();
    final (c, installer, _) = await open(tester, '/settings/about', http: http);
    http.hold = Completer<void>();
    unawaited(c.read(updateControllerProvider.notifier).install());
    await tester.pump();
    expect(find.text('Preparing the update…'), findsOneWidget);
    expect(install, findsNothing);
    http.hold!.complete();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(installer.started, hasLength(1));
  }, variant: windows);

  testWidgets('in Hebrew, About’s Updates and the offer read in Hebrew, the version left to right', (tester) async {
    final http = github();
    await open(
      tester,
      '/settings/about',
      http: http,
      settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew),
    );
    expect(find.text('גרסה \u20660.0.2\u2069 מוכנה להתקנה'), findsOneWidget);
    expect(find.text('בדיקה עכשיו'), findsOneWidget);
    expect(find.text('בדיקה אוטומטית'), findsOneWidget);
    final version = tester.widget<PaperRow>(find.widgetWithText(PaperRow, 'הגרסה הזו'));
    expect(version.value, '\u20660.0.1\u2069 (גרסה מקדימה)');
  }, variant: windows);
}
