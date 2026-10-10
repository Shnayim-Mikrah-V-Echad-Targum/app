import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/widgets/sefer_choice_chip.dart';

import '../../helpers.dart';

/// Reminders that can be scheduled, where the OS [allows] them or not, and
/// the device's settings for them can be opened or not.
class _Notifications extends PhoneNotifications {
  _Notifications({this.allows = true, this.opensSettings = true});

  final bool allows;
  final bool opensSettings;

  @override
  Future<bool> requestPermission() async => allows;

  @override
  bool get canOpenSystemSettings => opensSettings;
}

void main() {
  Future<ProviderContainer> openReminders(WidgetTester tester, _Notifications service,
      {AppSettings settings = const AppSettings(onboardingComplete: true)}) async {
    final c = await pumpApp(tester, settings: settings, notifications: service);
    c.read(routerProvider).go('/settings/reminders');
    await tester.pumpAndSettle();
    return c;
  }

  /// The chosen routines' labels.
  List<String> selected(WidgetTester tester) => [
        for (final chip in tester.widgetList<SeferChoiceChip>(find.byType(SeferChoiceChip)))
          if (chip.selected) (chip.label as Text).data!,
      ];

  testWidgets('a routine chosen stays chosen when the language changes, and is saved by name', (tester) async {
    final c = await openReminders(
      tester,
      _Notifications(),
      settings: const AppSettings(onboardingComplete: true, dailyReminder: true),
    );
    expect(find.text('After I…'), findsOneWidget);
    expect(selected(tester), isEmpty);

    await tester.tap(find.text('finish Shacharit'));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).habitAnchor, HabitAnchor.shacharit);
    expect(c.read(settingsProvider).toJson()['habitAnchor'], 'shacharit');
    expect(selected(tester), ['finish Shacharit']);

    c.read(settingsProvider.notifier).update((s) => s.copyWith(language: AppLanguage.hebrew));
    await tester.pumpAndSettle();
    expect(selected(tester), ['אסיים שחרית']);

    // Chosen again, it is cleared.
    await tester.tap(find.text('אסיים שחרית'));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).habitAnchor, isNull);
    expect(selected(tester), isEmpty);
  });

  testWidgets('one chosen by an earlier version, saved as its label, shows as chosen', (tester) async {
    await openReminders(
      tester,
      _Notifications(),
      settings: AppSettings.fromJson(
        {...const AppSettings(onboardingComplete: true, dailyReminder: true).toJson(), 'habitAnchor': 'אסיים ארוחת ערב'},
      ),
    );
    expect(selected(tester), ['finish dinner']);
  });

  group('notifications refused', () {
    const channel = MethodChannel('com.spencerccf.app_settings/methods');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    testWidgets("can be allowed in the device's notification settings for the app", (tester) async {
      final c = await openReminders(tester, _Notifications(allows: false));
      await tester.tap(find.text('Daily reminder'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications are off'), findsOneWidget);

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(calls.single.method, 'openSettings');
      expect((calls.single.arguments as Map)['type'], 'notification');
      expect(c.read(settingsProvider).dailyReminder, isFalse);
    });

    testWidgets("where the device's settings can't be opened, only say so", (tester) async {
      await openReminders(tester, _Notifications(allows: false, opensSettings: false));
      await tester.tap(find.text('Daily reminder'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications are off'), findsOneWidget);
      expect(find.text('Open settings'), findsNothing);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(calls, isEmpty);
    });
  });
}
