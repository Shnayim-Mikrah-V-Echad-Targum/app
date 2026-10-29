import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/core/text/hebrew_pronunciation.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/services/hebrew_voice/hebrew_voice.dart';
import 'package:shnayim_mikrah/services/hebrew_voice/voice_catalogue.dart';
import 'package:shnayim_mikrah/services/hebrew_voice/voice_settings.dart';
import 'package:shnayim_mikrah/services/hebrew_voice/voice_store.dart';

import '../../helpers.dart';

/// The voices' files in memory: fetched at once.
class _Store implements VoiceStore {
  final files = <VoiceFile>{};

  @override
  Future<bool> has(VoiceFile file) async => files.contains(file);

  @override
  Future<void> fetch(List<VoiceFile> wanted, {required void Function(int received, int total) onProgress}) async {
    files.addAll(wanted);
    onProgress(1, 1);
  }

  @override
  Future<void> remove(VoiceFile file) async => files.remove(file);

  @override
  Future<String> location(VoiceFile file) async => file.path;

  @override
  Future<Uint8List> read(VoiceFile file) async => Uint8List(0);
}

void main() {
  Future<(ProviderContainer, _Store)> open(WidgetTester tester, String route, {VoiceSettings voice = const VoiceSettings()}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = _Store();
    final c = await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, voice: voice),
      overrides: [hebrewVoicesProvider.overrideWith((ref) => HebrewVoices(store: store))],
    );
    c.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    return (c, store);
  }

  testWidgets('Accessibility names who reads the Torah, and opens the page of the voices', (tester) async {
    final (c, _) = await open(tester, '/settings/accessibility');
    final row = find.text('Hebrew voice');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(find.text('Michael isn’t downloaded: your device’s voice reads meanwhile'), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).state.uri.path, '/settings/accessibility/voice');
    expect(find.text('The Torah'), findsOneWidget);
  });

  testWidgets('a tradition sets every sound, and a sound set by hand makes it your own', (tester) async {
    final (c, _) = await open(tester, '/settings/accessibility/voice');
    final lithuanian = find.text('Lithuanian');
    await tester.ensureVisible(lithuanian);
    await tester.pumpAndSettle();
    await tester.tap(lithuanian);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).voice.pronunciation.preset, HebrewPronunciationPreset.lithuanian);
    await tester.ensureVisible(find.text('Tav without a dagesh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('t').last);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).voice.pronunciation.preset, isNull);
    expect(find.text('Your own'), findsOneWidget);
  });

  testWidgets('a voice chosen for the Targum is fetched and reads it; the Torah\'s voice by default', (tester) async {
    final (c, store) = await open(tester, '/settings/accessibility/voice/targum');
    expect(find.text('Voice for the Targum'), findsOneWidget);
    expect(find.text('Same as the Torah'), findsOneWidget);
    final noa = find.text('Noa');
    await tester.ensureVisible(noa);
    await tester.pumpAndSettle();
    await tester.tap(noa);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).voice.targum, 'noa');
    expect(store.files, containsAll(hebrewVoiceById('noa')!.files));
    expect(c.read(hebrewVoicesProvider).ready('noa'), isTrue);
    expect(find.text('Noa is ready'), findsOneWidget);
    expect(c.read(settingsProvider).voice.torah, kDefaultHebrewVoice, reason: 'the Torah keeps its own');
  });

  testWidgets('a voice on the device is taken off from its menu', (tester) async {
    final (c, store) = await open(tester, '/settings/accessibility/voice/mikrah');
    final voices = c.read(hebrewVoicesProvider);
    await voices.install(kDefaultHebrewVoice);
    await tester.pumpAndSettle();
    final more = find.byTooltip('More for Michael').first;
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from this device'));
    await tester.pumpAndSettle();
    expect(voices.ready(kDefaultHebrewVoice), isFalse);
    expect(store.files, isEmpty);
  });
}
