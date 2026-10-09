import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

import '../helpers.dart';

/// Widgets that used to pick ad hoc or seeded colours now read the tokens.
void main() {
  for (final (mode, scheme, status) in [
    (AppThemeMode.light, Palettes.light, Palettes.statusLight),
    (AppThemeMode.highContrastDark, Palettes.hcDark, Palettes.statusHcDark),
  ]) {
    testWidgets('${mode.name}: week strip and status badge colours', (tester) async {
      await pumpApp(tester, settings: AppSettings(onboardingComplete: true, theme: mode));
      final context = tester.element(find.byType(Scaffold).first);

      Color? iconColor(DayDisplay d) => (d.icon(context) as Icon).color;
      // outlineVariant was about 1.5:1, too faint to read as a day at all.
      expect(iconColor(DayDisplay.upcoming), scheme.outline);
      expect(iconColor(DayDisplay.noReading), scheme.outline);
      expect(iconColor(DayDisplay.missed), status.neutral);
      expect(iconColor(DayDisplay.grace), status.grace);

      // A week still open after its Shabbat is gold ink; finishing late is
      // a quieter blue, so the two no longer share a colour.
      expect(WeekStatusBadge.color(context, WeekStatus.overdue), status.overdue);
      expect(WeekStatusBadge.color(context, WeekStatus.late), status.late);
      expect(status.overdue, isNot(status.late));
    });
  }

  testWidgets('the demo notice is a gold-ink notice, not a tertiary strip', (tester) async {
    final c = await pumpApp(tester);
    c.read(routerProvider).go('/community');
    await tester.pumpAndSettle();
    final strip = tester.widget<Container>(
      find.ancestor(of: find.textContaining('Demo mode'), matching: find.byType(Container)).first,
    );
    expect(strip.color, Palettes.light.secondaryContainer);
    final text = tester.widget<Text>(find.textContaining('Demo mode'));
    expect(text.style?.color, Palettes.light.onSecondaryContainer);
  });
}
