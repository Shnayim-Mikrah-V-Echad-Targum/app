import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/core/text/hebrew_text.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/features/settings/widgets/settings_widgets.dart';
import 'package:shnayim_mikrah/l10n/app_localizations.dart';
import 'package:shnayim_mikrah/ui/theme/motion.dart';

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

    testWidgets('applied from the keyboard, a later Undo takes back the preset alone', (tester) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final c = await open(tester, before);
      final was = c.read(settingsProvider);
      await tester.tap(card('Low vision'));
      await tester.pumpAndSettle();
      expect(find.text('Low vision applied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(find.widgetWithText(SnackBarAction, 'Undo'), findsOneWidget, reason: 'held for the keyboard');

      // Changed since, the message still showing: Reduce motion on this
      // page, and the text size the preset set.
      await tester.ensureVisible(find.widgetWithText(SwitchRow, 'Reduce motion'));
      await tester.tap(find.widgetWithText(SwitchRow, 'Reduce motion'));
      await tester.pumpAndSettle();
      c.read(settingsProvider.notifier).update((s) => s.copyWith(readingScale: 2.2));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();
      final now = c.read(settingsProvider);
      expect(now.reduceMotion, isTrue, reason: 'a setting the preset leaves alone, changed since');
      expect(now.readingScale, 2.2, reason: 'changed since the preset set it');
      expect((now.theme, now.lineHeight, now.boldText, now.focusMode, now.lineWidth),
          (was.theme, was.lineHeight, was.boldText, was.focusMode, was.lineWidth),
          reason: 'what the preset alone set is as it was');
    });

    testWidgets('applied from the keyboard, its Undo leaves with the page', (tester) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final c = await open(tester, before);
      await tester.tap(card('Low vision'));
      await tester.pumpAndSettle();
      expect(find.text('Low vision applied'), findsOneWidget);

      // Back to Settings, where the reading plan, the reminders and the rest
      // are a tap away: an Undo there could take back changes made in them.
      c.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(c.read(routerProvider).state.uri.path, '/settings');
      expect(find.text('Low vision applied'), findsNothing);
      expect(find.widgetWithText(SnackBarAction, 'Undo'), findsNothing);
    });

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

  group("Reduce motion, while the device's is on", () {
    final row = find.widgetWithText(SwitchRow, 'Reduce motion');
    Switch toggle(WidgetTester tester) =>
        tester.widget<Switch>(find.descendant(of: row, matching: find.byType(Switch)));

    /// Turns the device's own Reduce motion on or off.
    Future<void> device(WidgetTester tester, {required bool reduced}) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduced);
      await tester.pumpAndSettle();
    }

    testWidgets('shows it on and disabled, saying that the device has it on', (tester) async {
      final handle = tester.ensureSemantics();
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final c = await open(tester, const AppSettings(onboardingComplete: true));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(toggle(tester).value, isTrue, reason: 'in force, though the app’s own is off');
      expect(toggle(tester).onChanged, isNull);
      expect(find.descendant(of: row, matching: find.text('On in your device’s settings')), findsOneWidget);
      expect(find.text('Turn off animations and moving celebrations'), findsNothing);
      expect(
        tester.getSemantics(row),
        isSemantics(
          label: 'Reduce motion\nOn in your device’s settings',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).reduceMotion, isFalse);

      // The device's turned off: the app's own setting again, to change.
      await device(tester, reduced: false);
      expect(toggle(tester).value, isFalse);
      expect(toggle(tester).onChanged, isNotNull);
      expect(find.descendant(of: row, matching: find.text('Turn off animations and moving celebrations')), findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).reduceMotion, isTrue);
      handle.dispose();
    });

    testWidgets("on iOS, where it is the device's Reduce Motion, shows it on and reduces the app's motion",
        (tester) async {
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await open(tester, const AppSettings(onboardingComplete: true));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(Motion.of(tester.element(row)).reduced, isFalse);
      // iOS reports Reduce Motion as a feature of its own, and not as
      // disableAnimations.
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      await tester.pumpAndSettle();
      expect(toggle(tester).value, isTrue);
      expect(toggle(tester).onChanged, isNull);
      expect(find.descendant(of: row, matching: find.text('On in your device’s settings')), findsOneWidget);
      expect(Motion.of(tester.element(row)).reduced, isTrue, reason: 'in force for the app');

      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
      await tester.pumpAndSettle();
      expect(toggle(tester).value, isFalse);
      expect(toggle(tester).onChanged, isNotNull);
      expect(Motion.of(tester.element(row)).reduced, isFalse);
    });

    testWidgets("is shown as it turns on with the app's own already on", (tester) async {
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await open(tester, const AppSettings(onboardingComplete: true, reduceMotion: true));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(toggle(tester).value, isTrue);
      expect(toggle(tester).onChanged, isNotNull);
      await device(tester, reduced: true);
      expect(toggle(tester).value, isTrue);
      expect(toggle(tester).onChanged, isNull, reason: 'the app’s motion was already reduced; the switch still hears of it');
      expect(find.descendant(of: row, matching: find.text('On in your device’s settings')), findsOneWidget);
    });
  });
}
