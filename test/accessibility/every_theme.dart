/// What semantics_invariants_test.dart and semantics_invariants_pages_test.dart
/// share: opening a route, and checking it in each of the five themes. The
/// pages are split between the two files because flutter test runs files in
/// parallel and the tests within a file one after another: in one file they
/// took about a minute, and the whole run waited on them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';

import '../helpers.dart';
import 'routes.dart';
import 'semantics_invariants.dart';

/// The five themes, in which every page is checked.
const themes = [
  AppThemeMode.light,
  AppThemeMode.dark,
  AppThemeMode.sepia,
  AppThemeMode.highContrastLight,
  AppThemeMode.highContrastDark,
];

/// What every page meets in every theme.
const guidelines = [semanticsInvariants, textContrastGuideline, androidTapTargetGuideline, labeledTapTargetGuideline];

/// The first half of [a11yRoutes], which semantics_invariants_test.dart
/// shows in every theme. semantics_invariants_pages_test.dart shows the rest,
/// [a11yRoutesSecondHalf], with the reader, onboarding and the pages that
/// need more than opening.
final a11yRoutesFirstHalf = a11yRoutes.sublist(0, _half);

/// The rest of [a11yRoutes], after [a11yRoutesFirstHalf].
final a11yRoutesSecondHalf = a11yRoutes.sublist(_half);

/// Rounded up: the second file has more besides, so the first takes the
/// middle route of an odd number. Each file then takes about half a minute.
final _half = (a11yRoutes.length + 1) ~/ 2;

/// Opens [route], waiting for texts to load (a spinner never settles).
Future<ProviderContainer> open(
  WidgetTester tester,
  String route, {
  AppSettings settings = a11ySettings,
  DateTime? now,
  ProgressState? progress,
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(tester, settings: settings, now: now ?? a11yMonday, progress: progress);
  c.read(routerProvider).go(route);
  await tester.pump();
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
    if (i >= 3 && find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return c;
}

/// Shows the page in each of [themes] and runs the [guidelines] on it,
/// reporting every failure at once, by theme.
Future<void> expectInEveryTheme(
  WidgetTester tester,
  ProviderContainer c, {
  List<AppThemeMode> themes = themes,
}) async {
  final failures = <String>[];
  for (final theme in themes) {
    c.read(settingsProvider.notifier).update((s) => s.copyWith(theme: theme));
    await tester.pumpAndSettle();
    for (final guideline in guidelines) {
      final result = await guideline.evaluate(tester);
      if (!result.passed) failures.add('${theme.name}: ${guideline.description}\n${result.reason}');
    }
  }
  expect(failures, isEmpty, reason: failures.join('\n\n'));
}
