import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/services/feedback.dart';

void main() {
  /// Shows a status message where announcements are taken, and returns
  /// those made.
  Future<List<String>> announced(WidgetTester tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(supportsAnnounce: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () => showStatus(context, 'Updated'), child: const Text('Refresh')),
        ),
      ),
    ));
    tester.takeAnnouncements();
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Updated'), findsOneWidget, reason: 'shown in a SnackBar');
    return [for (final a in tester.takeAnnouncements()) a.message];
  }

  testWidgets(
    'on iOS a status message is left to its SnackBar, which VoiceOver reads as a live region',
    (tester) async => expect(await announced(tester), isEmpty),
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'on Windows and macOS a status message is announced once',
    (tester) async => expect(await announced(tester), ['Updated']),
    variant: const TargetPlatformVariant({TargetPlatform.windows, TargetPlatform.macOS}),
  );
}
