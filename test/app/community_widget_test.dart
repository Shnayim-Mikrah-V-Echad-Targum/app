import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/community/data/community_providers.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/models.dart';
import 'package:shnayim_mikra/features/community/ui/account_screen.dart';
import 'package:shnayim_mikra/features/community/ui/community_ui.dart';
import 'package:shnayim_mikra/features/community/ui/forum_screen.dart';
import 'package:shnayim_mikra/features/community/ui/thread_screen.dart';
import 'package:shnayim_mikra/features/parsha/week_overview_screen.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';

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

/// A community whose threads' posts fail to load while [offline].
class _Flaky extends DemoForumRepository {
  bool offline = false;

  @override
  Future<List<Post>> posts(String threadId, {(DateTime, String)? before, int limit = ForumRepository.postsPageSize}) async {
    if (offline) throw Exception('offline');
    return super.posts(threadId, before: before, limit: limit);
  }
}

/// A moderator whose thread actions, and a member whose new threads, can be
/// held back ([gate]).
class _Gated extends DemoForumRepository {
  Completer<void>? gate;

  Future<_Gated> signIn() async {
    await verifyCode('reader@example.org', '123456');
    await acceptGuidelines();
    return this;
  }

  @override
  Future<void> moderate(String action, String targetId, {String? reason}) async {
    await gate?.future;
    return super.moderate(action, targetId, reason: reason);
  }

  @override
  Future<String> createThread({required int forumId, required String title, required String body, int? parshaNumber}) async {
    await gate?.future;
    return super.createThread(forumId: forumId, title: title, body: body, parshaNumber: parshaNumber);
  }
}

/// A community whose threads' earlier posts fail to load while [offline].
class _NoEarlier extends DemoForumRepository {
  bool offline = false;

  @override
  Future<List<Post>> posts(String threadId, {(DateTime, String)? before, int limit = ForumRepository.postsPageSize}) async {
    if (offline && before != null) throw Exception('offline');
    return super.posts(threadId, before: before, limit: limit);
  }
}

/// A community whose forums' threads fail to load while [offline].
class _FlakyForum extends DemoForumRepository {
  bool offline = false;

  @override
  Future<List<ThreadSummary>> threads({
    int? forumId,
    int? parshaNumber,
    (DateTime, String)? after,
    int limit = ForumRepository.threadsPageSize,
  }) async {
    if (offline) throw Exception('offline');
    return super.threads(forumId: forumId, parshaNumber: parshaNumber, after: after, limit: limit);
  }
}

/// A signed-in member who can't reach the server to accept the guidelines.
class _OfflineNewcomer extends DemoForumRepository {
  @override
  Future<void> acceptGuidelines() async => throw Exception('offline');
}

/// A community whose forums can't be paged: the first page comes, and no
/// other.
class _FirstPageOnly extends DemoForumRepository {
  @override
  Future<List<ThreadSummary>> threads({
    int? forumId,
    int? parshaNumber,
    (DateTime, String)? after,
    int limit = ForumRepository.threadsPageSize,
  }) async {
    if (after != null) throw Exception('offline');
    return super.threads(forumId: forumId, parshaNumber: parshaNumber, limit: limit);
  }
}

/// A community whose pages after the first wait for [gate], and are
/// counted ([pages]).
class _SlowPaging extends DemoForumRepository {
  Completer<void>? gate;
  int pages = 0;

  @override
  Future<List<ThreadSummary>> threads({
    int? forumId,
    int? parshaNumber,
    (DateTime, String)? after,
    int limit = ForumRepository.threadsPageSize,
  }) async {
    if (after != null) {
      pages++;
      await gate?.future;
    }
    return super.threads(forumId: forumId, parshaNumber: parshaNumber, after: after, limit: limit);
  }
}

/// A thread in Divrei Torah, with its last post [minutes] into October.
ThreadSummary _thread(int id, {int minutes = 0, bool pinned = false, int posts = 1}) => ThreadSummary(
      id: '$id',
      forumId: 3,
      title: 'Thread $id',
      kind: ThreadKind.discussion,
      authorName: 'Avraham',
      postCount: posts,
      lastPostAt: DateTime(2026, 10, 1).add(Duration(minutes: minutes)),
      createdAt: DateTime(2026, 10, 1),
      pinned: pinned,
    );

