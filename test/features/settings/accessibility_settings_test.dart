import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/text/hebrew_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';

import '../../helpers.dart';

void main() {
  Future<ProviderContainer> open(WidgetTester tester, AppSettings settings) =>
      openRoute(tester, '/settings/accessibility', settings: settings);

  /// The quick setup named [title]: the whole card.
  Finder card(String title) => find.ancestor(of: find.text(title), matching: find.byType(MergeSemantics)).first;

  group('quick setups', () {
    // Settings far from every preset, with more than the display set.
    final before = AppSettings(
      onboardingComplete: true,
      theme: AppThemeMode.sepia,
      readingScale: 1.3,
      lineHeight: 2.4,
      wordSpacing: 2,
      showTeamim: false,
      scriptureFont: ScriptureFont.ezra,
      uiFont: UiFont.atkinson,
      joinDate: LocalDate(2026, 10, 4),
      speechRate: 0.7,
    );
    String json(AppSettings s) => jsonEncode(s.toJson());

    for (final (title, preset) in [
      ('Large print', DisplayPreset.largePrint),
      ('Dyslexia-friendly', DisplayPreset.dyslexia),
      ('High contrast', DisplayPreset.highContrast),
      ('Low vision', DisplayPreset.lowVision),
    ]) {
      testWidgets('$title, applied, shows Undo, which restores the settings exactly as they were', (tester) async {
        final c = await open(tester, before);
        // As they are when the card is tapped (Today has noted what it said).
        final was = c.read(settingsProvider);
        await tester.tap(card(title));
        await tester.pumpAndSettle();
        expect(presetActive(c.read(settingsProvider), preset), isTrue);
        expect(find.text('$title applied'), findsOneWidget);
        await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
        await tester.pumpAndSettle();
        expect(json(c.read(settingsProvider)), json(was));
        expect(presetActive(c.read(settingsProvider), preset), isFalse);
      });
    }

    testWidgets('Reset display is a text button under them, and can be undone too', (tester) async {
      final c = await open(tester, before);
      final was = c.read(settingsProvider);
      final reset = find.widgetWithText(TextButton, 'Reset display');
      expect(find.descendant(of: reset, matching: find.byIcon(Icons.restart_alt)), findsOneWidget);
      expect(tester.getTopLeft(reset).dy, greaterThan(tester.getBottomLeft(card('Low vision')).dy));
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(presetActive(c.read(settingsProvider), DisplayPreset.reset), isTrue);
      expect(c.read(settingsProvider).speechRate, 0.7, reason: 'not a display setting');
      expect(find.text('Display settings reset'), findsOneWidget);
      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();
      expect(json(c.read(settingsProvider)), json(was));
    });

    testWidgets('are cards two by two, 88 high at least', (tester) async {
      await open(tester, const AppSettings(onboardingComplete: true));
      final large = tester.getRect(card('Large print'));
      final dyslexia = tester.getRect(card('Dyslexia-friendly'));
      final contrast = tester.getRect(card('High contrast'));
      expect(large.height, greaterThanOrEqualTo(88));
      expect(dyslexia.top, large.top);
      expect(dyslexia.width, large.width);
      expect(contrast.top, greaterThan(large.bottom));
      expect(contrast.left, large.left);
      expect(find.text('Bigger, roomier text'), findsOneWidget);
    });

    testWidgets('one in force reads as selected, washed and checked', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, applyPreset(const AppSettings(onboardingComplete: true), DisplayPreset.largePrint, darkPreferred: false));
      expect(
        tester.getSemantics(card('Large print')),
        isSemantics(label: 'Large print\nBigger, roomier text', isButton: true, hasSelectedState: true, isSelected: true, hasTapAction: true),
      );
      expect(tester.getSemantics(card('Low vision')), isSemantics(isSelected: false, isButton: true));
      expect(find.descendant(of: card('Large print'), matching: find.byIcon(Icons.check_circle)), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      final context = tester.element(card('Large print'));
      final fill = tester.widget<Material>(find.descendant(of: card('Large print'), matching: find.byType(Material)).first);
      expect(fill.color, Theme.of(context).colorScheme.primaryContainer);
      handle.dispose();
    });
  });

  for (final (language, locale, normal, faster) in [
    (AppLanguage.english, 'en', 'Normal', '1.1×'),
    // The multiple a left-to-right run, so that its sign stays after it.
    (AppLanguage.hebrew, 'he', 'רגיל', '\u20661.1×\u2069'),
  ]) {
    testWidgets('the speech rate has a heading of its own, and reads relative to normal (${language.name})',
        (tester) async {
      final handle = tester.ensureSemantics();
      final l = lookupAppLocalizations(Locale(locale));
      final c = await open(tester, AppSettings(onboardingComplete: true, language: language));
      final slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();

      final heading = find.bySemanticsLabel(l.a11yGroupSpeech);
      expect(tester.getSemantics(heading), isSemantics(isHeader: true));
      expect(tester.getBottomLeft(heading).dy, lessThan(tester.getTopLeft(find.text(l.speechRate)).dy));
      expect(tester.getSemantics(slider), isSemantics(label: l.speechRate, value: normal, isSlider: true));
      expect(find.text(normal), findsOneWidget, reason: 'the value shows by its title');

      await tester.tap(find.byTooltip(l.increaseSetting(l.speechRate)));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).speechRate, closeTo(0.5, 0.001), reason: 'the setting keeps its own scale');
      expect(tester.getSemantics(slider), isSemantics(label: l.speechRate, value: faster, isSlider: true));
      expect(find.text(faster), findsOneWidget);
      handle.dispose();
    });
  }

  for (final (language, written, spoken) in [
    (AppLanguage.hebrew, 'א-דני', 'שם אדנות'),
    (AppLanguage.english, 'Ado-nai', 'Adonai'),
  ]) {
    testWidgets('the Divine Name option is written with a hyphen and spoken as a word (${language.name})',
        (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(tester, settings: AppSettings(onboardingComplete: true, language: language));
      c.read(routerProvider).go('/settings/accessibility');
      await tester.pumpAndSettle();
      final option = find.byWidgetPredicate(
        (w) => w is RadioListTile<DivineNameSpeech> && w.value == DivineNameSpeech.adonai,
      );
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();

      expect(find.descendant(of: option, matching: find.text(written)), findsOneWidget);
      final label = tester.getSemantics(option).label;
      expect(label, contains(spoken));
      expect(label, isNot(contains(written)), reason: 'a screen reader would spell out the hyphenated letters');
      handle.dispose();
    });
  }
}
