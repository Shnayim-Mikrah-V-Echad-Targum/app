import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/models.dart';
import 'package:shnayim_mikra/features/community/ui/community_ui.dart';
import 'package:shnayim_mikra/features/community/ui/thread_screen.dart';
import 'package:shnayim_mikra/features/parsha/week_overview_screen.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';

/// Records the weekly threads asked for, and can hold them back ([gate]) or
/// fail them ([offline]).
class _Threads extends DemoForumRepository {
  final asked = <(int, int)>[];
  Completer<void>? gate;
  bool offline = false;

  @override
  Future<String> weeklyThread({required int parshaNumber, required int hebrewYear, required String title}) async {
    asked.add((parshaNumber, hebrewYear));
    await gate?.future;
    if (offline) throw Exception('offline');
    return super.weeklyThread(parshaNumber: parshaNumber, hebrewYear: hebrewYear, title: title);
  }
}

/// A signed-in member who has accepted the guidelines, whose replies and
/// todah can be held back ([gate]) and whose todah can fail ([failTodah]).
class _Member extends DemoForumRepository {
  Completer<void>? gate;
  bool failTodah = false;
  int todahCalls = 0;

  Future<_Member> signIn() async {
    await verifyCode('reader@example.org', '123456');
    await acceptGuidelines();
    return this;
  }

  @override
  Future<Post> reply(String threadId, String body, {String? replyToId}) async {
    await gate?.future;
    return super.reply(threadId, body, replyToId: replyToId);
  }

  @override
  Future<void> setTodah(String postId, bool on) async {
    todahCalls++;
    await gate?.future;
    if (failTodah) throw Exception('offline');
    return super.setTodah(postId, on);
  }
}

/// A signed-in member who can't reach the server to accept the guidelines.
class _OfflineNewcomer extends DemoForumRepository {
  @override
  Future<void> acceptGuidelines() async => throw Exception('offline');
}

/// Friday of Bereshit 5787.
final _bereshit = DateTime(2026, 10, 9, 11);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  DateTime? now,
  DemoForumRepository? forums,
  ProgressState? progress,
  AppSettings settings = const AppSettings(onboardingComplete: true),
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(tester, now: now ?? _bereshit, forums: forums, progress: progress, settings: settings);
  await tester.pumpAndSettle();
  return c;
}

String _location(ProviderContainer c) => c.read(routerProvider).state.uri.toString();

/// The week page's Discuss button, in either language.
final _discuss = find.descendant(of: find.byType(WeeklyThreadOpener), matching: find.byType(OutlinedButton));

Future<void> _tapDiscuss(WidgetTester tester) async {
  await tester.ensureVisible(_discuss);
  await tester.pumpAndSettle();
  await tester.tap(_discuss);
}

Future<void> _goBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

Future<void> _tapTodah(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
}

