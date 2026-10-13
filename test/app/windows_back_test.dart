import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/notes/notes_screen.dart';
import 'package:shnayim_mikra/features/parsha/parsha_tab.dart';
import 'package:shnayim_mikra/features/parsha/week_overview_screen.dart';
import 'package:shnayim_mikra/features/progress/progress_screen.dart';
import 'package:shnayim_mikra/features/reader/reader_screen.dart';
import 'package:shnayim_mikra/features/search/search_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/today/today_screen.dart';

import '../helpers.dart';

/// In the Windows app, the mouse's back button, Alt+← and a keyboard's Back
/// key go back, as the system's Back does on Android.
void main() {
  final windows = TargetPlatformVariant.only(TargetPlatform.windows);

  /// Records each time the app asks to leave, which a back button on Windows
  /// must never do.
  List<MethodCall> recordExits(WidgetTester tester) {
    final exits = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exits.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    return exits;
  }

  Future<GoRouter> open(WidgetTester tester) async {
    final c = await pumpApp(tester);
    await tester.pumpAndSettle();
    return c.read(routerProvider);
  }

  Future<void> altLeft(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
  }

  /// A click of the mouse's back button over the middle of the window.
  Future<void> mouseBack(WidgetTester tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kBackMouseButton);
    await mouse.down(tester.getCenter(find.byType(Navigator).first));
    await mouse.up();
    await mouse.removePointer();
    await tester.pumpAndSettle();
  }

  testWidgets('Alt+← closes a page over the tabs', (tester) async {
    final router = await open(tester);
    router.push('/notes');
    await tester.pumpAndSettle();
    expect(find.byType(NotesScreen), findsOneWidget);

    await altLeft(tester);
    expect(router.state.uri.path, '/today');
    expect(find.byType(NotesScreen), findsNothing);
    expect(find.byType(TodayScreen), findsOneWidget);
  }, variant: windows);

  testWidgets('Alt+← closes a page within a tab, then returns to Today', (tester) async {
    final exits = recordExits(tester);
    final router = await open(tester);
    router.go('/parsha/week/5787:2');
    await tester.pumpAndSettle();
    expect(find.byType(WeekOverviewScreen), findsOneWidget);

    await altLeft(tester);
    expect(router.state.uri.path, '/parsha');
    expect(find.byType(ParshaTab), findsOneWidget);

    await altLeft(tester);
    expect(router.state.uri.path, '/today');
    expect(find.byType(TodayScreen), findsOneWidget);

    // Today's root has nothing to go back to, and the app stays open.
    await altLeft(tester);
    expect(router.state.uri.path, '/today');
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(exits, isEmpty);
    expect(tester.takeException(), isNull);
  }, variant: windows);

  testWidgets('Alt+← on Progress goes to Today', (tester) async {
    final router = await open(tester);
    router.go('/progress');
    await tester.pumpAndSettle();
    expect(find.byType(ProgressScreen), findsOneWidget);

    await altLeft(tester);
    expect(router.state.uri.path, '/today');
    expect(find.byType(TodayScreen), findsOneWidget);
  }, variant: windows);

  testWidgets('Today with a page open in another tab stays open', (tester) async {
    final exits = recordExits(tester);
    final router = await open(tester);
    router.go('/parsha/week/5787:2');
    await tester.pumpAndSettle();
    router.go('/today');
    await tester.pumpAndSettle();

    await altLeft(tester);
    await mouseBack(tester);
    expect(router.state.uri.path, '/today');
    expect(exits, isEmpty);
    expect(tester.takeException(), isNull);
  }, variant: windows);

  testWidgets('the mouse’s back button goes back', (tester) async {
    final router = await open(tester);
    router.go('/progress');
    await tester.pumpAndSettle();
    router.push('/notes');
    await tester.pumpAndSettle();

    await mouseBack(tester);
    expect(router.state.uri.path, '/progress');
    expect(find.byType(NotesScreen), findsNothing);

    await mouseBack(tester);
    expect(router.state.uri.path, '/today');

    // The other buttons are the page's.
    router.push('/notes');
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kForwardMouseButton);
    await mouse.down(tester.getCenter(find.byType(NotesScreen)));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.byType(NotesScreen), findsOneWidget);
  }, variant: windows);

  testWidgets('a keyboard’s Back key goes back', (tester) async {
    final router = await open(tester);
    router.push('/notes');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.browserBack);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/today');
    expect(find.byType(NotesScreen), findsNothing);
  }, variant: windows);

  testWidgets('a dialog closes first', (tester) async {
    final router = await open(tester);
    router.push('/notes');
    await tester.pumpAndSettle();
    showDialog<void>(
      context: tester.element(find.byType(NotesScreen)),
      builder: (_) => const AlertDialog(content: Text('A dialog')),
    );
    await tester.pumpAndSettle();

    await altLeft(tester);
    expect(find.text('A dialog'), findsNothing);
    expect(find.byType(NotesScreen), findsOneWidget);

    await mouseBack(tester);
    expect(find.byType(NotesScreen), findsNothing);
  }, variant: windows);

  testWidgets('a text field keeps Alt+← for its caret, and the mouse still goes back', (tester) async {
    final router = await open(tester);
    router.push('/search');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Bereshit');
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.selection.baseOffset, 'Bereshit'.length);

    await altLeft(tester);
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(field.controller!.selection, const TextSelection.collapsed(offset: 0));

    await mouseBack(tester);
    expect(find.byType(SearchScreen), findsNothing);
    expect(router.state.uri.path, '/today');
  }, variant: windows);

  testWidgets('the reader’s shortcuts list Alt+← in the Windows app alone', (tester) async {
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, notificationPromptShown: true));
    await tester.pumpAndSettle();
    c.read(routerProvider).push('/read/5787:2/0');
    // Till its texts have loaded.
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);

    final handle = tester.ensureSemantics();
    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.pumpAndSettle();
    final row = find.bySemanticsLabel('Go back a page, as the mouse’s back button does\nAlt + Left arrow');
    final present = defaultTargetPlatform == TargetPlatform.windows;
    expect(row, present ? findsOneWidget : findsNothing);
    handle.dispose();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // And it closes the reader.
    await altLeft(tester);
    expect(find.byType(ReaderScreen), present ? findsNothing : findsOneWidget);
  }, variant: const TargetPlatformVariant({TargetPlatform.windows, TargetPlatform.android}));

  testWidgets('elsewhere they are left alone', (tester) async {
    final router = await open(tester);
    router.push('/notes');
    await tester.pumpAndSettle();

    await altLeft(tester);
    await mouseBack(tester);
    expect(find.byType(NotesScreen), findsOneWidget);
  },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      }));
}