/// [repo] with thread 5000 of [count] posts by Rivka, "Post 1" to "Post
/// [count]", one a minute, in which post [replyFrom] (if given) replies to
/// post [replyTo].
T _withLongThread<T extends DemoForumRepository>(T repo, {int count = 250, int? replyFrom, int? replyTo}) => repo
  ..seed(
    threads: [_thread(5000, minutes: count, posts: count)],
    posts: [
      for (var i = 1; i <= count; i++)
        Post(
          id: '$i',
          threadId: '5000',
          authorId: 'demo-author',
          authorName: 'Rivka',
          body: 'Post $i',
          createdAt: DateTime(2026, 10, 1).add(Duration(minutes: i)),
          replyToId: i == replyFrom ? '$replyTo' : null,
        ),
    ],
  );

/// [repo] with 40 pinned and 40 other threads in Divrei Torah.
T _withManyThreads<T extends DemoForumRepository>(T repo) => repo
  ..seed(threads: [
    for (var i = 0; i < 40; i++) _thread(300 + i, minutes: i, pinned: true),
    for (var i = 0; i < 40; i++) _thread(100 + i, minutes: i),
  ]);

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

/// The thread's list, which builds its posts only as they scroll into view.
final _threadList = find.descendant(of: find.byType(ThreadScreen), matching: find.byType(Scrollable)).first;

/// Scrolls the thread down (or [up]) until [finder] is in view.
Future<void> _scrollThreadTo(WidgetTester tester, Finder finder, {bool up = false}) async {
  await tester.scrollUntilVisible(finder, up ? -400 : 400, scrollable: _threadList, maxScrolls: 100);
  await tester.pumpAndSettle();
}