/// The post menu of the [index]th post.
Future<void> _openPostMenu(WidgetTester tester, int index) async {
  await tester.tap(find.descendant(of: find.byType(PostCard).at(index), matching: find.byTooltip('More options')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('demo community: sign in with a code, accept guidelines, reply', (tester) async {
    final c = await _pump(tester, now: DateTime(2026, 10, 12, 10));

    c.read(routerProvider).go('/community/account');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'reader@example.org');
    await tester.tap(find.text('Email me a code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('reader@example.org'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Signed in as'), findsOneWidget);

    c.read(routerProvider).go('/community/thread/1');
    await tester.pumpAndSettle();
    expect(find.text('Why read the Targum rather than a translation?'), findsWidgets);
    await tester.enterText(find.widgetWithText(TextField, 'Write a reply'), 'Thank you, this helped me.');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reply'));
    await tester.pumpAndSettle();

    // First post: the community guidelines.
    expect(find.text("I'll follow the community guidelines"), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Thank you, this helped me.'), findsOneWidget);
    expect(find.text('3 posts'), findsOneWidget);
  });

  group('the weekly discussion', () {
    testWidgets('of a combined week opens from its page, named for both portions', (tester) async {
      final forums = _Threads();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/parsha/week/5787:42-43');
      await tester.pumpAndSettle();
      expect(find.text('Parshat Matot-Masei'), findsOneWidget);

      await _tapDiscuss(tester);
      await tester.pumpAndSettle();
      expect(_location(c), matches(RegExp(r'^/community/thread/\d+$')));
      expect(find.byType(ThreadScreen), findsOneWidget);
      expect(forums.asked, [(42, 5787)]);
      // In the app bar and as the heading.
      expect(find.text('Parshat Matot-Masei 5787'), findsNWidgets(2));
      expect(find.text('No posts yet — share a thought on Parshat\u00a0Matot-Masei.'), findsOneWidget);
    });

    testWidgets("of a past week is that year's", (tester) async {
      final forums = _Threads();
      // Noach 5788.
      final c = await _pump(tester, now: DateTime(2027, 10, 25, 11), forums: forums);
      c.read(routerProvider).go('/parsha/week/5787:2');
      await tester.pumpAndSettle();
      await _tapDiscuss(tester);
      await tester.pumpAndSettle();
      expect(forums.asked, [(2, 5787)]);
      expect(find.text('Parshat Noach 5787'), findsNWidgets(2));
    });

    testWidgets("opens from Today for this week's parsha", (tester) async {
      final forums = _Threads();
      final c = await _pump(tester, forums: forums);
      final card = find.text("Discuss this week's parsha");
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(forums.asked, [(1, 5787)]);
      expect(_location(c), matches(RegExp(r'^/community/thread/\d+$')));
      expect(find.text('Parshat Bereshit 5787'), findsNWidgets(2));
    });

    testWidgets('offline says so, rather than loading forever', (tester) async {
      final c = await _pump(tester, forums: _Threads()..offline = true);
      c.read(routerProvider).go('/parsha/week/5787:1');
      await tester.pumpAndSettle();
      await _tapDiscuss(tester);
      await tester.pumpAndSettle();
      expect(find.text("Couldn't reach the server. Check your connection and try again."), findsOneWidget);
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<OutlinedButton>(_discuss).onPressed, isNotNull);
    });

    testWidgets('shows that it is opening, and opens once however often it is tapped', (tester) async {
      final semantics = tester.ensureSemantics();
      final forums = _Threads()..gate = Completer<void>();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/parsha/week/5787:1');
      await tester.pumpAndSettle();
      await _tapDiscuss(tester);
      await tester.pump();
      // Merged into the button's label.
      expect(find.bySemanticsLabel(RegExp('Loading…')), findsOneWidget);
      await tester.tap(_discuss);
      await tester.pump();
      expect(forums.asked, hasLength(1));

      forums.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ThreadScreen), findsOneWidget);
      await _goBack(tester);
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Loading…')), findsNothing);
      semantics.dispose();
    });

    testWidgets('is named in Hebrew in the Hebrew UI, and each title runs its own way', (tester) async {
      const hebrew = AppSettings(onboardingComplete: true, language: AppLanguage.hebrew);
      final c = await _pump(tester, settings: hebrew);
      c.read(routerProvider).go('/parsha/week/5787:1');
      await tester.pumpAndSettle();
      await _tapDiscuss(tester);
      await tester.pumpAndSettle();
      expect(find.text('פרשת בראשית תשפ״ז'), findsNWidgets(2));
      Text appBarTitle() =>
          tester.widget<Text>(find.descendant(of: find.byType(AppBar), matching: find.byType(Text)).first);
      expect(appBarTitle().textDirection, TextDirection.rtl);

      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      expect(appBarTitle().data, 'Why read the Targum rather than a translation?');
      expect(appBarTitle().textDirection, TextDirection.ltr);
      expect(appBarTitle().overflow, TextOverflow.ellipsis);
    });
  });

  testWidgets('a cleared week comes back with Undo after its page has closed', (tester) async {
    final day = LocalDate(2026, 10, 6);
    final c = await _pump(
      tester,
      progress: ProgressState(weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAliyah(0, day)}),
    );
    c.read(routerProvider).go('/parsha/week/5787:1');
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('More options')));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Clear this week's progress"));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, "Clear this week's progress"));
    await tester.pumpAndSettle();
    expect(c.read(progressProvider).week('5787:1').completedUnits, 0);

    await _goBack(tester);
    expect(find.byType(WeekOverviewScreen), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(c.read(progressProvider).week('5787:1').isAliyahDone(0), isTrue);
  });

  group('a reply', () {
    testWidgets('sent as its page closes is not restored as a draft', (tester) async {
      final forums = await _Member().signIn();
      final c = await _pump(tester, forums: forums);
      final prefs = c.read(sharedPreferencesProvider);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Write a reply'), 'Thank you, this helped me.');
      await tester.pump(const Duration(seconds: 1));
      expect(prefs.getString('draft.thread.1'), 'Thank you, this helped me.');

      forums.gate = Completer<void>();
      await tester.tap(find.widgetWithText(FilledButton, 'Reply'));
      await tester.pump();
      await _goBack(tester);
      expect(find.byType(ThreadScreen), findsNothing);
      forums.gate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(prefs.getString('draft.thread.1'), isNull);

      c.read(routerProvider).push('/community/thread/1');
      await tester.pumpAndSettle();
      expect(find.text('Your draft was restored.'), findsNothing);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Write a reply')).controller!.text, isEmpty);
      expect(find.text('Thank you, this helped me.'), findsOneWidget);
      expect(find.text('3 posts'), findsOneWidget);
    });

    testWidgets('that cannot accept the guidelines offline says so', (tester) async {
      final forums = _OfflineNewcomer();
      await forums.verifyCode('reader@example.org', '123456');
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Write a reply'), 'Thank you.');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reply'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text("Couldn't reach the server. Check your connection and try again."), findsOneWidget);
      expect(find.text('Thank you.'), findsOneWidget);
    });
  });

  group('todah', () {
    testWidgets('shows at once, and a second tap waits for the first', (tester) async {
      final forums = await _Member().signIn();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();

      forums.gate = Completer<void>();
      await _tapTodah(tester, '4 thanks');
      await tester.pump();
      expect(find.text('5 thanks'), findsOneWidget);
      await _tapTodah(tester, '5 thanks');
      await tester.pump();
      expect(forums.todahCalls, 1);

      forums.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('5 thanks'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('that fails is taken back', (tester) async {
      final forums = await _Member().signIn();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();

      forums
        ..gate = Completer<void>()
        ..failTodah = true;
      await _tapTodah(tester, '4 thanks');
      await tester.pump();
      expect(find.text('5 thanks'), findsOneWidget);
      forums.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('4 thanks'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(find.text("Couldn't reach the server. Check your connection and try again."), findsOneWidget);
    });

    testWidgets("given is the member's own, and goes when they sign out", (tester) async {
      final forums = await _Member().signIn();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      await _tapTodah(tester, '4 thanks');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await forums.signOut();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(find.text('5 thanks'), findsOneWidget);
    });
  });

  group('a report', () {
    testWidgets('needs a reason, and is made once', (tester) async {
      final forums = await _Member().signIn();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();

      await _openPostMenu(tester, 1);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      final report = find.widgetWithText(FilledButton, 'Report');
      expect(tester.widget<FilledButton>(report).onPressed, isNull);
      await tester.tap(find.text('Spam or advertising'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(report).onPressed, isNotNull);
      await tester.tap(report);
      await tester.pumpAndSettle();
      expect(find.text('Thank you. A moderator will review it.'), findsOneWidget);

      await _openPostMenu(tester, 1);
      expect(find.text('Report'), findsNothing);
      expect(find.text('Block Rivka'), findsOneWidget);
    });

    testWidgets('made before, in another session, says so', (tester) async {
      final forums = await _Member().signIn();
      await forums.report(postId: '2', reason: ReportReason.spam);
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();

      await _openPostMenu(tester, 1);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Off topic'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Report'));
      await tester.pumpAndSettle();
      expect(find.text("You've already reported this post."), findsOneWidget);

      await _openPostMenu(tester, 1);
      expect(find.text('Report'), findsNothing);
    });
  });
}