/// The post menu of the [index]th post, named for its author.
Future<void> _openPostMenu(WidgetTester tester, int index) async {
  await tester.tap(find.descendant(of: find.byType(PostCard).at(index), matching: find.byTooltip(RegExp('^More options for '))));
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
    // Said on the page, and once in a status message.
    const sent = 'We sent a 6-digit code to reader@example.org.';
    expect(find.descendant(of: find.byType(PageBody), matching: find.text(sent)), findsOneWidget);
    expect(find.descendant(of: find.byType(SnackBar), matching: find.text(sent)), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue, reason: 'the code field takes the focus');
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    final signedIn = find.textContaining('Signed in as');
    expect(find.descendant(of: find.byType(PageBody), matching: signedIn), findsOneWidget);
    expect(find.descendant(of: find.byType(SnackBar), matching: signedIn), findsOneWidget);
    // Let the status message clear the composer.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

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
    // Sent, the reply is scrolled to, at the end of the thread.
    expect(find.text('Thank you, this helped me.'), findsOneWidget);
    await _scrollThreadTo(tester, find.text('3 posts'), up: true);
    expect(find.text('3 posts'), findsOneWidget);
  });

  testWidgets('signing in to send a reply goes back to it with nothing over it, and says as whom', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(supportsAnnounce: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final c = await _pump(tester);
    c.read(routerProvider).go('/community/thread/1');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Write a reply'), 'Thank you.');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reply'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'reader@example.org');
    await tester.tap(find.text('Email me a code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    tester.takeAnnouncements();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(ThreadScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing, reason: 'nothing covers the reply box');
    expect([for (final a in tester.takeAnnouncements()) a.message], [startsWith('Signed in as ')]);
    // The reply goes on: a first post asks to accept the guidelines.
    expect(find.text("I'll follow the community guidelines"), findsOneWidget);
  });

  testWidgets('"Use a different email" gives the email field the focus', (tester) async {
    final c = await _pump(tester);
    c.read(routerProvider).go('/community/account');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'reader@example.org');
    await tester.tap(find.text('Email me a code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use a different email'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).decoration?.labelText, 'Email address');
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
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
    expect(find.text('Clear all progress for Bereshit?'), findsOneWidget, reason: "the dialog's title");
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
      expect(find.text('3 posts'), findsOneWidget);
      await _scrollThreadTo(tester, find.text('Thank you, this helped me.'));
      expect(find.text('Thank you, this helped me.'), findsOneWidget);
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

    Future<void> signInFromThePrompt(WidgetTester tester) async {
      expect(find.byType(AccountScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'reader@example.org');
      await tester.tap(find.text('Email me a code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.byType(ThreadScreen), findsOneWidget);
    }

    testWidgets('tapped signed out, and given before, stays given once signed in', (tester) async {
      final forums = await _Member().signIn();
      await forums.setTodah('2', true);
      await forums.signOut();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsNothing, reason: 'signed out, none are yours');

      await _tapTodah(tester, '5 thanks');
      await tester.pumpAndSettle();
      await signInFromThePrompt(tester);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('5 thanks'), findsOneWidget);
      expect((await forums.posts('1')).firstWhere((p) => p.id == '2').myTodah, isTrue);
    });

    testWidgets('tapped signed out on what proves to be your own post gives none', (tester) async {
      final forums = _Member()
        ..seed(posts: [
          Post(id: '7', threadId: '1', authorId: 'me', authorName: 'Me', body: 'My own thought', createdAt: DateTime.now()),
        ]);
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      await _scrollThreadTo(tester, find.text('My own thought'));
      final mine = find.descendant(
        of: find.ancestor(of: find.text('My own thought'), matching: find.byType(PostCard)),
        matching: find.text('Say thanks'),
      );
      await tester.tap(mine);
      await tester.pumpAndSettle();
      await signInFromThePrompt(tester);
      expect(forums.todahCalls, 0);
      expect((await forums.posts('1')).firstWhere((p) => p.id == '7').todah, 0);
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

  testWidgets('a post is numbered, and its todah is a toggle named for what a tap does', (tester) async {
    final semantics = tester.ensureSemantics();
    final forums = await _Member().signIn();
    final c = await _pump(tester, forums: forums);
    c.read(routerProvider).go('/community/thread/1');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'^Post 2 of 2\n')), findsOneWidget);
    expect(find.byTooltip('More options for Rivka'), findsOneWidget);

    final todah = find.descendant(of: find.byType(PostCard).at(1), matching: find.bySubtype<TextButton>());
    expect(
      tester.getSemantics(todah),
      isSemantics(label: 'Say thanks to Rivka. 4 thanks', isButton: true, hasToggledState: true, isToggled: false),
    );
    await _tapTodah(tester, '4 thanks');
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(todah),
      isSemantics(label: 'Remove your thanks to Rivka. 5 thanks', isButton: true, hasToggledState: true, isToggled: true),
    );
    semantics.dispose();
  });

  group('refreshing', () {
    testWidgets('a thread from the keyboard shows the replies since it opened', (tester) async {
      final forums = DemoForumRepository();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      forums.seed(posts: [
        Post(id: '9001', threadId: '1', authorName: 'Sarah', body: 'Sent from another device', createdAt: DateTime.now()),
      ]);

      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pumpAndSettle();
      expect(find.text('Updated'), findsOneWidget);
      await _scrollThreadTo(tester, find.text('Sent from another device'));
      expect(find.text('Sent from another device'), findsOneWidget);
    });

    testWidgets('a forum with Ctrl+R shows its new threads', (tester) async {
      final forums = DemoForumRepository();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/forum/divrei-torah');
      await tester.pumpAndSettle();
      forums.seed(threads: [_thread(9002, minutes: 100000)]);
      expect(find.text('Thread 9002'), findsNothing);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Thread 9002'), findsOneWidget);
      expect(find.text('Updated'), findsOneWidget);
    });

    testWidgets('the forums and the reports from their Refresh button', (tester) async {
      final forums = await _Member().signIn();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Updated'), findsOneWidget);

      c.read(routerProvider).go('/community/moderation');
      await tester.pumpAndSettle();
      expect(find.text('Spam or advertising'), findsNothing);
      await forums.report(postId: '2', reason: ReportReason.spam);
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Spam or advertising'), findsOneWidget);
    });

    testWidgets('a thread that fits the screen by pulling it down', (tester) async {
      final forums = DemoForumRepository()
        ..seed(
          threads: [_thread(6001)],
          posts: [Post(id: '9000', threadId: '6001', authorName: 'Rivka', body: 'Shalom', createdAt: DateTime(2026, 10, 1))],
        );
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/6001');
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(_threadList).position;
      expect(position.maxScrollExtent, 0, reason: 'nothing to scroll');
      forums.seed(posts: [
        Post(id: '9001', threadId: '6001', authorName: 'Sarah', body: 'Sent from another device', createdAt: DateTime.now()),
      ]);
      await tester.fling(_threadList, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Sent from another device'), findsOneWidget);
    });

    testWidgets('a thread pulled down offline says why, and keeps its posts', (tester) async {
      final forums = _Flaky();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      forums.offline = true;
      await tester.fling(_threadList, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text("Couldn't reach the server. Check your connection and try again."), findsOneWidget);
      expect(find.byType(PostCard), findsNWidgets(2));
    });

    testWidgets('a forum pulled down offline says why, and keeps its threads', (tester) async {
      final forums = _FlakyForum();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      forums.offline = true;
      final list = find.descendant(of: find.byType(ForumScreen), matching: find.byType(Scrollable)).first;
      await tester.fling(list, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text("Couldn't reach the server. Check your connection and try again."), findsOneWidget);
      expect(find.text('Why read the Targum rather than a translation?'), findsOneWidget);
    });

    testWidgets('that fails says why, and keeps what is shown', (tester) async {
      final forums = _Flaky();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      forums.offline = true;
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't reach the server. Check your connection and try again."), findsOneWidget);
      expect(find.text('Updated'), findsNothing);
      expect(find.byType(PostCard), findsWidgets);
    });
  });

  group('a long thread', () {
    testWidgets('numbers its posts within the whole thread, for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      final c = await _pump(tester, forums: _withLongThread(DemoForumRepository()));
      c.read(routerProvider).go('/community/thread/5000');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp(r'^Post 151 of 250\n')), findsOneWidget, reason: 'the first post shown');
      expect(find.bySemanticsLabel(RegExp(r'^Post 1 of ')), findsNothing);

      await tester.tap(find.text('Show earlier posts'));
      await tester.pumpAndSettle();
      await _scrollThreadTo(tester, find.text('Post 51'), up: true);
      expect(find.bySemanticsLabel(RegExp(r'^Post 51 of 250\n')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('quotes a post on an earlier page, not loaded, above the reply to it', (tester) async {
      final c = await _pump(tester, forums: _withLongThread(DemoForumRepository(), count: 150, replyFrom: 140, replyTo: 30));
      c.read(routerProvider).go('/community/thread/5000');
      await tester.pumpAndSettle();
      expect(c.read(postsProvider('5000')).requireValue.posts.any((p) => p.id == '30'), isFalse);
      await _scrollThreadTo(tester, find.text('Post 140'));
      expect(find.text('Rivka: Post 30'), findsOneWidget);
    });

    testWidgets('that cannot show its earlier posts says so, and keeps those shown', (tester) async {
      final forums = _withLongThread(_NoEarlier()..offline = true);
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/5000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show earlier posts'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text("Couldn't reach the server. Check your connection and try again."), findsOneWidget);
      expect(find.text('Show earlier posts'), findsOneWidget);
      expect(find.text('Post 151'), findsOneWidget);
      expect(c.read(postsProvider('5000')).requireValue.posts, hasLength(100));
    });

    testWidgets('shown to its first post from the keyboard gives that post the focus', (tester) async {
      final c = await _pump(tester, forums: _withLongThread(DemoForumRepository()));
      c.read(routerProvider).go('/community/thread/5000');
      await tester.pumpAndSettle();
      Focus.of(tester.element(find.text('Show earlier posts'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(Focus.of(tester.element(find.text('Show earlier posts'))).hasPrimaryFocus, isTrue,
          reason: 'with more to show, the button stays, with the focus');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Show earlier posts'), findsNothing);
      final first = find.ancestor(of: find.text('Post 1'), matching: find.byType(PostCard));
      expect(FocusManager.instance.primaryFocus?.context, isNotNull);
      expect(
        find.descendant(of: first, matching: find.byElementPredicate((e) => e == FocusManager.instance.primaryFocus!.context)),
        findsOneWidget,
        reason: 'the first post, in its place, has the focus',
      );
      expect(tester.getRect(first).top, greaterThanOrEqualTo(0));
    });

    testWidgets('opens on its latest posts, shows the earlier ones on request, and counts them all', (tester) async {
      final forums = DemoForumRepository()
        ..seed(
          threads: [_thread(5000, minutes: 250, posts: 250)],
          posts: [
            for (var i = 1; i <= 250; i++)
              Post(
                id: '$i',
                threadId: '5000',
                authorId: 'demo-author',
                authorName: 'Rivka',
                body: 'Post $i',
                createdAt: DateTime(2026, 10, 1).add(Duration(minutes: i)),
              ),
          ],
        );
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/5000');
      await tester.pumpAndSettle();
      expect(find.text('250 posts'), findsOneWidget);
      expect(find.text('Show earlier posts'), findsOneWidget);
      expect(find.text('Post 151'), findsOneWidget);
      expect(find.text('Post 150'), findsNothing);
      await _scrollThreadTo(tester, find.text('Post 250'));
      expect(find.text('Post 250'), findsOneWidget);

      await _scrollThreadTo(tester, find.text('Show earlier posts'), up: true);
      await tester.tap(find.text('Show earlier posts'));
      await tester.pumpAndSettle();
      // The posts before, from their first.
      expect(find.text('Post 51'), findsOneWidget);
      await tester.tap(find.text('Show earlier posts'));
      await tester.pumpAndSettle();
      expect(find.text('Post 1'), findsOneWidget);
      expect(find.text('Show earlier posts'), findsNothing);
      expect(c.read(postsProvider('5000')).requireValue.posts, hasLength(250));
      await _scrollThreadTo(tester, find.text('250 posts'), up: true);
      expect(find.text('250 posts'), findsOneWidget);
    });
  });

  group('a forum', () {
    testWidgets('lists its pinned threads, then the rest a page at a time', (tester) async {
      final c = await _pump(tester, forums: _withManyThreads(DemoForumRepository()));
      c.read(routerProvider).go('/community/forum/divrei-torah');
      await tester.pumpAndSettle();
      expect(find.text('Thread 339'), findsOneWidget, reason: 'the latest pinned thread first');
      final list = find.descendant(of: find.byType(ForumScreen), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.text('Load more'), 400, scrollable: list);
      await tester.pumpAndSettle();
      expect(find.text('Thread 110'), findsOneWidget, reason: 'the 30th latest of the others, last');
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Load more'), findsNothing);
      final shown = c.read(threadsProvider(3)).requireValue.threads;
      expect({for (final t in shown) t.id}, hasLength(80));
      await tester.scrollUntilVisible(find.text('Thread 100'), 400, scrollable: list);
      expect(find.text('Thread 100'), findsOneWidget);
    });

    testWidgets('loaded from the keyboard says how many came, and gives the first of them the focus', (tester) async {
      final repo = _SlowPaging()..seed(threads: [for (var i = 0; i < 70; i++) _thread(100 + i, minutes: i)]);
      final c = await _pump(tester, forums: repo);
      c.read(routerProvider).go('/community/forum/divrei-torah');
      await tester.pumpAndSettle();
      final list = find.descendant(of: find.byType(ForumScreen), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.text('Load more'), 400, scrollable: list);
      await tester.pumpAndSettle();
      final button = find.descendant(of: find.byType(ForumScreen), matching: find.byType(OutlinedButton));
      expect(button, findsOneWidget);
      Focus.of(tester.element(find.text('Load more'))).requestFocus();
      await tester.pump();

      // Pressed again while it loads, it keeps the focus and loads once.
      repo.gate = Completer<void>();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.descendant(of: button, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(Focus.of(tester.element(find.byType(CircularProgressIndicator))).hasPrimaryFocus, isTrue);
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(repo.pages, 1);
      expect(c.read(threadsProvider(3)).requireValue.threads, hasLength(60));
      expect(find.text('Loaded 30 more discussions'), findsOneWidget);
      // The latest of those loaded is in the button's place, with the focus.
      expect(Focus.of(tester.element(find.text('Thread 139'))).hasPrimaryFocus, isTrue);
      expect(tester.getRect(find.text('Thread 139')).bottom, lessThanOrEqualTo(915));
    });

    testWidgets('that cannot load more says so, and offers it again', (tester) async {
      final c = await _pump(tester, forums: _withManyThreads(_FirstPageOnly()));
      c.read(routerProvider).go('/community/forum/divrei-torah');
      await tester.pumpAndSettle();
      final list = find.descendant(of: find.byType(ForumScreen), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.text('Load more'), 400, scrollable: list);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text("Couldn't reach the server. Check your connection and try again."), findsOneWidget);
      expect(find.text('Load more'), findsOneWidget);
      expect(c.read(threadsProvider(3)).requireValue.threads, hasLength(70));
    });
  });

  group("a thread's count", () {
    testWidgets('is of the posts shown, once all are: none by a blocked member', (tester) async {
      final forums = await _Member().signIn();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      expect(find.text('2 posts'), findsOneWidget);
      await _openPostMenu(tester, 1);
      await tester.tap(find.text('Block Rivka'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Block Rivka'));
      await tester.pumpAndSettle();
      expect(find.byType(PostCard), findsOneWidget);
      expect(find.text('1 post'), findsOneWidget);
    });

    testWidgets('drops, here and in its forum, when a post is deleted', (tester) async {
      final forums = await _Member().signIn();
      await forums.reply('1', 'A thought to take back.');
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      expect(find.textContaining('3 posts'), findsOneWidget);
      await tester.tap(find.text('Why read the Targum rather than a translation?'));
      await tester.pumpAndSettle();
      expect(find.text('3 posts'), findsOneWidget);

      await _scrollThreadTo(tester, find.text('A thought to take back.'));
      await _openPostMenu(tester, 2);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      await _scrollThreadTo(tester, find.text('2 posts'), up: true);
      expect(find.text('2 posts'), findsOneWidget);

      await _goBack(tester);
      expect(find.textContaining('2 posts'), findsOneWidget);
      expect(find.textContaining('3 posts'), findsNothing);
    });
  });

  testWidgets('a pin made as its thread closes still shows, in the thread and its forum', (tester) async {
    final forums = await _Gated().signIn();
    final c = await _pump(tester, forums: forums);
    c.read(routerProvider).go('/community/forum/questions');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Why read the Targum rather than a translation?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pinned'), findsNothing);

    forums.gate = Completer<void>();
    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('More options')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin to top'));
    await tester.pump();
    await _goBack(tester);
    forums.gate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Pinned'), findsOneWidget, reason: 'as its forum lists it');

    await tester.tap(find.text('Why read the Targum rather than a translation?'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('More options')));
    await tester.pumpAndSettle();
    expect(find.text('Unpin'), findsOneWidget);
  });

  testWidgets('a weekly thread is listed in Hebrew in the Hebrew UI, named for both portions of a combined week', (tester) async {
    final forums = DemoForumRepository();
    await forums.weeklyThread(parshaNumber: 42, hebrewYear: 5787, title: 'Matot · מטות · 5787');
    final c = await _pump(tester, forums: forums, settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew));
    c.read(routerProvider).go('/community/forum/parsha');
    await tester.pumpAndSettle();
    final title = find.descendant(of: find.byType(ThreadTile), matching: find.textContaining(RegExp(r'^פרשת מטות.מסעי תשפ״ז$')));
    expect(title, findsOneWidget);
    expect(tester.widget<Text>(title).textDirection, TextDirection.rtl);
  });

  testWidgets('an empty thread that is not weekly says it has no replies yet', (tester) async {
    final forums = DemoForumRepository()..seed(threads: [_thread(6000, posts: 0)]);
    final c = await _pump(tester, forums: forums);
    c.read(routerProvider).go('/community/thread/6000');
    await tester.pumpAndSettle();
    expect(find.text('No replies yet.'), findsOneWidget);
  });

  testWidgets('a new discussion sent as its page closes is not restored as a draft', (tester) async {
    final forums = await _Gated().signIn();
    final c = await _pump(tester, forums: forums);
    final prefs = c.read(sharedPreferencesProvider);
    c.read(routerProvider).go('/community');
    await tester.pumpAndSettle();
    c.read(routerProvider).push('/community/new?forum=questions');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'A question on Rashi');
    await tester.enterText(find.widgetWithText(TextField, 'Your message'), 'Why does Rashi explain this word?');
    await tester.pump(const Duration(seconds: 1));
    expect(prefs.getString('draft.newThread'), isNotNull);

    forums.gate = Completer<void>();
    await tester.tap(find.widgetWithText(FilledButton, 'Post'));
    await tester.pump();
    await _goBack(tester);
    forums.gate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(prefs.getString('draft.newThread'), isNull);
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
