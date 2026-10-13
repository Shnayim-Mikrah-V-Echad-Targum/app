import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/about/legal_screen.dart';
import 'package:shnayim_mikra/features/community/data/community_providers.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/models.dart';
import 'package:shnayim_mikra/features/community/ui/account_screen.dart';
import 'package:shnayim_mikra/features/community/ui/community_ui.dart';
import 'package:shnayim_mikra/features/community/ui/compose_screen.dart';
import 'package:shnayim_mikra/features/community/ui/forum_screen.dart';
import 'package:shnayim_mikra/features/community/ui/thread_screen.dart';
import 'package:shnayim_mikra/features/parsha/week_overview_screen.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/l10n.dart';
import 'package:shnayim_mikra/ui/theme/focus.dart';
import 'package:shnayim_mikra/ui/widgets/app_mark.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/fallbacks.dart';
import 'package:shnayim_mikra/ui/widgets/lang.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';
import 'package:shnayim_mikra/ui/widgets/sefer_tag.dart';

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

/// A signed-in member with a name, who has accepted the guidelines, whose
/// replies and todah can be held back ([gate]) and whose todah can fail
/// ([failTodah]).
class _Member extends DemoForumRepository {
  Completer<void>? gate;
  bool failTodah = false;
  int todahCalls = 0;

  Future<_Member> signIn() async {
    await verifyCode('reader@example.org', '123456');
    await updateDisplayName('Reader');
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
    await updateDisplayName('Reader');
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

/// A community whose forums' threads are asked for ([asked] times), wait
/// for [gate], and then fail while [offline].
class _HeldThreads extends DemoForumRepository {
  Completer<void>? gate;
  bool offline = false;
  int asked = 0;

  @override
  Future<List<ThreadSummary>> threads({
    int? forumId,
    int? parshaNumber,
    (DateTime, String)? after,
    int limit = ForumRepository.threadsPageSize,
  }) async {
    asked++;
    await gate?.future;
    if (offline) throw Exception('offline');
    return super.threads(forumId: forumId, parshaNumber: parshaNumber, after: after, limit: limit);
  }
}

/// A community whose forums, and whose reports, fail to load while
/// [offline].
class _OfflineCommunity extends DemoForumRepository {
  bool offline = true;

  @override
  Future<List<Forum>> forums() async => offline ? throw Exception('offline') : super.forums();

  @override
  Future<List<Report>> openReports() async => offline ? throw Exception('offline') : super.openReports();
}

/// A community whose forums, and their activity, fail to load while
/// [offline].
class _OfflineForumsAndStats extends _OfflineCommunity {
  @override
  Future<Map<int, ForumStats>> forumStats() async => offline ? throw Exception('offline') : super.forumStats();
}

/// A community whose threads, and their posts, fail to load while
/// [offline], each thread fetched counted ([threadsAsked]).
class _FlakyThread extends _Flaky {
  int threadsAsked = 0;

  @override
  Future<ThreadSummary> thread(String id) async {
    threadsAsked++;
    if (offline) throw Exception('offline');
    return super.thread(id);
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

/// A community whose App feedback forum is locked to moderators, and empty.
class _LockedFeedback extends DemoForumRepository {
  _LockedFeedback() : super(samples: false);

  @override
  Future<List<Forum>> forums() async => [
        for (final f in await super.forums())
          f.slug == 'feedback'
              ? Forum(id: f.id, slug: f.slug, nameEn: f.nameEn, nameHe: f.nameHe, locked: true)
              : f,
      ];
}

/// A community whose forums' activity can't be fetched (offline).
class _NoStats extends DemoForumRepository {
  @override
  Future<Map<int, ForumStats>> forumStats() async => throw Exception('offline');
}

/// A community whose forums' activity comes once [gate] completes.
class _SlowStats extends DemoForumRepository {
  final gate = Completer<void>();

  @override
  Future<Map<int, ForumStats>> forumStats() async {
    await gate.future;
    return super.forumStats();
  }
}

/// A member whose forums' lists are counted as they are fetched, by forum.
class _CountingThreads extends _Member {
  final fetched = <int?, int>{};

  @override
  Future<List<ThreadSummary>> threads({
    int? forumId,
    int? parshaNumber,
    (DateTime, String)? after,
    int limit = ForumRepository.threadsPageSize,
  }) {
    if (after == null) fetched[forumId] = (fetched[forumId] ?? 0) + 1;
    return super.threads(forumId: forumId, parshaNumber: parshaNumber, after: after, limit: limit);
  }
}

/// A member whose blocked members can't be fetched while [offline], and
/// who has blocked none.
class _NoBlockedList extends DemoForumRepository {
  bool offline = true;

  @override
  Future<Set<String>> blockedUsers() async => offline ? throw Exception('offline') : super.blockedUsers();
}

/// A member whose Unblock waits for [gate], is counted, and fails.
class _FailingUnblock extends DemoForumRepository {
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<void> unblock(String userId) async {
    calls++;
    await gate?.future;
    throw Exception('offline');
  }
}

/// The demo community, counting the codes it is sent to check ([checked]),
/// and turning each down if it [refuses], as the server does a code mistyped
/// or expired.
class _CheckedCodes extends DemoForumRepository {
  _CheckedCodes({this.refuses = false});

  final bool refuses;
  final checked = <String>[];

  @override
  Future<void> verifyCode(String email, String code) async {
    checked.add(code);
    if (refuses) throw const CommunityException('invalid_code');
    return super.verifyCode(email, code);
  }
}

/// A community on a server: no demo.
class _Server extends DemoForumRepository {
  @override
  bool get isDemo => false;
}

/// A signed-in member who can't reach the server to accept the guidelines.
class _OfflineNewcomer extends DemoForumRepository {
  @override
  Future<void> acceptGuidelines() async => throw Exception('offline');
}

/// A community whose server turns down new discussions with [code].
class _Refusing extends DemoForumRepository {
  _Refusing(this.code);
  final String code;

  Future<_Refusing> signIn() async {
    await verifyCode('reader@example.org', '123456');
    await updateDisplayName('Reader');
    await acceptGuidelines();
    return this;
  }

  @override
  Future<String> createThread({required int forumId, required String title, required String body, int? parshaNumber}) async =>
      throw CommunityException(code);
}

/// A community whose forums can't be paged: the first page comes, and no
/// other. Its forums start empty.
class _FirstPageOnly extends DemoForumRepository {
  _FirstPageOnly() : super(samples: false);

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
/// counted ([pages]). Its forums start empty.
class _SlowPaging extends DemoForumRepository {
  _SlowPaging() : super(samples: false);

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

/// [repo], whose forums start empty, with 40 pinned and 40 other threads in
/// Divrei Torah.
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

/// Signs in on the account page with a code, the six digits signing in as
/// the last is typed, and gives a new account the [name] it asks for.
Future<void> _signInWithCode(WidgetTester tester, {String name = 'Reader'}) async {
  expect(find.byType(AccountScreen), findsOneWidget);
  await tester.enterText(find.byType(TextField), 'reader@example.org');
  await tester.tap(find.text('Email me a code'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '123456');
  await tester.pumpAndSettle();
  expect(find.widgetWithText(FilledButton, 'Save name'), findsOneWidget, reason: 'a new account has a machine\'s name');
  await tester.enterText(find.byType(TextField), name);
  await tester.tap(find.widgetWithText(FilledButton, 'Save name'));
  await tester.pumpAndSettle();
}

/// The chip of the forum a new discussion is to begin in.
String _chosenForum(WidgetTester tester) {
  final chosen = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).where((c) => c.selected);
  return (chosen.single.label as Text).data!;
}

/// The focused text field's label, or null if none has the focus.
String? _focusedField(WidgetTester tester) {
  for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
    if (field.focusNode?.hasFocus ?? false) return field.decoration?.labelText;
  }
  return null;
}

/// The edge [finder]'s text is set from, by where its first letter stands:
/// left or right, as a paragraph that starts on that edge sets it.
TextAlign _setFrom(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final first = paragraph.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 1)).first;
  if (first.left.abs() < 0.5) return TextAlign.left;
  if ((first.right - paragraph.size.width).abs() < 0.5) return TextAlign.right;
  return TextAlign.center;
}

/// The week page's Discuss row, in either language.
final _discuss = find.descendant(of: find.byType(WeeklyThreadOpener), matching: find.byType(PaperRow));

Future<void> _tapDiscuss(WidgetTester tester) async {
  await tester.ensureVisible(_discuss);
  await tester.pumpAndSettle();
  await tester.tap(_discuss);
}

Future<void> _goBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

/// The Todah button that counts [count] thanks. In the demo's first thread,
/// Rivka's post has 4.
Finder _todahWith(int count) => find.ancestor(of: find.text('$count'), matching: find.bySubtype<TextButton>());

/// The Todah buttons, and the Reply buttons, of the posts.
final _todahButton = find.ancestor(of: find.text('Todah'), matching: find.bySubtype<TextButton>());
final _replyButton = find.ancestor(of: find.text('Reply'), matching: find.bySubtype<TextButton>());

Future<void> _tapTodah(WidgetTester tester, int count) async {
  await tester.ensureVisible(_todahWith(count));
  await tester.pump();
  await tester.tap(_todahWith(count));
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
    // Said on the page, and not again in a status message.
    const sent = 'We sent a 6-digit code to reader@example.org.';
    expect(find.descendant(of: find.byType(PageBody), matching: find.text(sent)), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(TextField), findsOneWidget, reason: 'one field, under the six boxes');
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue, reason: 'the code field takes the focus');
    // The last of the six digits signs in.
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(SnackBar), matching: find.text('Signed in as reader@example.org')), findsOneWidget);
    // A new account has a machine's name: the page asks for one, in a field
    // that takes the focus.
    expect(find.text('Display name'), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField), 'Rivka');
    await tester.tap(find.widgetWithText(FilledButton, 'Save name'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(PageBody), matching: find.text('Rivka')), findsOneWidget);
    expect(find.descendant(of: find.byType(PageBody), matching: find.text('reader@example.org')), findsOneWidget);
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
    expect(find.text('I’ll follow the community guidelines'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    // Sent, the reply is scrolled to, at the end of the thread, signed with
    // the name chosen.
    expect(find.text('Thank you, this helped me.'), findsOneWidget);
    final reply = find.ancestor(of: find.text('Thank you, this helped me.'), matching: find.byType(PostCard));
    expect(find.descendant(of: reply, matching: find.text('Rivka')), findsOneWidget);
    expect(find.descendant(of: reply, matching: find.textContaining('user_')), findsNothing);
    await _scrollThreadTo(tester, find.text('3 posts'), up: true);
    expect(find.text('3 posts'), findsOneWidget);
  });

  group('a new discussion', () {
    Future<ProviderContainer> compose(WidgetTester tester, {String forum = 'questions', DemoForumRepository? forums}) async {
      final c = await _pump(tester, forums: forums, now: DateTime(2026, 10, 12, 10));
      c.read(routerProvider).go('/community');
      await tester.pumpAndSettle();
      c.read(routerProvider).push('/community/new?forum=$forum');
      await tester.pumpAndSettle();
      return c;
    }

    final title = find.widgetWithText(TextField, 'Title');
    final message = find.widgetWithText(TextField, 'Your message');
    final postInAppBar = find.descendant(of: find.byType(AppBar), matching: find.widgetWithText(FilledButton, 'Post'));

    testWidgets('picks its forum from chips with their icons, the one asked for chosen', (tester) async {
      await compose(tester);
      expect(_chosenForum(tester), 'Questions & answers');
      final divreiTorah = find.widgetWithText(ChoiceChip, 'Divrei Torah');
      expect(find.descendant(of: divreiTorah, matching: find.byIcon(Icons.lightbulb_outline)), findsOneWidget);
      // Past the screen's edge: the row scrolls sideways.
      await tester.ensureVisible(divreiTorah);
      await tester.pumpAndSettle();
      await tester.tap(divreiTorah);
      await tester.pump();
      expect(_chosenForum(tester), 'Divrei Torah');
    });

    testWidgets('shows the forum asked for, though it lies past the edge of the screen', (tester) async {
      await compose(tester, forum: 'feedback');
      expect(_chosenForum(tester), 'App feedback');
      final chip = tester.getRect(find.widgetWithText(ChoiceChip, 'App feedback'));
      expect(chip.left, greaterThanOrEqualTo(0));
      expect(chip.right, lessThanOrEqualTo(412));
    });

    testWidgets('picks its forum from the keyboard, which keeps the focus on the chip', (tester) async {
      await compose(tester);
      Focus.of(tester.element(find.text('Divrei Torah'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(_chosenForum(tester), 'Divrei Torah');
      expect(Focus.of(tester.element(find.text('Divrei Torah'))).hasPrimaryFocus, isTrue);
      // And on from there.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(_chosenForum(tester), 'Divrei Torah');
    });

    testWidgets('says why Post is too soon, under each field, and gives the first the focus', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(supportsAnnounce: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final semantics = tester.ensureSemantics();
      await compose(tester);
      // Ready whenever a forum is chosen; until pressed, each field shows
      // only what it needs. It is the page's one Post, in the app bar, where
      // the keyboard never covers it.
      expect(tester.widget<FilledButton>(postInAppBar).onPressed, isNotNull);
      expect(find.widgetWithText(FilledButton, 'Post'), findsOneWidget);
      expect(find.text('At least 5 characters'), findsOneWidget);
      expect(find.text('At least 2 characters'), findsOneWidget);

      tester.takeAnnouncements();
      await tester.tap(postInAppBar);
      await tester.pump();
      expect(find.text('The title needs at least 5 characters.'), findsOneWidget);
      expect(find.text('The message needs at least 2 characters.'), findsOneWidget);
      expect(_focusedField(tester), 'Title');
      // Heard at once, and again from the field it lands in.
      expect([for (final a in tester.takeAnnouncements()) a.message], ['The title needs at least 5 characters.']);
      expect(
        tester.getSemantics(find.descendant(of: title, matching: find.byType(EditableText))),
        isSemantics(label: 'Title', hint: 'The title needs at least 5 characters.', isFocused: true, isTextField: true),
      );
      expect(find.byType(ThreadScreen), findsNothing);

      // Each error goes as its field is long enough, and the next is the
      // focus of the next press.
      await tester.enterText(title, 'On Rashi');
      await tester.pump();
      expect(find.text('The title needs at least 5 characters.'), findsNothing);
      expect(find.text('The message needs at least 2 characters.'), findsOneWidget);
      await tester.tap(postInAppBar);
      await tester.pump();
      expect(_focusedField(tester), 'Your message');
      semantics.dispose();
    });

    testWidgets('wraps a long title, which takes no line break, and goes on to the message', (tester) async {
      await compose(tester);
      final field = find.descendant(of: title, matching: find.byType(EditableText));
      final oneLine = tester.getSize(field).height;
      await tester.enterText(title, 'On the order of the second reading');
      await tester.pump();
      // Wrapped, all of it in view, rather than scrolled sideways.
      expect(tester.getSize(field).height, greaterThan(oneLine * 1.5));
      expect(tester.state<EditableTextState>(field).renderEditable.maxScrollExtent, 0);
      // However long, up to its 150 characters.
      await tester.enterText(title, List.filled(16, 'Question').join(' '));
      await tester.pump();
      expect(tester.getSize(field).height, greaterThan(oneLine * 5));
      expect(tester.state<EditableTextState>(field).renderEditable.maxScrollExtent, 0);
      // A line break pasted in is a space, so the title stays one line of
      // text, as the forum lists it.
      await tester.enterText(title, 'A question\non Rashi\r\nand Onkelos');
      await tester.pump();
      expect(tester.widget<TextField>(title).controller!.text, 'A question on Rashi and Onkelos');
      // So is any other break a line of text takes: a line separator, and
      // Word's manual line break (a vertical tab), say.
      await tester.enterText(title, 'A question\u2028on Rashi\vand Onkelos\u2029\f\u0085in full');
      await tester.pump();
      expect(tester.widget<TextField>(title).controller!.text, 'A question on Rashi and Onkelos in full');
      // The keyboard's action goes on to the message.
      expect(tester.widget<TextField>(title).textInputAction, TextInputAction.next);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(_focusedField(tester), 'Your message');
    });

    testWidgets('offers to discard a draft, 16 under the guidelines, once anything is written', (tester) async {
      await compose(tester);
      final discard = find.widgetWithText(TextButton, 'Discard draft');
      expect(discard, findsNothing);
      await tester.enterText(message, 'A thought');
      await tester.pump();
      await tester.ensureVisible(discard);
      await tester.pumpAndSettle();
      expect(tester.getRect(discard).top - tester.getRect(find.byType(LinkedText)).bottom, moreOrLessEquals(16, epsilon: 0.5));
      expect(tester.getCenter(discard).dx, moreOrLessEquals(tester.getCenter(find.byType(InfoCard)).dx, epsilon: 0.5));
      await tester.tap(discard);
      await tester.pump();
      expect(tester.widget<TextField>(message).controller!.text, isEmpty);
      expect(discard, findsNothing);
    });

    testWidgets('offers to discard a draft 16 under the paper, where the guidelines are accepted already', (tester) async {
      await compose(tester, forums: await _Member().signIn());
      expect(find.byType(LinkedText), findsNothing);
      final discard = find.widgetWithText(TextButton, 'Discard draft');
      await tester.enterText(message, 'A thought');
      await tester.pump();
      await tester.ensureVisible(discard);
      await tester.pumpAndSettle();
      expect(tester.getRect(discard).top - tester.getRect(find.byType(InfoCard)).bottom, moreOrLessEquals(16, epsilon: 0.5));
    });

    testWidgets('signed in with a name, is signed with it, and posts with Ctrl+Enter', (tester) async {
      final forums = await _Member().signIn();
      await compose(tester, forums: forums);
      expect(find.text('Posting as Reader'), findsOneWidget);
      expect(find.descendant(of: find.byType(InitialDisc), matching: find.text('R')), findsOneWidget);
      // The guidelines, accepted already, aren't asked about again.
      expect(find.byType(LinkedText), findsNothing);
      await tester.enterText(title, 'A question on Rashi');
      await tester.enterText(message, 'Why does Rashi explain this word?');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(ThreadScreen), findsOneWidget);
      expect(find.text('A question on Rashi'), findsOneWidget);
      expect(find.text('Reader'), findsWidgets);
    });

    testWidgets("shows a server's error under the field it is about, and others as a status", (tester) async {
      await compose(tester, forums: await _Refusing('content_rejected').signIn());
      await tester.enterText(title, 'A question on Rashi');
      await tester.enterText(message, 'Why does Rashi explain this word?');
      await tester.tap(postInAppBar);
      await tester.pumpAndSettle();
      const rejected = 'That message can’t be posted. Please review the community guidelines.';
      expect(find.descendant(of: find.byType(InfoCard), matching: find.text(rejected)), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(_focusedField(tester), 'Your message');

      await compose(tester, forums: await _Refusing('rate_limited').signIn());
      await tester.enterText(title, 'A question on Rashi');
      await tester.enterText(message, 'Why does Rashi explain this word?');
      await tester.tap(postInAppBar);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(SnackBar), matching: find.text('You’re posting quickly — please wait a few seconds.')), findsOneWidget);
    });

    testWidgets("keeps a server's error under its field until that field is changed", (tester) async {
      await compose(tester, forums: await _Refusing('too_many_links').signIn());
      await tester.enterText(title, 'A question on Rashi');
      await tester.enterText(message, 'See https://a.example and https://b.example');
      await tester.tap(postInAppBar);
      await tester.pumpAndSettle();
      const links = 'New members can include at most 2 links.';
      expect(find.text(links), findsOneWidget);
      // A typo fixed in the title leaves it, as the links are still there.
      await tester.enterText(title, 'A question on Rashi.');
      await tester.pump();
      expect(find.text(links), findsOneWidget);
      // So does a window resized.
      tester.view.physicalSize = const Size(800, 900);
      await tester.pumpAndSettle();
      expect(find.text(links), findsOneWidget);
      await tester.enterText(message, 'See the commentary');
      await tester.pumpAndSettle();
      expect(find.text(links), findsNothing);
    });

    testWidgets('counts its characters only near the limit, in the number format of the language', (tester) async {
      await compose(tester);
      await tester.enterText(title, 'x' * 119);
      await tester.pump();
      expect(find.textContaining('/150'), findsNothing);
      await tester.enterText(title, 'x' * 120);
      await tester.pump();
      expect(find.text('120/150'), findsOneWidget);
      await tester.enterText(message, 'x' * 8000);
      await tester.pump();
      expect(find.text('8,000/10,000'), findsOneWidget);
    });

    testWidgets('closes with its close button, keeping the draft', (tester) async {
      final c = await compose(tester);
      await tester.enterText(title, 'A question on Rashi');
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(ComposeScreen), findsNothing);
      expect(c.read(sharedPreferencesProvider).getString('draft.newThread'), contains('A question on Rashi'));
    });
  });

  testWidgets('a first post after signing in is signed with the name chosen, never a machine\'s', (tester) async {
    // Signed in before, and never named.
    final forums = DemoForumRepository();
    await forums.verifyCode('reader@example.org', '123456');
    final c = await _pump(tester, forums: forums);
    c.read(routerProvider).go('/community/thread/1');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Write a reply'), 'Thank you.');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reply'));
    await tester.pumpAndSettle();
    // Asked for a name, the page goes back only once it is saved. Its field
    // has the focus as the page opens on it.
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save name'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isTrue);
    await tester.tap(find.widgetWithText(FilledButton, 'Save name'));
    await tester.pumpAndSettle();
    expect(find.text('Names must be 2–40 characters.'), findsOneWidget);
    expect(find.byType(AccountScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Rivka');
    await tester.tap(find.widgetWithText(FilledButton, 'Save name'));
    await tester.pumpAndSettle();
    expect(find.byType(ThreadScreen), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    final posts = await forums.posts('1');
    expect(posts.last.body, 'Thank you.');
    expect(posts.last.authorName, 'Rivka');
  });

  testWidgets('a reply is not sent by a member who leaves the name unchosen', (tester) async {
    final forums = DemoForumRepository();
    await forums.verifyCode('reader@example.org', '123456');
    final c = await _pump(tester, forums: forums);
    c.read(routerProvider).go('/community/thread/1');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Write a reply'), 'Thank you.');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reply'));
    await tester.pumpAndSettle();
    await _goBack(tester);
    expect(find.byType(ThreadScreen), findsOneWidget);
    expect((await forums.posts('1')).where((p) => p.body == 'Thank you.'), isEmpty);
    expect(find.text('Thank you.'), findsOneWidget, reason: 'the reply waits in its box');
  });

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    testWidgets('new discussion: the empty fields run the way of the ${language.name} UI, and then of their text',
        (tester) async {
      final rtl = language == AppLanguage.hebrew;
      final ui = rtl ? TextDirection.rtl : TextDirection.ltr;
      final c = await _pump(tester, settings: AppSettings(onboardingComplete: true, language: language));
      c.read(routerProvider).go('/community/new');
      await tester.pumpAndSettle();
      Finder field(int maxLength) => find.byWidgetPredicate((w) => w is TextField && w.maxLength == maxLength);
      TextDirection direction(Finder field) =>
          tester.widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText))).textDirection!;
      final (title, body) = (field(150), field(10000));
      expect(direction(title), ui);
      expect(direction(body), ui);
      // The decoration follows the UI, whatever the text's direction: the
      // helper is at the field's start, on the right in Hebrew, and the
      // counter, shown near the limit, at its end.
      final helper = find.text(rtl ? 'לפחות 5 תווים' : 'At least 5 characters');
      bool atStart(Finder f) =>
          rtl ? tester.getCenter(f).dx > tester.getCenter(title).dx : tester.getCenter(f).dx < tester.getCenter(title).dx;
      expect(atStart(helper), isTrue);

      await tester.enterText(title, rtl ? 'Shalom' : 'שלום');
      await tester.enterText(body, '12345');
      await tester.pump();
      expect(direction(title), rtl ? TextDirection.ltr : TextDirection.rtl, reason: 'the way of its text');
      expect(direction(body), ui, reason: 'digits alone have no direction of their own');
      expect(atStart(helper), isTrue);

      // Past 80% of the 150 characters.
      await tester.enterText(title, (rtl ? 'Shalom ' : 'שלום ') * 25);
      await tester.pump();
      final counter = find.textContaining('/150');
      expect(counter, findsOneWidget);
      expect(atStart(counter), isFalse, reason: "at the field's end, on the left in Hebrew");
      // Past the draft's save.
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('a reply starts right to left in the Hebrew UI, and runs the way of its text', (tester) async {
    final c = await _pump(tester, settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew));
    c.read(routerProvider).go('/community/thread/1');
    await tester.pumpAndSettle();
    final reply = find.descendant(of: find.byType(TextField).last, matching: find.byType(EditableText));
    expect(tester.widget<EditableText>(reply).textDirection, TextDirection.rtl);
    await tester.enterText(reply, 'Thank you');
    await tester.pump();
    expect(tester.widget<EditableText>(reply).textDirection, TextDirection.ltr);
    await tester.enterText(reply, '');
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<EditableText>(reply).textDirection, TextDirection.rtl);
  });

  testWidgets('an edited post runs the way of its text as it is edited', (tester) async {
    final forums = await _Member().signIn();
    forums.seed(
      threads: [_thread(7100)],
      posts: [Post(id: '1', threadId: '7100', authorId: 'me', authorName: 'Me', body: 'שלום לכולם', createdAt: DateTime(2026, 10, 1))],
    );
    final c = await _pump(tester, forums: forums);
    c.read(routerProvider).go('/community/thread/7100');
    await tester.pumpAndSettle();
    await _openPostMenu(tester, 0);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final field = find.descendant(of: find.byType(AlertDialog), matching: find.byType(EditableText));
    TextDirection direction() => tester.widget<EditableText>(field).textDirection!;
    expect(direction(), TextDirection.rtl);
    await tester.enterText(field, 'Hello all');
    await tester.pump();
    expect(direction(), TextDirection.ltr);
    await tester.enterText(field, 'שלום');
    await tester.pump();
    expect(direction(), TextDirection.rtl);
    await tester.enterText(field, '');
    await tester.pump();
    expect(direction(), TextDirection.ltr, reason: "empty, the English UI's way");
  });

  testWidgets('in the Hebrew UI, the address a code went to keeps its own order', (tester) async {
    final c = await _pump(tester, settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew));
    c.read(routerProvider).go('/community/account');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1reader@example.org');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    final sent = find.textContaining(ltr('1reader@example.org'));
    expect(find.descendant(of: find.byType(PageBody), matching: sent), findsOneWidget);
    // In a status message too, once the code is sent again.
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(seconds: 30));
    await tester.tap(find.widgetWithText(TextButton, 'שליחת הקוד שוב'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(SnackBar), matching: sent), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    // Signed in, the page stays until the account has a name.
    expect(find.byType(AccountScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Rivka');
    tester.takeAnnouncements();
    await tester.tap(find.widgetWithText(FilledButton, 'Save name'));
    await tester.pumpAndSettle();

    expect(find.byType(ThreadScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing, reason: 'nothing covers the reply box');
    expect([for (final a in tester.takeAnnouncements()) a.message], ['Signed in as Rivka']);
    // The reply goes on: a first post asks to accept the guidelines.
    expect(find.text('I’ll follow the community guidelines'), findsOneWidget);
  });

  testWidgets('in Hebrew, signing in says that it worked, and the page then names the account', (tester) async {
    final c = await _pump(tester, settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew));
    c.read(routerProvider).go('/community/account');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'reader@example.org');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final status = find.textContaining(RegExp('^התחברת בשם '));
    expect(find.descendant(of: find.byType(SnackBar), matching: status), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    // Without a name of its own yet, the page asks for one; saved, the
    // account's card is headed by it.
    expect(find.descendant(of: find.byType(PageBody), matching: find.text('שם תצוגה')), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'רבקה');
    await tester.tap(find.widgetWithText(FilledButton, 'שמירת השם'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(PageBody), matching: find.text('רבקה')), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
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
      // The page of the two read together (its app bar's title, revealed
      // on scrolling, is left out where the test font makes it too wide).
      expect(tester.widget<WeekOverview>(find.byType(WeekOverview)).ctx.id, '5787:42-43');

      await _tapDiscuss(tester);
      await tester.pumpAndSettle();
      expect(_location(c), matches(RegExp(r'^/community/thread/\d+$')));
      expect(find.byType(ThreadScreen), findsOneWidget);
      expect(forums.asked, [(42, 5787)]);
      // The heading, under its forum's name in the app bar.
      expect(find.text('Parshat Matot-Masei 5787'), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Parshat HaShavua')), findsOneWidget);
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
      expect(find.text('Parshat Noach 5787'), findsOneWidget);
    });

    testWidgets("opens from Today for this week's parsha", (tester) async {
      final forums = _Threads();
      final c = await _pump(tester, forums: forums);
      final card = find.text('Discuss this week’s parsha');
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(forums.asked, [(1, 5787)]);
      expect(_location(c), matches(RegExp(r'^/community/thread/\d+$')));
      expect(find.text('Parshat Bereshit 5787'), findsOneWidget);
    });

    testWidgets('offline says so, rather than loading forever', (tester) async {
      final c = await _pump(tester, forums: _Threads()..offline = true);
      c.read(routerProvider).go('/parsha/week/5787:1');
      await tester.pumpAndSettle();
      await _tapDiscuss(tester);
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t reach the server. Check your connection and try again.'), findsOneWidget);
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<PaperRow>(_discuss).onTap, isNotNull);
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
      Text appBarTitle() =>
          tester.widget<Text>(find.descendant(of: find.byType(AppBar), matching: find.byType(Text)).first);
      expect(appBarTitle().data, 'פרשת השבוע');
      expect(tester.widget<Text>(find.text('פרשת בראשית תשפ״ז')).textDirection, TextDirection.rtl);

      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      expect(appBarTitle().data, 'שאלות ותשובות');
      // English, from its own start edge, as the forum lists it.
      final heading = tester.widget<Text>(find.text('Why read the Targum rather than a translation?'));
      expect(heading.textDirection, TextDirection.ltr);
      expect(heading.textAlign, TextAlign.start);
      expect(_setFrom(tester, find.text('Why read the Targum rather than a translation?')), TextAlign.left);
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
    await tester.tap(find.text('Clear this week’s progress'));
    await tester.pumpAndSettle();
    expect(find.text('Clear all progress for Bereshit?'), findsOneWidget, reason: "the dialog's title");
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
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
      await forums.updateDisplayName('Reader');
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
      expect(find.text('Couldn’t reach the server. Check your connection and try again.'), findsOneWidget);
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
      await _tapTodah(tester, 4);
      await tester.pump();
      expect(_todahWith(5), findsOneWidget);
      await _tapTodah(tester, 5);
      await tester.pump();
      expect(forums.todahCalls, 1);

      forums.gate!.complete();
      await tester.pumpAndSettle();
      expect(_todahWith(5), findsOneWidget);
      expect(find.byIcon(Icons.volunteer_activism), findsOneWidget);
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
      await _tapTodah(tester, 4);
      await tester.pump();
      expect(_todahWith(5), findsOneWidget);
      forums.gate!.complete();
      await tester.pumpAndSettle();
      expect(_todahWith(4), findsOneWidget);
      expect(find.byIcon(Icons.volunteer_activism), findsNothing);
      expect(find.text('Couldn’t reach the server. Check your connection and try again.'), findsOneWidget);
    });

    Future<void> signInFromThePrompt(WidgetTester tester) async {
      await _signInWithCode(tester);
      expect(find.byType(ThreadScreen), findsOneWidget);
    }

    testWidgets('tapped signed out, and given before, stays given once signed in', (tester) async {
      final forums = await _Member().signIn();
      await forums.setTodah('2', true);
      await forums.signOut();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.volunteer_activism), findsNothing, reason: 'signed out, none are yours');

      await _tapTodah(tester, 5);
      await tester.pumpAndSettle();
      await signInFromThePrompt(tester);
      expect(find.byIcon(Icons.volunteer_activism), findsOneWidget);
      expect(_todahWith(5), findsOneWidget);
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
        matching: find.text('Todah'),
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
      await _tapTodah(tester, 4);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.volunteer_activism), findsOneWidget);

      await forums.signOut();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.volunteer_activism), findsNothing);
      expect(_todahWith(5), findsOneWidget);
    });
  });

  testWidgets("a thread's one heading is its title, which names the page; its forum's over it is none", (tester) async {
    final semantics = tester.ensureSemantics();
    final c = await _pump(tester);
    c.read(routerProvider).go('/community/thread/1');
    await tester.pumpAndSettle();
    const title = 'Why read the Targum rather than a translation?';
    final headings = [
      for (final node in find.semantics.byPredicate((node) => node.getSemanticsData().headingLevel == 1).evaluate())
        node.getSemanticsData(),
    ];
    expect([for (final h in headings) h.label], [title]);
    expect(headings.single.flagsCollection.namesRoute, isTrue);
    final forum = tester.getSemantics(find.descendant(of: find.byType(AppBar), matching: find.text('Questions & answers')));
    expect(forum.getSemanticsData().flagsCollection.isHeader, isFalse);
    expect(forum.getSemanticsData().flagsCollection.namesRoute, isFalse);
    semantics.dispose();
  });

  testWidgets('a post is numbered, and its todah is a toggle named for what a tap does', (tester) async {
    final semantics = tester.ensureSemantics();
    final forums = await _Member().signIn();
    final c = await _pump(tester, forums: forums);
    c.read(routerProvider).go('/community/thread/1');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'^Post 2 of 2\n')), findsOneWidget);
    expect(find.byTooltip('More options for Rivka'), findsOneWidget);

    Finder todahOf(int post) => find.descendant(of: find.byType(PostCard).at(post), matching: _todahButton);
    final todah = todahOf(1);
    // Its name holds the word it shows, Todah, so that voice control finds it
    // by what it says (WCAG 2.5.3).
    expect(
      tester.getSemantics(todah),
      isSemantics(label: 'Say todah to Rivka. Thanked 4 times', isButton: true, hasToggledState: true, isToggled: false),
    );
    await _tapTodah(tester, 4);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(todah),
      isSemantics(label: 'Remove your todah to Rivka. Thanked 5 times', isButton: true, hasToggledState: true, isToggled: true),
    );
    // Thanked by no one yet, it names only what a tap does.
    expect(
      tester.getSemantics(todahOf(0)),
      isSemantics(label: 'Say todah to Avraham', isButton: true, hasToggledState: true, isToggled: false),
    );
    // Thanked once, it holds the digit it shows, "1", as with any other count.
    await tester.ensureVisible(todahOf(0));
    await tester.pumpAndSettle();
    await tester.tap(todahOf(0));
    await tester.pumpAndSettle();
    expect(find.descendant(of: todahOf(0), matching: find.text('1')), findsOneWidget);
    expect(
      tester.getSemantics(todahOf(0)),
      isSemantics(label: 'Remove your todah to Avraham. Thanked 1 time', isButton: true, hasToggledState: true, isToggled: true),
    );
    for (final i in [0, 1]) {
      expect(tester.getSemantics(todahOf(i)).label.toLowerCase(), contains('todah'));
    }
    semantics.dispose();
  });

  group('a post, set as a letter,', () {
    testWidgets('names its writer, tagged in a question they asked, and when it was written', (tester) async {
      final semantics = tester.ensureSemantics();
      final c = await _pump(tester);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      // Avraham asked; Rivka answered.
      final asked = find.ancestor(of: find.text('Question'), matching: find.byType(PostCard));
      expect(asked, findsOneWidget);
      expect(find.descendant(of: asked, matching: find.text('Avraham')), findsOneWidget);
      // The name, the tag and the time, each a text of its own, are read as
      // one, with the full date.
      expect(find.bySemanticsLabel(RegExp(r'^Post 1 of 2\nAvraham, Question, \w+day, ')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Post 2 of 2\nRivka, \w+day, ')), findsOneWidget);
      semantics.dispose();
    });

    // The asker's later words are no question: Author, as in any other
    // discussion.
    testWidgets('by the member who asked a question is tagged Question only on the post that asked it', (tester) async {
      final semantics = tester.ensureSemantics();
      final forums = DemoForumRepository()
        ..seed(posts: [
          Post(
            id: '9200',
            threadId: '1',
            authorId: 'demo-author',
            authorName: 'Avraham',
            body: 'Thanks, that answers it.',
            createdAt: DateTime.now(),
          ),
        ]);
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      await _scrollThreadTo(tester, find.text('Thanks, that answers it.'));
      final thanks = find.ancestor(of: find.text('Thanks, that answers it.'), matching: find.byType(PostCard));
      expect(find.descendant(of: thanks, matching: find.text('Author')), findsOneWidget);
      expect(find.descendant(of: thanks, matching: find.text('Question')), findsNothing);
      expect(find.bySemanticsLabel(RegExp(r'^Post 3 of 3\nAvraham, Author, ')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Post 1 of 3\nAvraham, Question, ')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('by the member who began a discussion is tagged Author, in each of their posts', (tester) async {
      final c = await _pump(tester);
      c.read(routerProvider).go('/community/thread/11');
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Parshat HaShavua')), findsOneWidget);
      await _scrollThreadTo(tester, find.text('Of course. Hebrew and English are both welcome here.'));
      final tagged = find.ancestor(of: find.text('Author'), matching: find.byType(PostCard));
      expect(tagged, findsNWidgets(2), reason: "Chana's welcome and her answer");
      expect(find.descendant(of: tagged, matching: find.text('Chana')), findsNWidgets(2));
      expect(find.text('Question'), findsNothing);
    });

    testWidgets('offers Reply, which answers it in the reply box, until let go', (tester) async {
      final semantics = tester.ensureSemantics();
      final c = await _pump(tester);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      final replies = find.descendant(of: find.byType(PostCard), matching: _replyButton);
      expect(replies, findsNWidgets(2), reason: 'one under each post');
      expect(tester.getSemantics(replies.last), isSemantics(label: 'Reply to Rivka', isButton: true));

      await tester.ensureVisible(replies.last);
      await tester.pumpAndSettle();
      await tester.tap(replies.last);
      await tester.pumpAndSettle();
      expect(find.text('Replying to \u2068Rivka\u2069'), findsOneWidget);
      final field = find.descendant(of: find.byType(TextField), matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue, reason: 'the reply box takes the focus');

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Replying to'), findsNothing);
      semantics.dispose();
    });

    testWidgets('in a locked thread offers no Reply, but to a moderator', (tester) async {
      final c = await _pump(tester);
      c.read(routerProvider).go('/community/thread/51');
      await tester.pumpAndSettle();
      expect(find.text('This discussion is locked.'), findsOneWidget);
      expect(find.byType(PostCard), findsNWidgets(2));
      expect(find.descendant(of: find.byType(PostCard), matching: _replyButton), findsNothing);
      expect(find.byType(TextField), findsNothing);

      // The demo's members are moderators.
      final forums = await _Member().signIn();
      final m = await _pump(tester, forums: forums);
      m.read(routerProvider).go('/community/thread/51');
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(PostCard), matching: _replyButton), findsNWidgets(2));
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('of your own shows the thanks it was given, without a button, once it has any', (tester) async {
      final semantics = tester.ensureSemantics();
      final forums = await _Member().signIn();
      forums.seed(posts: [
        Post(id: '9100', threadId: '1', authorId: 'me', authorName: 'Leah', body: 'Thanked', createdAt: DateTime.now(), todah: 3),
        Post(id: '9101', threadId: '1', authorId: 'me', authorName: 'Leah', body: 'Not yet', createdAt: DateTime.now()),
      ]);
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      Finder post(String body) => find.ancestor(of: find.text(body), matching: find.byType(PostCard));

      await _scrollThreadTo(tester, find.text('Not yet'));
      expect(find.descendant(of: post('Thanked'), matching: _todahButton), findsNothing);
      expect(find.descendant(of: post('Thanked'), matching: find.text('3')), findsOneWidget);
      // Read with the post, as its last line.
      expect(tester.getSemantics(post('Thanked')).label, endsWith('\nThanked 3 times'));
      expect(find.descendant(of: post('Not yet'), matching: _todahButton), findsNothing);
      expect(find.descendant(of: post('Not yet'), matching: find.byIcon(Icons.volunteer_activism_outlined)), findsNothing);
      // Each can still be answered.
      expect(find.descendant(of: post('Not yet'), matching: _replyButton), findsOneWidget);
      semantics.dispose();
    });

    /// The opening post's rule, in [post].
    Finder ruleIn(Finder post) =>
        find.descendant(of: post, matching: find.byWidgetPredicate((w) => w is PositionedDirectional && w.width == 3));

    testWidgets('that opened the thread is ruled in the gutter, its text in the column the others share', (tester) async {
      final c = await _pump(tester);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      final posts = find.byType(PostCard);
      expect(ruleIn(posts.at(0)), findsOneWidget);
      expect(ruleIn(posts.at(1)), findsNothing);
      // The same column of text for every letter, the rule hung before it.
      double textLeft(int i) => tester.getTopLeft(find.descendant(of: posts.at(i), matching: find.byType(SelectableText))).dx;
      expect(textLeft(0), textLeft(1));
      final rule = tester.getRect(ruleIn(posts.at(0)));
      expect(rule.right, tester.getRect(posts.at(0)).left - 12);
      // From the top of the initial.
      expect(rule.top, tester.getTopLeft(find.descendant(of: posts.at(0), matching: find.byType(InitialDisc))).dy);
    });

    testWidgets('that opened the thread takes no rule once its member is blocked', (tester) async {
      final forums = await _Member().signIn();
      final avraham = (await forums.posts('1')).first.authorId!;
      await forums.block(avraham);
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      expect(find.byType(PostCard), findsOneWidget, reason: "Rivka's answer alone");
      expect(ruleIn(find.byType(PostCard)), findsNothing);
    });

    testWidgets('takes no rule while the earliest posts of a long thread are still to load', (tester) async {
      final c = await _pump(tester, forums: _withLongThread(DemoForumRepository()));
      c.read(routerProvider).go('/community/thread/5000');
      await tester.pumpAndSettle();
      expect(find.text('Show earlier posts'), findsOneWidget);
      expect(ruleIn(find.byType(PostCard).first), findsNothing);
    });

    testWidgets('of a weekly thread takes no rule nor tag: the thread is the community\'s', (tester) async {
      final forums = DemoForumRepository()..isCurrentWeek = (parsha, year) => true;
      final id = await forums.weeklyThread(parshaNumber: 1, hebrewYear: 5787, title: 'Bereshit · בראשית · 5787');
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/$id');
      await tester.pumpAndSettle();
      expect(find.byType(PostCard), findsWidgets);
      expect(ruleIn(find.byType(PostCard).first), findsNothing);
      expect(find.text('Question'), findsNothing);
      expect(find.text('Author'), findsNothing);
    });

    testWidgets("opens its menu from the whole of its button, whose glyph ends on the column's edge", (tester) async {
      final c = await _pump(tester);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      final post = find.byType(PostCard).first;
      final button = find.descendant(of: post, matching: find.byType(PopupMenuButton<String>));
      final box = tester.getRect(button);
      expect(box.width, greaterThanOrEqualTo(48));
      final text = tester.getRect(find.descendant(of: post, matching: find.byType(SelectableText)));
      expect(tester.getRect(find.descendant(of: button, matching: find.byIcon(Icons.more_vert))).right, text.right);
      // Its outer edge, in the gutter, takes the tap too.
      await tester.tapAt(box.centerRight - const Offset(2, 0));
      await tester.pumpAndSettle();
      expect(find.byType(SeferMenuItem<String>), findsWidgets);
    });

    testWidgets('of your own, unthanked, puts Reply where the others put Todah, in line with the text', (tester) async {
      final forums = await _Member().signIn();
      forums.seed(posts: [
        Post(id: '9101', threadId: '1', authorId: 'me', authorName: 'Leah', body: 'Not yet', createdAt: DateTime.now()),
      ]);
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      await _scrollThreadTo(tester, find.text('Not yet'));
      Finder post(String body) => find.ancestor(of: find.text(body), matching: find.byType(PostCard));
      final mine = tester.getRect(find.descendant(of: post('Not yet'), matching: find.byIcon(Icons.reply)));
      final todah = tester.getRect(find.descendant(of: find.byType(PostCard).at(1), matching: find.byIcon(Icons.volunteer_activism_outlined)));
      expect(mine.left, todah.left);
      final text = tester.getRect(find.descendant(of: post('Not yet'), matching: find.byType(SelectableText)));
      expect(mine.left, text.left);
    });

    testWidgets('at 200% text, puts the time under the name with no separator, the initial on the first line', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final c = await _pump(tester);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      final post = find.byType(PostCard).first;
      final name = tester.getRect(find.descendant(of: post, matching: find.text('Avraham')));
      final times = tester.widgetList<Text>(find.descendant(of: post, matching: find.byType(Text))).where((t) => t.style?.fontSize == Theme.of(tester.element(post)).textTheme.bodySmall?.fontSize);
      expect(times, isNotEmpty);
      expect(times.first.data, isNot(startsWith(' · ')), reason: 'no separator leading a line of its own');
      expect(tester.getTopLeft(find.byWidget(times.first)).dy, greaterThanOrEqualTo(name.bottom - 1));
      final disc = tester.getRect(find.descendant(of: post, matching: find.byType(InitialDisc)));
      expect(disc.center.dy, moreOrLessEquals(name.center.dy, epsilon: 1));
      expect(tester.getRect(ruleIn(post)).top, disc.top, reason: 'the rule starts at the top of the initial');
    });

    testWidgets('in high contrast, keeps its name on the line its initial and menu are centred on, by its outlined tag',
        (tester) async {
      final c = await _pump(tester, settings: const AppSettings(onboardingComplete: true, theme: AppThemeMode.highContrastDark));
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      final post = find.byType(PostCard).first;
      final name = tester.getRect(find.descendant(of: post, matching: find.text('Avraham')));
      // The tag, with its outline outside its padding, stands taller than the
      // name's line.
      final tag = tester.getRect(find.descendant(of: post, matching: find.byType(SeferTag)));
      expect(tag.height, greaterThan(name.height));
      expect(tag.center.dy, moreOrLessEquals(name.center.dy, epsilon: 0.5));
      final disc = tester.getRect(find.descendant(of: post, matching: find.byType(InitialDisc)));
      expect(disc.center.dy, moreOrLessEquals(name.center.dy, epsilon: 0.5));
      final menu = tester.getRect(find.descendant(of: post, matching: find.byTooltip('More options for Avraham')));
      expect(menu.center.dy, moreOrLessEquals(name.center.dy, epsilon: 0.5));
    });

    testWidgets('is edited in a labelled field that takes the focus', (tester) async {
      final forums = await _Member().signIn();
      forums.seed(posts: [
        Post(id: '9100', threadId: '1', authorId: 'me', authorName: 'Leah', body: 'A first thought', createdAt: DateTime.now()),
      ]);
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      await _scrollThreadTo(tester, find.text('A first thought'));
      await tester.tap(find.descendant(
        of: find.ancestor(of: find.text('A first thought'), matching: find.byType(PostCard)),
        matching: find.byTooltip('More options for Leah'),
      ));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SeferMenuItem<String>, 'Edit'), findsOneWidget);
      expect(find.widgetWithText(SeferMenuItem<String>, 'Reply'), findsNothing, reason: 'Reply is under each post instead');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      final field = tester.widget<TextField>(find.descendant(of: dialog, matching: find.byType(TextField)));
      expect(field.decoration?.labelText, 'Your message');
      expect(field.maxLength, 10000);
      // Its counter quiet until the message nears the limit, as Compose's.
      expect(find.descendant(of: dialog, matching: find.textContaining('/10')), findsNothing);
      expect(tester.widget<EditableText>(find.descendant(of: dialog, matching: find.byType(EditableText))).focusNode.hasFocus, isTrue);
      final editing = find.descendant(of: dialog, matching: find.byType(TextField));
      await tester.enterText(editing, 'x' * 7999);
      await tester.pump();
      expect(find.descendant(of: dialog, matching: find.textContaining('/10')), findsNothing);
      await tester.enterText(editing, 'x' * 8000);
      await tester.pump();
      expect(find.descendant(of: dialog, matching: find.text('8,000/10,000')), findsOneWidget);
      await tester.enterText(editing, 'A first thought');
      await tester.pump();
      // Save waits for a change, of 2 characters at least, as a reply does.
      FilledButton save() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
      expect(save().onPressed, isNull, reason: 'nothing changed');
      await tester.enterText(find.descendant(of: dialog, matching: find.byType(TextField)), 'A');
      await tester.pump();
      expect(save().onPressed, isNull, reason: 'too short');
      await tester.enterText(find.descendant(of: dialog, matching: find.byType(TextField)), 'A second thought');
      await tester.pump();
      expect(save().onPressed, isNotNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('A second thought'), findsOneWidget);
    });
  });

  group('the reply box', () {
    testWidgets('waits for a reply, and says while it is sent', (tester) async {
      final semantics = tester.ensureSemantics();
      final forums = await _Member().signIn();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      final send = find.widgetWithText(FilledButton, 'Reply');
      FilledButton button() => tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button().onPressed, isNull, reason: 'nothing to send yet');
      await tester.enterText(find.widgetWithText(TextField, 'Write a reply'), 'Agreed.');
      await tester.pump();
      expect(button().onPressed, isNotNull);

      forums.gate = Completer<void>();
      await tester.tap(send);
      await tester.pump();
      expect(find.descendant(of: find.byType(FilledButton), matching: find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(find.bySemanticsLabel('Sending…'), findsOneWidget);
      forums.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Sending…'), findsNothing);
      expect(find.text('Agreed.'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('starts at the interface\'s edge, and follows what is typed', (tester) async {
      const hebrew = AppSettings(onboardingComplete: true, language: AppLanguage.hebrew);
      final c = await _pump(tester, settings: hebrew);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      TextDirection? direction() => tester.widget<TextField>(find.byType(TextField)).textDirection;
      expect(direction(), TextDirection.rtl);
      await tester.enterText(find.byType(TextField), 'Thank you');
      await tester.pump();
      expect(direction(), TextDirection.ltr);
    });

    testWidgets('lines up with the column of posts on a wide screen', (tester) async {
      final c = await _pump(tester);
      tester.view.physicalSize = const Size(1366, 860);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      final field = tester.getRect(find.byType(TextField));
      final send = tester.getRect(find.byType(FilledButton));
      final body = tester.getRect(find.byType(PostCard).first);
      expect(field.left, body.left);
      // A post reaches past the column only by the box of its menu button.
      expect(send.right, moreOrLessEquals(body.right - PostCard.menuBleed));
    });
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
      expect(find.text('Couldn’t reach the server. Check your connection and try again.'), findsOneWidget);
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
      expect(find.text('Couldn’t reach the server. Check your connection and try again.'), findsOneWidget);
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
      expect(find.text('Couldn’t reach the server. Check your connection and try again.'), findsOneWidget);
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
      expect(find.text('Couldn’t reach the server. Check your connection and try again.'), findsOneWidget);
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
      final c = await _pump(tester, forums: _withManyThreads(DemoForumRepository(samples: false)));
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
      expect(find.text('Couldn’t reach the server. Check your connection and try again.'), findsOneWidget);
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
      // A block can be undone: confirmed with the plain Filled button.
      final block = find.widgetWithText(FilledButton, 'Block Rivka');
      expect(tester.widget<FilledButton>(block).style, isNull);
      await tester.tap(block);
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
      // The forum counts the replies: the posts after the first.
      final tile = find.widgetWithText(ThreadTile, 'Why read the Targum rather than a translation?');
      expect(find.descendant(of: tile, matching: find.textContaining('2\u00a0replies')), findsOneWidget);
      await tester.tap(find.text('Why read the Targum rather than a translation?'));
      await tester.pumpAndSettle();
      expect(find.text('3 posts'), findsOneWidget);

      await _scrollThreadTo(tester, find.text('A thought to take back.'));
      // The post's own menu: the first post may no longer be built, so the
      // posts on screen can't be counted from the top.
      await tester.tap(find.descendant(
        of: find.ancestor(of: find.text('A thought to take back.'), matching: find.byType(PostCard)),
        matching: find.byTooltip(RegExp('^More options for ')),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      // A deletion can't be undone: the dialog says so, and confirms it in
      // error's ink.
      final dialog = find.byType(AlertDialog);
      expect(find.descendant(of: dialog, matching: find.text('Delete this post?')), findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text('This can’t be undone.')), findsOneWidget);
      final confirm = find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, 'Delete'));
      final scheme = Theme.of(tester.element(confirm)).colorScheme;
      expect(tester.widget<FilledButton>(confirm).style?.backgroundColor?.resolve({}), scheme.error);
      expect(tester.widget<FilledButton>(confirm).style?.foregroundColor?.resolve({}), scheme.onError);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await _scrollThreadTo(tester, find.text('2 posts'), up: true);
      expect(find.text('2 posts'), findsOneWidget);

      await _goBack(tester);
      expect(find.descendant(of: tile, matching: find.textContaining('1\u00a0reply')), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.textContaining('2\u00a0replies')), findsNothing);
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
    // As its forum lists it: under Pinned, before the rest.
    final top = tester.getTopLeft(find.text('Why read the Targum rather than a translation?')).dy;
    final heading = find.descendant(of: find.byType(GroupHeader), matching: find.text('Pinned'));
    expect(top, inExclusiveRange(tester.getTopLeft(heading).dy, tester.getTopLeft(find.text('Recent')).dy));

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

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    testWidgets('a post header and a notice keep their inset from the start edge, ${language.name} UI', (tester) async {
      final forums = DemoForumRepository()
        ..seed(
          threads: [
            ThreadSummary(
              id: '7000',
              forumId: 3,
              title: 'שאלה על התרגום',
              kind: ThreadKind.discussion,
              authorName: 'רבקה',
              postCount: 1,
              lastPostAt: DateTime(2026, 10, 1),
              createdAt: DateTime(2026, 10, 1),
              locked: true,
            ),
          ],
          posts: [
            Post(id: '1', threadId: '7000', authorName: 'רבקה', body: 'למה דווקא אונקלוס?', createdAt: DateTime(2026, 10, 1)),
          ],
        );
      final c = await _pump(tester, forums: forums, settings: AppSettings(onboardingComplete: true, language: language));
      c.read(routerProvider).go('/community/thread/7000');
      await tester.pumpAndSettle();

      // How far [inner] is in from the start edge of [outer]: its right edge
      // in Hebrew.
      final rtl = language == AppLanguage.hebrew;
      double inset(Finder outer, Finder inner) {
        final (o, i) = (tester.getRect(outer), tester.getRect(inner));
        return rtl ? o.right - i.right : i.left - o.left;
      }

      // A post is a letter on the page: the author's initial at its start
      // edge, the right one in Hebrew, and their name after it.
      final post = find.byType(PostCard);
      final disc = find.descendant(of: post, matching: find.byType(InitialDisc));
      final name = find.descendant(of: post, matching: find.text('רבקה'));
      expect(name, findsOneWidget);
      expect(inset(post, disc), lessThan(1));
      expect(inset(post, name), greaterThanOrEqualTo(tester.getSize(disc).width + 12));

      // The locked thread's notice, below the demo's, which is one too.
      final notice = find.widgetWithIcon(NoticeBanner, Icons.lock_outline);
      expect(notice, findsOneWidget, reason: 'the thread is locked');
      final icon = find.descendant(of: notice, matching: find.byIcon(Icons.lock_outline));
      expect(inset(find.descendant(of: notice, matching: find.byType(Card)), icon), greaterThanOrEqualTo(12));
    });
  }

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
    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.widgetWithText(FilledButton, 'Post')));
    await tester.pump();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    forums.gate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(prefs.getString('draft.newThread'), isNull);
  });

  testWidgets('the display name runs the way of the name, and empty, right to left in the Hebrew UI', (tester) async {
    final forums = await _Member().signIn();
    final c = await _pump(
      tester,
      forums: forums,
      settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew),
    );
    c.read(routerProvider).go('/community/account');
    await tester.pumpAndSettle();
    // The name is edited in a dialog, from the account's card.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byWidgetPredicate((w) => w is TextField && w.maxLength == 40),
      matching: find.byType(EditableText),
    );
    TextDirection direction() => tester.widget<EditableText>(field).textDirection!;
    expect(tester.widget<EditableText>(field).controller.text, 'Reader');
    expect(direction(), TextDirection.ltr, reason: 'the way of the name');
    await tester.enterText(field, '');
    await tester.pump();
    expect(direction(), TextDirection.rtl, reason: 'empty, the way of the UI');
    await tester.enterText(field, 'Rivka');
    await tester.pump();
    expect(direction(), TextDirection.ltr);
    await tester.enterText(field, '');
    await tester.pump();
    expect(direction(), TextDirection.rtl);
  });

  testWidgets('a post with no letters, such as "+1", runs the way of the Hebrew UI', (tester) async {
    final forums = await _Member().signIn();
    forums.seed(
      threads: [_thread(7200)],
      posts: [
        for (final (i, body) in ['שלום לכולם', '+1', 'Привет!'].indexed)
          Post(
            id: '${i + 1}',
            threadId: '7200',
            authorId: 'member$i',
            authorName: 'Member $i',
            body: body,
            createdAt: DateTime(2026, 10, i + 1),
          ),
      ],
    );
    final c = await _pump(
      tester,
      forums: forums,
      settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew),
    );
    c.read(routerProvider).go('/community/thread/7200');
    await tester.pumpAndSettle();
    TextDirection bodyDirection(String body) => tester
        .widget<SelectableText>(find.byWidgetPredicate((w) => w is SelectableText && w.data == body))
        .textDirection!;
    expect(bodyDirection('+1'), TextDirection.rtl, reason: 'no strong character: the UI direction');
    expect(bodyDirection('Привет!'), TextDirection.ltr, reason: 'Cyrillic runs left to right');
    expect(bodyDirection('שלום לכולם'), TextDirection.rtl);
  });

  group('a report', () {
    testWidgets('has details that run the way of their text', (tester) async {
      final forums = await _Member().signIn();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      await _openPostMenu(tester, 1);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      final field = find.descendant(of: find.byType(AlertDialog), matching: find.byType(EditableText));
      TextDirection direction() => tester.widget<EditableText>(field).textDirection!;
      expect(direction(), TextDirection.ltr, reason: "empty, the English UI's way");
      await tester.enterText(field, 'לשון הרע על אדם אחר');
      await tester.pump();
      expect(direction(), TextDirection.rtl);
      await tester.enterText(field, '');
      await tester.pump();
      expect(direction(), TextDirection.ltr);
    });

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

    testWidgets('asks for details in three lines, labelled at their top, counted only near the limit', (tester) async {
      final forums = await _Member().signIn();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();

      await _openPostMenu(tester, 1);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final details = find.descendant(of: dialog, matching: find.byType(TextField));
      final field = tester.widget<TextField>(details);
      expect(field.minLines, 3);
      expect(field.maxLength, 1000);
      // The label sits in the first line, where what is typed begins, rather
      // than in the middle of the box.
      final editable = tester.getRect(find.descendant(of: details, matching: find.byType(EditableText)));
      final label = tester.getRect(find.descendant(of: details, matching: find.text('Details (optional)')));
      expect(editable.height, greaterThan(label.height * 2.5));
      expect(label.center.dy, lessThan(editable.top + editable.height / 3));
      // No "0/1000" from the start: a counter only near the limit, in the
      // number format of the language.
      expect(find.descendant(of: dialog, matching: find.textContaining('/1')), findsNothing);
      await tester.enterText(details, 'x' * 799);
      await tester.pump();
      expect(find.descendant(of: dialog, matching: find.textContaining('/1')), findsNothing);
      await tester.enterText(details, 'x' * 800);
      await tester.pump();
      expect(find.descendant(of: dialog, matching: find.text('800/1,000')), findsOneWidget);
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
      expect(find.text('You’ve already reported this post.'), findsOneWidget);

      await _openPostMenu(tester, 1);
      expect(find.text('Report'), findsNothing);
    });
  });

  group('the community page', () {
    const demoMode = 'Demo mode: posts stay on this device and reset when the app restarts.';

    testWidgets('says that it is the demo, until its notice is dismissed for the session', (tester) async {
      final c = await _pump(tester);
      c.read(routerProvider).go('/community');
      await tester.pumpAndSettle();
      final notice = find.widgetWithText(NoticeBanner, demoMode);
      expect(notice, findsOneWidget);
      expect(find.byType(DemoTag), findsNothing, reason: 'the notice says it here');

      await tester.tap(find.byTooltip('Dismiss notice'));
      await tester.pumpAndSettle();
      expect(notice, findsNothing);
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      c.read(routerProvider).go('/community');
      await tester.pumpAndSettle();
      expect(notice, findsNothing, reason: 'for the rest of the session');
    });

    testWidgets("dismissed from the keyboard, gives the focus to this week's discussion", (tester) async {
      final c = await _pump(tester);
      c.read(routerProvider).go('/community');
      await tester.pumpAndSettle();
      Focus.of(tester.element(find.descendant(of: find.byTooltip('Dismiss notice'), matching: find.byIcon(Icons.close))))
          .requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(NoticeBanner), findsNothing);
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(focused, isNotNull);
      expect(
        find.descendant(of: find.byType(ThisWeekCard), matching: find.byElementPredicate((e) => e == focused)),
        findsOneWidget,
      );
    });

    testWidgets("opens this week's discussion, which the demo has begun", (tester) async {
      final c = await _pump(tester);
      c.read(routerProvider).go('/community');
      await tester.pumpAndSettle();
      final card = find.byType(ThisWeekCard);
      // The parsha's name in Hebrew, tagged as Hebrew, over its English title.
      final hebrew = find.descendant(of: card, matching: find.text('בְּרֵאשִׁית'));
      expect(hebrew, findsOneWidget);
      expect(tester.widget<Lang>(find.ancestor(of: hebrew, matching: find.byType(Lang))).locale, const Locale('he'));
      expect(find.descendant(of: card, matching: find.text('This week: Parshat Bereshit')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Open the discussion')), findsOneWidget);

      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(ThreadScreen), findsOneWidget);
      expect(find.text('Parshat Bereshit 5787'), findsOneWidget);
      expect(find.byType(PostCard), findsNWidgets(3));
    });

    testWidgets("has an account button: a person signed out, and the member's initial signed in", (tester) async {
      final forums = DemoForumRepository();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community');
      await tester.pumpAndSettle();
      final appBar = find.byType(AppBar);
      expect(find.descendant(of: appBar, matching: find.byIcon(Icons.person_outline)), findsOneWidget);
      expect(find.byTooltip('Sign in'), findsNWidgets(1));

      await forums.verifyCode('reader@example.org', '123456');
      c.invalidate(myProfileProvider);
      await tester.pumpAndSettle();
      // Until a name is chosen, the machine's ("user_1a2b3c4d") gives no
      // initial: a person on the disc, not a "U".
      final disc = find.descendant(of: appBar, matching: find.byType(InitialDisc));
      expect(disc, findsOneWidget);
      expect(find.descendant(of: disc, matching: find.byIcon(Icons.person_outline)), findsOneWidget);
      expect(find.descendant(of: disc, matching: find.byType(Text)), findsNothing);

      await forums.updateDisplayName('rivka');
      c.invalidate(myProfileProvider);
      await tester.pumpAndSettle();
      expect(disc, findsOneWidget);
      expect(find.descendant(of: disc, matching: find.text('R')), findsOneWidget);
      expect(tester.getSize(disc), const Size(32, 32));
      expect(find.byTooltip('Account & community'), findsOneWidget);
      // The sign-in row goes, and a moderator's reports come.
      expect(find.text('Sign in to post, say todah or report.'), findsNothing);
      expect(find.text('Reports to review'), findsOneWidget);
    });

    testWidgets('on a community server says nothing of a demo', (tester) async {
      final c = await _pump(tester, forums: _Server());
      for (final page in ['/community', '/community/forum/questions', '/community/thread/1', '/community/account']) {
        c.read(routerProvider).go(page);
        await tester.pumpAndSettle();
        expect(find.text(demoMode), findsNothing, reason: page);
        expect(find.text('Demo'), findsNothing, reason: page);
      }
    });
  });

  group('the Demo tag', () {
    for (final page in ['/community/forum/questions', '/community/thread/1', '/community/new?forum=questions', '/community/account']) {
      testWidgets('on $page is a button that explains the demo', (tester) async {
        final semantics = tester.ensureSemantics();
        final c = await _pump(tester);
        c.read(routerProvider).go(page);
        await tester.pumpAndSettle();
        expect(find.textContaining('Demo mode'), findsNothing, reason: "the notice is the Community page's alone");
        final tag = find.descendant(of: find.byType(AppBar), matching: find.widgetWithText(TextButton, 'Demo'));
        expect(tag, findsOneWidget);
        // A small tag, but a whole 48 to tap.
        expect(tester.getSize(tag).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(tag).width, greaterThanOrEqualTo(48));
        // Named by what it does too: "Demo" alone could be taken for a
        // switch to a demo.
        expect(
          tester.getSemantics(tag),
          isSemantics(label: 'Demo', tooltip: 'About the demo', isButton: true, hasTapAction: true),
        );

        await tester.tap(tag);
        await tester.pumpAndSettle();
        expect(find.text('About the demo'), findsOneWidget);
        expect(find.textContaining('Anything you post stays on this device'), findsOneWidget);
        expect(find.textContaining('sign in with any email address'), findsOneWidget, reason: 'signed out');
        semantics.dispose();
      });
    }

    testWidgets('tells a member signed in nothing of how to sign in', (tester) async {
      final forums = await _Member().signIn();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/new?forum=questions');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DemoTag));
      await tester.pumpAndSettle();
      expect(find.textContaining('Anything you post stays on this device'), findsOneWidget);
      expect(find.textContaining('sign in'), findsNothing);
    });

    testWidgets('is in Hebrew in the Hebrew UI', (tester) async {
      final c = await _pump(tester, settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew));
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(AppBar), matching: find.widgetWithText(TextButton, 'הדגמה')), findsOneWidget);
      await tester.tap(find.byType(DemoTag));
      await tester.pumpAndSettle();
      expect(find.text('על ההדגמה'), findsWidgets);
    });
  });

  group('a forum page', () {
    testWidgets('lists a thread as one button for screen readers, its tags, title and activity read together',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final c = await _pump(tester);
      c.read(routerProvider).go('/community/forum/feedback');
      await tester.pumpAndSettle();
      const title = 'A warmer theme for reading at night?';
      final tile = find.widgetWithText(ThreadTile, title);
      final node = tester.getSemantics(tile);
      expect(node, isSemantics(isButton: true, hasTapAction: true));
      expect(node.label, startsWith('Locked\n\u2068Avraham\u2069\u00a0· '));
      expect(node.label, endsWith('\u00a0· 1\u00a0reply\u00a0· thanked 13\u00a0times'));
      expect(tester.getSemantics(find.descendant(of: tile, matching: find.text('Locked'))).id, node.id);
      // The title, tagged with its own language, is read within the row, and
      // is no item to stop on of its own.
      final heading = tester.getSemantics(find.text(title));
      expect(heading.label, title);
      expect(heading.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      expect(heading.getSemanticsData().flagsCollection.isButton, isFalse);
      SemanticsNode? up = heading;
      while (up != null && up.id != node.id) {
        up = up.parent;
      }
      expect(up, isNotNull, reason: 'within the row');
      semantics.dispose();
    });

    testWidgets('in Hebrew, sets an English title from the left, and keeps an English name in its place', (tester) async {
      final c = await _pump(tester, settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew));
      c.read(routerProvider).go('/community/forum/feedback');
      await tester.pumpAndSettle();
      const title = 'A warmer theme for reading at night?';
      final english = tester.widget<Text>(find.text(title));
      expect(english.textDirection, TextDirection.ltr, reason: 'so its question mark ends it');
      expect(english.textAlign, TextAlign.start, reason: 'from its own start edge');
      expect(_setFrom(tester, find.text(title)), TextAlign.left);
      // Its last line ends well short of the row's right edge, as it would
      // not set from the page's edge.
      final lines = tester.renderObject<RenderParagraph>(find.text(title));
      final last = lines.getBoxesForSelection(const TextSelection(baseOffset: title.length - 1, extentOffset: title.length)).last;
      expect(last.right, lessThan(lines.size.width - 40));
      // The meta line runs right to left: the name, isolated, first, at the
      // right, then the time and the replies.
      final meta = find.descendant(of: find.widgetWithText(ThreadTile, title), matching: find.textContaining('\u2068Avraham\u2069\u00a0· '));
      expect(meta, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(meta);
      final text = paragraph.text.toPlainText();
      Rect boxOf(String part) {
        final start = text.indexOf(part);
        return paragraph.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: start + part.length)).first.toRect();
      }
      expect(boxOf('Avraham').left, greaterThan(boxOf('יום').right));
      // Its lock tag in Hebrew too.
      expect(find.descendant(of: find.widgetWithText(ThreadTile, title), matching: find.text('נעול')), findsOneWidget);
    });

    testWidgets('locked and empty, invites no one who may not begin a discussion', (tester) async {
      final c = await _pump(tester, forums: _LockedFeedback());
      c.read(routerProvider).go('/community/forum/feedback');
      await tester.pumpAndSettle();
      final empty = find.byType(EmptyState);
      expect(find.descendant(of: empty, matching: find.text('No discussions here yet.')), findsOneWidget);
      expect(find.text('No discussions yet — begin the first.'), findsNothing);
      expect(find.descendant(of: empty, matching: find.byType(ButtonStyleButton)), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets("of the week's parsha opens on this week's discussion, and is never empty", (tester) async {
      final c = await _pump(tester, forums: DemoForumRepository(samples: false));
      c.read(routerProvider).go('/community/forum/parsha');
      await tester.pumpAndSettle();
      expect(find.byType(ThisWeekCard), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
      await tester.tap(find.byType(ThisWeekCard));
      await tester.pumpAndSettle();
      expect(find.text('Parshat Bereshit 5787'), findsOneWidget);
    });

    testWidgets('with no discussions says so, and offers to begin the first', (tester) async {
      final c = await _pump(tester, forums: DemoForumRepository(samples: false));
      c.read(routerProvider).go('/community/forum/divrei-torah');
      await tester.pumpAndSettle();
      final empty = find.byType(EmptyState);
      expect(find.descendant(of: empty, matching: find.text('No discussions yet — begin the first.')), findsOneWidget);
      await tester.tap(find.descendant(of: empty, matching: find.text('New discussion')));
      await tester.pumpAndSettle();
      expect(find.byType(ComposeScreen), findsOneWidget);
      expect(_chosenForum(tester), 'Divrei Torah');
    });

    testWidgets('lists its pinned discussions apart, and tags a locked one above its title', (tester) async {
      final c = await _pump(tester);
      c.read(routerProvider).go('/community/forum/parsha');
      await tester.pumpAndSettle();
      const welcomeTitle = 'Welcome: how the weekly discussions work';
      final welcome = tester.getTopLeft(find.text(welcomeTitle)).dy;
      final heading = find.descendant(of: find.byType(GroupHeader), matching: find.text('Pinned'));
      expect(welcome, inExclusiveRange(tester.getTopLeft(heading).dy, tester.getTopLeft(find.text('Recent')).dy));
      // Tagged pinned above its title too, so that the row says so wherever
      // it is met, as a locked one says it is locked.
      final pinned = find.widgetWithText(ThreadTile, welcomeTitle);
      final pinTag = find.descendant(of: pinned, matching: find.text('Pinned'));
      expect(pinTag, findsOneWidget);
      expect(find.descendant(of: pinned, matching: find.byIcon(Icons.push_pin_outlined)), findsOneWidget);
      expect(tester.getTopLeft(pinTag).dy, lessThan(welcome));

      c.read(routerProvider).go('/community/forum/feedback');
      await tester.pumpAndSettle();
      const title = 'A warmer theme for reading at night?';
      final locked = find.widgetWithText(ThreadTile, title);
      final tag = find.descendant(of: locked, matching: find.text('Locked'));
      expect(tag, findsOneWidget);
      expect(find.descendant(of: locked, matching: find.byIcon(Icons.lock_outline)), findsOneWidget);
      expect(tester.getTopLeft(tag).dy, lessThan(tester.getTopLeft(find.text(title)).dy));
      // Who started it, when it was last active, its replies and the thanks
      // its posts were given.
      expect(
        find.descendant(of: locked, matching: find.textContaining(RegExp('^\u2068Avraham\u2069\u00a0· .+\u00a0· 1\u00a0reply\u00a0· thanked 13\u00a0times\$'))),
        findsOneWidget,
      );
    });

    testWidgets("lists a weekly thread as the community's, started by no one", (tester) async {
      final now = DateTime.now();
      final forums = DemoForumRepository()
        ..seed(threads: [
          ThreadSummary(
            id: '6100',
            forumId: 1,
            title: 'Noach · נח · 5787',
            kind: ThreadKind.weekly,
            authorName: '',
            postCount: 0,
            // Ahead of the clock, so that it is "just now" however long the
            // test takes.
            lastPostAt: now.add(const Duration(days: 1)),
            createdAt: now,
            parshaNumber: 2,
            hebrewYear: 5787,
          ),
        ]);
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/forum/parsha');
      await tester.pumpAndSettle();
      final weekly = find.widgetWithText(ThreadTile, 'Parshat Noach 5787');
      expect(find.descendant(of: weekly, matching: find.text('Just now\u00a0· No replies yet')), findsOneWidget);
    });

    testWidgets('runs each title its own way from its own start edge, and keeps a Hebrew name in its place', (tester) async {
      final c = await _pump(tester);
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      const question = 'עד מתי אפשר להשלים את הקריאה?';
      final hebrew = tester.widget<Text>(find.text(question));
      expect(hebrew.textDirection, TextDirection.rtl, reason: 'so its question mark ends it');
      expect(hebrew.textAlign, TextAlign.start, reason: 'from its own start edge, so that its lines all start there');
      expect(_setFrom(tester, find.text(question)), TextAlign.right);
      expect(tester.widget<Lang>(find.ancestor(of: find.text(question), matching: find.byType(Lang))).locale, const Locale('he'));
      expect(tester.widget<Text>(find.text('Why read Numbers 32:3 a third time?')).textDirection, TextDirection.ltr);
      // Isolated, so that the rest of the line stays after the name.
      expect(find.textContaining('\u2068שירה\u2069\u00a0· '), findsOneWidget);
    });
  });

  group('what cannot load', () {
    const offline = 'Couldn’t reach the server. Check your connection and try again.';
    final retry = find.widgetWithText(FilledButton, 'Try again');

    testWidgets("a forum's discussions say why, under no floating button, and come when tried again", (tester) async {
      final forums = _FlakyForum()..offline = true;
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ErrorState, offline), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing, reason: 'nothing to begin a discussion over');
      // It can be pulled to try again too.
      final scrollable = tester.widget<Scrollable>(find.descendant(of: find.byType(ErrorState), matching: find.byType(Scrollable)));
      expect(scrollable.physics, isA<AlwaysScrollableScrollPhysics>());

      forums.offline = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Why read the Targum rather than a translation?'), findsOneWidget);
      expect(find.byType(ErrorState), findsNothing);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('tried again, say so on the button, which keeps the focus, until the outcome', (tester) async {
      final forums = _HeldThreads()..offline = true;
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      // Never tried again behind the reader's back.
      await tester.pump(const Duration(minutes: 1));
      expect(forums.asked, 1);
      Focus.of(tester.element(find.text('Try again'))).requestFocus();
      await tester.pump();
      forums.gate = Completer<void>();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      // While it is tried again the message stays, and the button, still
      // enabled and with the focus, spins.
      expect(find.widgetWithText(ErrorState, offline), findsOneWidget);
      expect(find.descendant(of: retry, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(tester.widget<FilledButton>(retry).onPressed, isNotNull);
      expect(Focus.of(tester.element(find.text('Try again'))).hasPrimaryFocus, isTrue);

      forums.gate!.complete();
      await tester.pumpAndSettle();
      expect(forums.asked, 2);
      expect(find.widgetWithText(ErrorState, offline), findsOneWidget, reason: 'failed again');
      expect(find.descendant(of: retry, matching: find.byType(CircularProgressIndicator)), findsNothing);
      expect(Focus.of(tester.element(find.text('Try again'))).hasPrimaryFocus, isTrue);
    });

    testWidgets('a thread keeps its title, says why, and docks no reply box until its posts come', (tester) async {
      final forums = _Flaky()..offline = true;
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      final heading = find.bySemanticsLabel('Why read the Targum rather than a translation?');
      expect(find.text('Why read the Targum rather than a translation?'), findsOneWidget);
      expect(heading, findsWidgets);
      expect(find.widgetWithText(ErrorMessage, offline), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Write a reply'), findsNothing);

      forums.offline = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.byType(PostCard), findsNWidgets(2));
      expect(find.byType(ErrorMessage), findsNothing);
      expect(find.widgetWithText(TextField, 'Write a reply'), findsOneWidget);
    });

    testWidgets('the forums on the Community page say why, and come when tried again', (tester) async {
      final forums = _OfflineCommunity();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ErrorMessage, offline), findsOneWidget);
      expect(find.byType(ThisWeekCard), findsOneWidget, reason: 'the rest of the page stays');

      forums.offline = false;
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Questions & answers'), findsOneWidget);
      expect(find.byType(ErrorMessage), findsNothing);
    });

    testWidgets('a question on a verse says why its forums can\'t be had, and fetches them again as it opens again',
        (tester) async {
      final forums = _OfflineCommunity();
      final c = await _pump(tester, forums: forums);
      // Asked from the reader, before Community was ever opened.
      final ask = Uri(path: '/ask', queryParameters: {'verse': 'Genesis 3:22'}).toString();
      c.read(routerProvider).push(ask);
      await tester.pumpAndSettle();
      final post = find.descendant(of: find.byType(AppBar), matching: find.widgetWithText(FilledButton, 'Post'));
      expect(find.widgetWithText(ErrorMessage, offline), findsOneWidget, reason: 'in place of the forums');
      expect(find.byType(ChoiceChip), findsNothing);
      expect(tester.widget<FilledButton>(post).onPressed, isNull);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      forums.offline = false;
      c.read(routerProvider).push(ask);
      await tester.pump();
      expect(find.byType(ErrorMessage), findsNothing, reason: 'fetched afresh, not the failure from before');
      await tester.pumpAndSettle();
      expect(_chosenForum(tester), 'Questions & answers');
      expect(tester.widget<FilledButton>(post).onPressed, isNotNull);
    });

    testWidgets("a new discussion lists its forums when they're tried again", (tester) async {
      final forums = _OfflineCommunity();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).push('/community/new?forum=questions');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ErrorMessage, offline), findsOneWidget);
      forums.offline = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.byType(ErrorMessage), findsNothing);
      expect(_chosenForum(tester), 'Questions & answers');
    });

    testWidgets("a forum whose discussions couldn't load fetches them again as it opens again", (tester) async {
      final forums = _FlakyForum()..offline = true;
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ErrorState, offline), findsOneWidget);
      c.read(routerProvider).go('/community');
      await tester.pumpAndSettle();

      forums.offline = false;
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pump();
      expect(find.byType(ErrorState), findsNothing, reason: 'loading afresh, not the failure from before');
      await tester.pumpAndSettle();
      expect(find.text('Why read the Targum rather than a translation?'), findsOneWidget);
    });

    testWidgets("a forum whose forums can't be had can be pulled to try again", (tester) async {
      final forums = _OfflineCommunity();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ErrorState, offline), findsOneWidget);
      expect(find.ancestor(of: find.byType(ErrorState), matching: find.byType(RefreshIndicator)), findsOneWidget);

      forums.offline = false;
      await tester.fling(find.byType(ErrorState), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Why read the Targum rather than a translation?'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets("a thread names its forum, though the forums had failed before it opened", (tester) async {
      final forums = _OfflineCommunity();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ErrorMessage, offline), findsOneWidget);

      forums.offline = false;
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Questions & answers')), findsOneWidget);
    });

    testWidgets('a thread refreshed names its forum, should the forums have failed as it opened', (tester) async {
      final forums = _OfflineCommunity();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      final appBar = find.byType(AppBar);
      expect(find.descendant(of: appBar, matching: find.text('Community')), findsOneWidget);

      forums.offline = false;
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: appBar, matching: find.text('Questions & answers')), findsOneWidget);
    });

    testWidgets('a thread that can\'t be had is never tried again behind the reader\'s back, its posts nor itself',
        (tester) async {
      final forums = _FlakyThread()..offline = true;
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ErrorMessage, offline), findsOneWidget);
      final title = find.text('Why read the Targum rather than a translation?');
      expect(title, findsNothing);
      final at = tester.getTopLeft(retry);

      // Back online, nothing moves until the reader asks: no title comes
      // over Try again.
      forums.offline = false;
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(forums.threadsAsked, 1);
      expect(title, findsNothing);
      expect(tester.getTopLeft(retry), at);

      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(title, findsOneWidget);
      expect(find.byType(PostCard), findsNWidgets(2));
    });

    testWidgets('a reply restored says so once its reply box is there, never while the posts can\'t load',
        (tester) async {
      final forums = _Flaky()..offline = true;
      final c = await _pump(tester, forums: forums);
      // Wide, where the page's own Scaffold shows the message, above the box.
      tester.view.physicalSize = const Size(1366, 860);
      await c.read(sharedPreferencesProvider).setString('draft.thread.1', 'Kept for later');
      c.read(routerProvider).go('/community/thread/1');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ErrorMessage, offline), findsOneWidget);
      expect(find.text('Your draft was restored.'), findsNothing, reason: 'no reply box for it to be in');

      forums.offline = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Kept for later'), findsOneWidget);
      expect(find.text('Your draft was restored.'), findsOneWidget);
      // Above the box it is in, which was docked before it came.
      final box = tester.getRect(find.ancestor(of: find.byType(TextField), matching: find.byType(Material)).first);
      final shown = tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first);
      expect(shown.bottom, box.top - 16);
    });

    testWidgets("the forums on the Community page, tried again, come with their activity, which had failed too",
        (tester) async {
      final forums = _OfflineForumsAndStats();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ErrorMessage, offline), findsOneWidget);
      // The activity, tried again by itself, gives up.
      for (var i = 0; i < 40 && c.read(forumStatsProvider).isLoading; i++) {
        await tester.pump(const Duration(seconds: 7));
      }
      expect(c.read(forumStatsProvider), isA<AsyncError<Object?>>());

      forums.offline = false;
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.widgetWithText(PaperRow, 'Questions & answers'),
          matching: find.textContaining(RegExp('^\\d+\u00a0discussions?')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the reports to review say why, and come when tried again', (tester) async {
      final forums = _OfflineCommunity();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/moderation');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ErrorState, offline), findsOneWidget);

      forums.offline = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.byType(ErrorState), findsNothing);
    });
  });

  group("a forum's floating button", () {
    testWidgets('is not offered over an empty forum, whose own button is the one invitation', (tester) async {
      final c = await _pump(tester, forums: DemoForumRepository(samples: false));
      c.read(routerProvider).go('/community/forum/divrei-torah');
      await tester.pumpAndSettle();
      expect(find.text('New discussion'), findsOneWidget);
      expect(find.descendant(of: find.byType(EmptyState), matching: find.text('New discussion')), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('floats over no spinner while the discussions load again for another account', (tester) async {
      final forums = _HeldThreads();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);

      forums.gate = Completer<void>();
      await forums.verifyCode('reader@example.org', '123456');
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'loading again, for the account');
      expect(find.byType(FloatingActionButton), findsNothing);

      forums.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets("is offered over the week's forum, never empty", (tester) async {
      final c = await _pump(tester, forums: DemoForumRepository(samples: false));
      c.read(routerProvider).go('/community/forum/parsha');
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    for (final reduced in [false, true]) {
      testWidgets(reduced ? 'appears at once under Reduce Motion' : 'fades in as the discussions come, without turning',
          (tester) async {
        final forums = _HeldThreads()..gate = Completer<void>();
        final c = await _pump(tester, forums: forums, settings: AppSettings(onboardingComplete: true, reduceMotion: reduced));
        c.read(routerProvider).go('/community/forum/questions');
        // The page arrives, and spins while the discussions load.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.byType(FloatingActionButton), findsNothing, reason: 'none while they load');

        forums.gate!.complete();
        await tester.pump();
        await tester.pump();
        final fab = find.byType(FloatingActionButton);
        expect(fab, findsOneWidget);
        double opacity() =>
            tester.widget<FadeTransition>(find.ancestor(of: fab, matching: find.byType(FadeTransition)).first).opacity.value;
        if (reduced) {
          expect(opacity(), 1);
        } else {
          await tester.pump(const Duration(milliseconds: 100));
          expect(opacity(), inExclusiveRange(0, 1), reason: 'fading in');
          await tester.pumpAndSettle();
          expect(opacity(), 1);
        }
        // An extended button, which the Scaffold never turns as it comes.
        expect(tester.widget<FloatingActionButton>(fab).isExtended, isTrue);
      });
    }

    testWidgets('shows its label, and at large text its icon alone, named by its tooltip', (tester) async {
      final semantics = tester.ensureSemantics();
      final c = await _pump(tester);
      // A tablet, where the label fits; the test's font sets every letter a
      // square, wider than the app's.
      tester.view.physicalSize = const Size(800, 1180);
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      final fab = find.byType(FloatingActionButton);
      expect(find.descendant(of: fab, matching: find.text('New discussion')), findsOneWidget);
      expect(find.byTooltip('New discussion'), findsNothing);
      expect(tester.getSize(fab).width, greaterThan(56));

      void iconAlone() {
        expect(find.descendant(of: fab, matching: find.text('New discussion')), findsNothing);
        expect(tester.getSize(fab), const Size(56, 56));
        expect(find.byTooltip('New discussion'), findsOneWidget);
        expect(
          tester.getSemantics(find.byTooltip('New discussion')),
          isSemantics(tooltip: 'New discussion', isButton: true, hasTapAction: true),
        );
      }

      // At 300%, the label would be taller than the button.
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      iconAlone();
      // On a phone at 200%, wider than two thirds of the screen.
      tester.view.physicalSize = const Size(412, 915);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      iconAlone();
      await tester.tap(fab);
      await tester.pumpAndSettle();
      expect(find.byType(ComposeScreen), findsOneWidget);
      semantics.dispose();
    });
  });

  group("a forum's activity", () {
    const question = 'Why read the Targum rather than a translation?';
    const opening = 'I read English more easily than Aramaic. Why does the Shulchan Aruch insist on Targum Onkelos?';
    const hebrewTitle = 'עד מתי אפשר להשלים את הקריאה?';
    const hebrewOpening = 'קרה לי שלא הספקתי לסיים שניים מקרא לפני שבת. עד מתי אפשר עוד להשלים?';
    Finder tileOf(String title) => find.widgetWithText(ThreadTile, title);

    testWidgets('lists a discussion with its opening, in its own direction, read within its row', (tester) async {
      final semantics = tester.ensureSemantics();
      final c = await _pump(tester);
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      final excerpt = find.text(hebrewOpening);
      final text = tester.widget<Text>(excerpt);
      expect(text.textDirection, TextDirection.rtl, reason: 'so its question mark ends it');
      expect(text.textAlign, TextAlign.start, reason: 'from its own start edge, so that its lines all start there');
      expect(_setFrom(tester, excerpt), TextAlign.right);
      expect(text.maxLines, 2);
      expect(text.style?.fontSize, Theme.of(tester.element(excerpt)).textTheme.bodySmall?.fontSize);
      expect(tester.widget<Lang>(find.ancestor(of: excerpt, matching: find.byType(Lang))).locale, const Locale('he'));
      // Under its title, over who began it, its replies and its thanks.
      final tile = tileOf(hebrewTitle);
      final meta = find.descendant(of: tile, matching: find.textContaining('\u2068שירה\u2069'));
      expect(tester.getTopLeft(excerpt).dy, greaterThanOrEqualTo(tester.getBottomLeft(find.text(hebrewTitle)).dy));
      expect(tester.getBottomLeft(excerpt).dy, lessThanOrEqualTo(tester.getTopLeft(meta).dy));
      expect(tester.widget<Text>(meta).data, endsWith('\u00a0· 2\u00a0replies\u00a0· thanked 13\u00a0times'));
      // Tagged with its language, it is read within the row, as the title is.
      final row = tester.getSemantics(tile);
      SemanticsNode? up = tester.getSemantics(excerpt);
      while (up != null && up.id != row.id) {
        up = up.parent;
      }
      expect(up, isNotNull, reason: 'within the row');
      expect(find.text(opening), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('at 200% text, shows the whole opening', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final c = await _pump(tester);
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(hebrewOpening), 200);
      expect(tester.widget<Text>(find.text(hebrewOpening)).maxLines, isNull, reason: 'never cut short once enlarged');
    });

    testWidgets("leaves out a blocked member's opening and the thanks on their posts, until they are unblocked", (tester) async {
      final forums = await _Member().signIn();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      expect(find.text(opening), findsOneWidget);
      await forums.setTodah('1', true);
      await tester.tap(find.text(question));
      await tester.pumpAndSettle();
      await _openPostMenu(tester, 0);
      await tester.tap(find.text('Block Avraham'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Block Avraham'));
      await tester.pumpAndSettle();
      await _goBack(tester);
      expect(find.text(opening), findsNothing, reason: 'rather than the answer in its place');
      // Only the thanks on Rivka's answer: none on Avraham's question.
      expect(tester.widget<Text>(find.descendant(of: tileOf(question), matching: find.textContaining('reply'))).data,
          endsWith('1\u00a0reply\u00a0· thanked 4\u00a0times'));

      // Once the status message that says so has gone.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      c.read(routerProvider).go('/community/account');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blocked members (1)'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      await tester.tap(find.descendant(of: sheet, matching: find.widgetWithText(TextButton, 'Unblock')));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(sheet)).pop();
      await tester.pumpAndSettle();
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      expect(find.text(opening), findsOneWidget);
      expect(find.descendant(of: tileOf(question), matching: find.textContaining('thanked 5\u00a0times')), findsOneWidget);
    });

    testWidgets("shows its opening post's edit", (tester) async {
      final forums = await _Member().signIn();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/forum/divrei-torah');
      await tester.pumpAndSettle();
      c.read(routerProvider).push('/community/new?forum=divrei-torah');
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Light on the first verse');
      await tester.enterText(find.widgetWithText(TextField, 'Your message'), 'Onkelos and Rashi read it differently.');
      await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.widgetWithText(FilledButton, 'Post')));
      await tester.pumpAndSettle();
      await _openPostMenu(tester, 0);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      await tester.enterText(find.descendant(of: dialog, matching: find.byType(TextField)), 'A clearer opening, on the first verse.');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await _goBack(tester);
      final tile = tileOf('Light on the first verse');
      expect(find.descendant(of: tile, matching: find.text('A clearer opening, on the first verse.')), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text('Onkelos and Rashi read it differently.')), findsNothing);
    });

    testWidgets('is fetched again when the member signs out, whose blocks went with them', (tester) async {
      final forums = _CountingThreads();
      await forums.signIn();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      final questions = c.read(forumsProvider).value!.firstWhere((f) => f.slug == 'questions').id;
      final before = forums.fetched[questions]!;
      await forums.signOut();
      await tester.pumpAndSettle();
      expect(forums.fetched[questions], before + 1);
    });

    testWidgets("a todah fetches again only its own forum's list", (tester) async {
      final forums = _CountingThreads();
      await forums.signIn();
      final c = await _pump(tester, forums: forums);
      final ids = {for (final f in await forums.forums()) f.slug: f.id};
      // Two forums' pages open, one under the other, and the thread over them.
      c.read(routerProvider).go('/community/forum/divrei-torah');
      await tester.pumpAndSettle();
      c.read(routerProvider).push('/community/forum/questions');
      await tester.pumpAndSettle();
      await tester.tap(find.text(question));
      await tester.pumpAndSettle();
      final (divrei, questions) = (forums.fetched[ids['divrei-torah']]!, forums.fetched[ids['questions']]!);
      await _tapTodah(tester, 4);
      await tester.pumpAndSettle();
      // Each list is fetched as its page shows again.
      await _goBack(tester);
      expect(forums.fetched[ids['questions']], questions + 1);
      await _goBack(tester);
      expect(forums.fetched[ids['divrei-torah']], divrei, reason: 'a forum the thread is not in');
    });

    testWidgets('counts a todah given in its thread', (tester) async {
      final forums = await _Member().signIn();
      final c = await _pump(tester, forums: forums);
      c.read(routerProvider).go('/community/forum/questions');
      await tester.pumpAndSettle();
      Finder thanks(int n) => find.descendant(of: tileOf(question), matching: find.textContaining('thanked $n\u00a0times'));
      expect(thanks(4), findsOneWidget);
      await tester.tap(find.text(question));
      await tester.pumpAndSettle();
      await _tapTodah(tester, 4);
      await tester.pumpAndSettle();
      await _goBack(tester);
      expect(thanks(5), findsOneWidget);
    });

    group('on the community page', () {
      Finder detailOf(String forum) => find.descendant(
            of: find.widgetWithText(PaperRow, forum),
            matching: find.textContaining(RegExp('^(No discussions yet|\\d+\u00a0discussions?)')),
          );

      testWidgets('says how many discussions each forum has, and when one was last posted in, as one item with the forum',
          (tester) async {
        final semantics = tester.ensureSemantics();
        final forums = await _Member().signIn();
        final c = await _pump(tester, forums: forums, now: DateTime(2026, 10, 12, 10));
        c.read(routerProvider).go('/community');
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(detailOf('Divrei Torah')).data, matches(RegExp('^2\u00a0discussions\u00a0· active .+\$')));
        final row = tester.getSemantics(find.widgetWithText(PaperRow, 'Divrei Torah'));
        expect(row.label, contains('Divrei Torah'));
        expect(row.label, contains('2\u00a0discussions'));
        expect(tester.getSemantics(detailOf('Divrei Torah')).id, row.id);

        // A discussion begun counts, and is its forum's latest.
        c.read(routerProvider).push('/community/new?forum=divrei-torah');
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Light on the first verse');
        await tester.enterText(find.widgetWithText(TextField, 'Your message'), 'Onkelos and Rashi read it differently.');
        await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.widgetWithText(FilledButton, 'Post')));
        await tester.pumpAndSettle();
        expect(find.byType(ThreadScreen), findsOneWidget);
        await _goBack(tester);
        expect(tester.widget<Text>(detailOf('Divrei Torah')).data, '3\u00a0discussions\u00a0· active just now');
        semantics.dispose();
      });

      testWidgets('says of a forum with no discussions only that, and never that it is active', (tester) async {
        final c = await _pump(tester, forums: DemoForumRepository(samples: false));
        c.read(routerProvider).go('/community');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('App feedback'), 200);
        expect(tester.widget<Text>(detailOf('Divrei Torah')).data, 'No discussions yet');
        expect(tester.widget<Text>(detailOf('Questions & answers')).data, matches(RegExp('^1\u00a0discussion\u00a0· active .+\$')));
      });

      testWidgets("counts this week's discussion, once it has been begun from its card", (tester) async {
        final c = await _pump(tester, now: DateTime(2026, 10, 12, 10));
        c.read(routerProvider).go('/community');
        await tester.pumpAndSettle();
        int count() => int.parse(RegExp(r'^\d+').firstMatch(tester.widget<Text>(detailOf('Parshat HaShavua')).data!)![0]!);
        final before = count();
        await tester.tap(find.byType(ThisWeekCard));
        await tester.pumpAndSettle();
        expect(find.byType(ThreadScreen), findsOneWidget);
        await _goBack(tester);
        expect(count(), before + 1);
      });

      testWidgets('counts no more the discussions an account deleted took with it', (tester) async {
        final forums = await _Member().signIn();
        final c = await _pump(tester, forums: forums, now: DateTime(2026, 10, 12, 10));
        c.read(routerProvider).go('/community');
        await tester.pumpAndSettle();
        c.read(routerProvider).push('/community/new?forum=divrei-torah');
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Light on the first verse');
        await tester.enterText(find.widgetWithText(TextField, 'Your message'), 'Onkelos and Rashi read it differently.');
        await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.widgetWithText(FilledButton, 'Post')));
        await tester.pumpAndSettle();
        await _goBack(tester);
        expect(tester.widget<Text>(detailOf('Divrei Torah')).data, startsWith('3\u00a0discussions'));

        c.read(routerProvider).push('/community/account');
        await tester.pumpAndSettle();
        final delete = find.text('Delete my account');
        await tester.scrollUntilVisible(delete, 200, scrollable: find.byType(Scrollable).first);
        await Scrollable.ensureVisible(tester.element(delete), alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(delete);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
        await tester.pumpAndSettle();
        c.read(routerProvider).go('/community');
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(detailOf('Divrei Torah')).data, startsWith('2\u00a0discussions'));
      });

      testWidgets('waits a moment for it, rather than grow each row as it comes', (tester) async {
        final forums = _SlowStats();
        final c = await _pump(tester, forums: forums);
        c.read(routerProvider).go('/community');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Questions & answers'), findsNothing, reason: 'still loading');
        forums.gate.complete();
        await tester.pumpAndSettle();
        expect(find.text('Questions & answers'), findsOneWidget);
        expect(detailOf('Questions & answers'), findsOneWidget, reason: 'listed with it at once');
      });

      testWidgets('lists the forums without it once it has taken too long, and adds it when it comes', (tester) async {
        final forums = _SlowStats();
        final c = await _pump(tester, forums: forums);
        c.read(routerProvider).go('/community');
        // The forums come at once, and then a grace of 1.5 s.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(find.text('Questions & answers'), findsOneWidget);
        expect(detailOf('Questions & answers'), findsNothing);
        forums.gate.complete();
        await tester.pumpAndSettle();
        expect(detailOf('Questions & answers'), findsOneWidget);
      });

      testWidgets('in Hebrew, says when a forum was last active, a date or a time ago', (tester) async {
        final c = await _pump(
          tester,
          now: DateTime(2026, 10, 12, 10),
          settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew),
        );
        c.read(routerProvider).go('/community');
        await tester.pumpAndSettle();
        final details = tester.widgetList<Text>(find.textContaining('פעילות אחרונה')).map((t) => t.data!).toList();
        expect(details, isNotEmpty);
        expect(details, everyElement(contains('פעילות אחרונה: ')));
      });

      testWidgets("lists the forums without it where it can't be had", (tester) async {
        final c = await _pump(tester, forums: _NoStats());
        c.read(routerProvider).go('/community');
        await tester.pumpAndSettle();
        expect(find.text('Questions & answers'), findsOneWidget);
        expect(find.text('Ask about a verse, a Targum or a Rashi.'), findsOneWidget);
        expect(detailOf('Questions & answers'), findsNothing);
        expect(find.text('Couldn’t reach the server. Check your connection and try again.'), findsNothing);
        // Nor while it is tried again, and after.
        await tester.pump(const Duration(minutes: 1));
        expect(detailOf('Questions & answers'), findsNothing);
        expect(find.text('Couldn’t reach the server. Check your connection and try again.'), findsNothing);
      });
    });
  });

  group('the account page', () {
    Future<ProviderContainer> account(WidgetTester tester, {DemoForumRepository? forums, AppSettings? settings}) async {
      final c = await _pump(tester, forums: forums, settings: settings ?? const AppSettings(onboardingComplete: true));
      c.read(routerProvider).go('/community/account');
      await tester.pumpAndSettle();
      return c;
    }

    Future<void> sendCode(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField), 'reader@example.org');
      await tester.tap(find.text('Email me a code'));
      await tester.pumpAndSettle();
    }

    final codeField = find.byType(TextField);
    bool codeFocused(WidgetTester tester) => tester.widget<TextField>(codeField).focusNode!.hasFocus;

    testWidgets('signed out, names the app, the code it will send, and what the email is for', (tester) async {
      await account(tester);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Account & community')), findsOneWidget);
      expect(find.byType(AppMark), findsOneWidget);
      expect(tester.getSize(find.byType(AppMark)), const Size(56, 56));
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('We’ll email you a 6-digit code — no password needed.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Email me a code'), findsOneWidget);
      expect(find.textContaining('We use your email only to sign you in.'), findsOneWidget);
      // In a column of 440 at most.
      tester.view.physicalSize = const Size(1366, 860);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.widgetWithText(FilledButton, 'Email me a code')).width, 440 - 2 * 32);
    });

    testWidgets('says under the field when the email is no address, and gives it the focus', (tester) async {
      await account(tester);
      await tester.enterText(find.byType(TextField), 'reader');
      await tester.tap(find.text('Email me a code'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(_focusedField(tester), 'Email address');
      await tester.enterText(find.byType(TextField), 'reader@');
      await tester.pump();
      expect(find.text('Please enter a valid email address.'), findsNothing, reason: 'it goes as the email is edited');
    });

    testWidgets('takes the code in six boxes, a pasted code filling them all and signing in', (tester) async {
      final forums = DemoForumRepository();
      await account(tester, forums: forums);
      await sendCode(tester);
      final boxes = find.descendant(of: find.byType(AccountScreen), matching: find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 48));
      expect(boxes, findsNWidgets(6));
      expect(tester.getSize(boxes.first), const Size(48, 56));
      expect(codeFocused(tester), isTrue);
      await tester.enterText(codeField, '1 2');
      await tester.pump();
      expect(find.descendant(of: boxes.at(0), matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: boxes.at(1), matching: find.text('2')), findsOneWidget);
      expect(forums.currentUser, isNull);
      // Pasted as an email writes it, with its space: all six, and signed in.
      await tester.enterText(codeField, '123 456');
      await tester.pumpAndSettle();
      expect(forums.currentUser, isNotNull);
      expect(find.widgetWithText(FilledButton, 'Save name'), findsOneWidget);
    });

    testWidgets('is one field for screen readers, named for the code', (tester) async {
      final semantics = tester.ensureSemantics();
      await account(tester);
      await sendCode(tester);
      expect(tester.getSemantics(codeField), isSemantics(label: '6-digit code', isTextField: true, isFocused: true));
      semantics.dispose();
    });

    testWidgets('says under the boxes when the code is wrong, and keeps them in focus', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(supportsAnnounce: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final semantics = tester.ensureSemantics();
      final forums = _CheckedCodes(refuses: true);
      await account(tester, forums: forums);
      await sendCode(tester);
      tester.takeAnnouncements();
      // The sixth digit sends it.
      await tester.enterText(codeField, '123456');
      await tester.pumpAndSettle();
      expect(forums.checked, ['123456']);
      const wrong = 'That code didn’t work. Check it and try again.';
      expect(find.text(wrong), findsOneWidget);
      expect(find.descendant(of: find.byType(SnackBar), matching: find.text(wrong)), findsNothing);
      expect(codeFocused(tester), isTrue);
      expect([for (final a in tester.takeAnnouncements()) a.message], [wrong]);
      expect(tester.getSemantics(codeField), isSemantics(label: '6-digit code', hint: wrong, isTextField: true));
      // What is typed next replaces it.
      final code = tester.widget<TextField>(codeField).controller!;
      expect(code.selection, const TextSelection(baseOffset: 0, extentOffset: 6));
      await tester.enterText(codeField, '4');
      await tester.pump();
      expect(find.text(wrong), findsNothing);
      semantics.dispose();
    });

    testWidgets('says under the boxes when the code is cut short, sending none, and goes on from it', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(supportsAnnounce: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final semantics = tester.ensureSemantics();
      final forums = _CheckedCodes();
      await account(tester, forums: forums);
      await sendCode(tester);
      await tester.enterText(codeField, '123');
      await tester.pump();
      tester.takeAnnouncements();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      const short = 'Enter all 6 digits of the code.';
      expect(find.text(short), findsOneWidget);
      expect(forums.checked, isEmpty, reason: 'nothing is sent to be checked');
      expect(find.byType(SnackBar), findsNothing);
      expect(codeFocused(tester), isTrue);
      expect([for (final a in tester.takeAnnouncements()) a.message], [short]);
      expect(tester.getSemantics(codeField), isSemantics(label: '6-digit code', hint: short, isTextField: true));
      // The digits typed stay, and the next goes after them.
      final code = tester.widget<TextField>(codeField).controller!;
      expect(code.selection, const TextSelection.collapsed(offset: 3));
      // From the keyboard's Done too.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text(short), findsOneWidget);
      expect(forums.checked, isEmpty);
      await tester.enterText(codeField, '1234');
      await tester.pump();
      expect(find.text(short), findsNothing, reason: 'it goes as the code is typed');
      await tester.enterText(codeField, '123456');
      await tester.pumpAndSettle();
      expect(forums.checked, ['123456']);
      expect(forums.currentUser, isNotNull);
      semantics.dispose();
    });

    // On a desktop (and on the web), a click on Sign in takes the focus from
    // the field, which takes it back with the error: the digits typed stay
    // all the same, and a wrong code is still replaced by what is typed next.
    testWidgets('keeps the digits typed when a click on Sign in finds the code cut short', (tester) async {
      final forums = _CheckedCodes(refuses: true);
      await account(tester, forums: forums);
      await sendCode(tester);
      final code = tester.widget<TextField>(codeField).controller!;
      Future<void> type(String digit) async {
        tester.testTextInput.updateEditingValue(code.value.replaced(code.selection, digit));
        await tester.pumpAndSettle();
      }

      await tester.enterText(codeField, '123');
      await tester.pump();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.widgetWithText(FilledButton, 'Sign in')));
      addTearDown(mouse.removePointer);
      await mouse.down(tester.getCenter(find.widgetWithText(FilledButton, 'Sign in')));
      await tester.pump();
      expect(codeFocused(tester), isFalse, reason: 'a click elsewhere takes the focus');
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.text('Enter all 6 digits of the code.'), findsOneWidget);
      expect(codeFocused(tester), isTrue);
      expect(code.selection, const TextSelection.collapsed(offset: 3));
      await type('4');
      expect(code.text, '1234');

      // The sixth digit sends it, and the wrong code is selected, so what is
      // typed next replaces it.
      await type('5');
      await type('6');
      expect(forums.checked, ['123456']);
      expect(find.text('That code didn’t work. Check it and try again.'), findsOneWidget);
      expect(code.selection, const TextSelection(baseOffset: 0, extentOffset: 6));
      await type('7');
      expect(code.text, '7');
    }, variant: TargetPlatformVariant.desktop());

    for (final announces in [true, false]) {
      testWidgets(
          'says where the code went once, on the page, '
          '${announces ? 'and announces it' : 'a live region where nothing is announced'}', (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(supportsAnnounce: announces);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        final semantics = tester.ensureSemantics();
        await account(tester);
        tester.takeAnnouncements();
        await sendCode(tester);
        const sent = 'We sent a 6-digit code to reader@example.org.';
        expect(find.descendant(of: find.byType(PageBody), matching: find.text(sent)), findsOneWidget);
        // Not again in a status message: one comes only when it is sent
        // again (below).
        expect(find.byType(SnackBar), findsNothing);
        // Screen readers hear it all the same.
        expect([for (final a in tester.takeAnnouncements()) a.message], announces ? [sent] : isEmpty);
        expect(tester.getSemantics(find.text(sent)), isSemantics(label: sent, isLiveRegion: !announces));
        semantics.dispose();
      });
    }

    testWidgets('sends the code again after 30 seconds', (tester) async {
      await account(tester);
      await sendCode(tester);
      TextButton resend() => tester.widget<TextButton>(find.ancestor(of: find.textContaining('Resend'), matching: find.byType(TextButton)));
      expect(find.text('Resend in 30s'), findsOneWidget);
      expect(resend().onPressed, isNull);
      await tester.pump(const Duration(seconds: 29));
      expect(find.text('Resend in 1s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Resend code'), findsOneWidget);
      expect(resend().onPressed, isNotNull);
      expect(find.byType(SnackBar), findsNothing, reason: 'the first was said on the page alone');
      await tester.tap(find.text('Resend code'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(SnackBar), matching: find.text('We sent a 6-digit code to reader@example.org.')), findsOneWidget);
      expect(find.text('Resend in 30s'), findsOneWidget);
      expect(codeFocused(tester), isTrue);
    });

    testWidgets('opens the privacy policy from the link in its sentence, a link for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await account(tester);
      final link = find.descendant(of: find.byType(LinkedText), matching: find.text('Privacy'));
      expect(tester.getSemantics(link), isSemantics(label: 'Privacy', isLink: true, hasTapAction: true));
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byType(LegalScreen), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('follows the privacy link from the keyboard', (tester) async {
      await account(tester);
      Focus.of(tester.element(find.descendant(of: find.byType(LinkedText), matching: find.text('Privacy')))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(LegalScreen), findsOneWidget);
    });

    testWidgets('signed in, shows the member on a card, and edits the name in a dialog', (tester) async {
      final forums = DemoForumRepository();
      await forums.verifyCode('reader@example.org', '123456');
      await forums.updateDisplayName('Rivka');
      await account(tester, forums: forums);
      final card = find.byType(InfoCard).first;
      expect(find.descendant(of: card, matching: find.text('Rivka')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('reader@example.org')), findsOneWidget);
      expect(tester.getSize(find.descendant(of: card, matching: find.byType(InitialDisc))), const Size(56, 56));
      // A moderator's tag, with its shield: a label, not a chip, so nothing
      // about it reads as a control.
      final tag = find.descendant(of: card, matching: find.byType(SeferTag));
      expect(find.descendant(of: tag, matching: find.text('Moderator')), findsOneWidget);
      expect(find.descendant(of: tag, matching: find.byIcon(Icons.shield_outlined)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.byType(Chip)), findsNothing);
      expect(find.descendant(of: tag, matching: find.byType(InkWell)), findsNothing);
      // The name once, on the card: no heading over a field of the same name.
      expect(find.text('Display name'), findsNothing);

      await tester.tap(find.byTooltip('Edit display name'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(find.descendant(of: dialog, matching: find.text('Display name')), findsOneWidget);
      // Named by the dialog's title, the field shows no label of its own,
      // and takes the focus.
      final field = find.descendant(of: dialog, matching: find.byType(TextField));
      expect(tester.widget<TextField>(field).decoration?.labelText, isNull);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      await tester.enterText(find.descendant(of: dialog, matching: find.byType(TextField)), 'R');
      await tester.tap(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, 'Save')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: dialog, matching: find.text('Names must be 2–40 characters.')), findsOneWidget);
      await tester.enterText(find.descendant(of: dialog, matching: find.byType(TextField)), 'Rivka Levi');
      await tester.tap(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, 'Save')));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(find.descendant(of: card, matching: find.text('Rivka Levi')), findsOneWidget);
      expect(find.text('Name saved.'), findsOneWidget);
    });

    // At 200% on a phone the address broke as "rivka@example." over "org"
    // (here, in the test font's wide letters, a shorter one is as wide). One
    // too long for the card even at the smallest size the interface is set
    // in wraps at that size, rather than shrink out of sight.
    testWidgets('signed in, keeps the email whole with large text, but no smaller than 12', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      for (final email in ['rivka@ex.org', 'rivka.levi.of.the.shabbat.table@example.org']) {
        final forums = DemoForumRepository();
        await forums.verifyCode(email, '123456');
        await forums.updateDisplayName('Rivka Levi');
        await account(tester, forums: forums);
        expect(tester.takeException(), isNull);
        final text = find.text(email);
        // As drawn: the width it is set in, scaled.
        final scale = tester.getRect(text).width / tester.getSize(text).width;
        final size = tester.widget<Text>(text).style!.fontSize! * 2 * scale;
        if (email.length < 20) {
          expectWordsWhole(tester, email);
          expect(size, lessThan(26), reason: 'set smaller to fit');
        } else {
          expect(size, moreOrLessEquals(12), reason: 'at the smallest size, wrapped');
        }
      }
    });

    testWidgets('signed in with a machine\'s name, shows the email in its place', (tester) async {
      final forums = DemoForumRepository();
      await forums.verifyCode('reader@example.org', '123456');
      await account(tester, forums: forums);
      final card = find.byType(InfoCard).first;
      expect(find.descendant(of: card, matching: find.textContaining('user_')), findsNothing);
      expect(find.descendant(of: card, matching: find.text('reader@example.org')), findsOneWidget);
    });

    testWidgets('groups backup, privacy and the account, each said once', (tester) async {
      final forums = DemoForumRepository();
      await forums.verifyCode('reader@example.org', '123456');
      await forums.updateDisplayName('Rivka');
      final c = await account(tester, forums: forums);
      for (final heading in ['Cloud backup', 'Privacy & safety', 'Account']) {
        expect(find.descendant(of: find.byType(GroupHeader), matching: find.text(heading)), findsOneWidget, reason: heading);
      }
      expect(find.text('Back up my progress'), findsOneWidget);
      expect(find.text('Blocked members (0)'), findsOneWidget);
      expect(find.text('You haven’t blocked anyone.'), findsOneWidget);
      expect(find.text('Reports to review'), findsOneWidget);

      // Backup on: the switch, and Sync now beside it.
      expect(find.byTooltip('Sync now'), findsNothing);
      await tester.tap(find.text('Back up my progress'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).cloudSync, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.byTooltip('Sync now'), findsOneWidget);
      expect(find.textContaining('Last synced'), findsOneWidget);

      // Deleting the account is in error's ink, and so is what confirms it.
      final delete = find.text('Delete my account');
      final scheme = Theme.of(tester.element(delete)).colorScheme;
      expect(tester.widget<Text>(delete).style?.color, scheme.error);
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();
      final confirm = find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Delete my account'));
      final style = tester.widget<FilledButton>(confirm).style!;
      expect(style.backgroundColor?.resolve({}), scheme.error);
    });

    testWidgets('says that deleting the account takes its backup too, and offers a backup file first', (tester) async {
      final forums = DemoForumRepository();
      await forums.verifyCode('reader@example.org', '123456');
      await forums.updateDisplayName('Rivka');
      final c = await account(tester, forums: forums);
      Future<void> openDialog() async {
        final delete = find.text('Delete my account');
        await tester.ensureVisible(delete);
        await tester.pumpAndSettle();
        await tester.tap(delete);
        await tester.pumpAndSettle();
      }

      // Said with backup off too: a backup made before stays in the account
      // until the account goes.
      expect(c.read(settingsProvider).cloudSync, isFalse);
      await openDialog();
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.textContaining('the cloud backup of your progress, bookmarks and notes')),
        findsOneWidget,
      );
      expect(find.descendant(of: dialog, matching: find.textContaining('other devices keep what’s on them')), findsOneWidget);
      final buttons = find.descendant(of: dialog, matching: find.bySubtype<ButtonStyleButton>());
      expect(
        [for (final b in tester.widgetList<ButtonStyleButton>(buttons)) (b.child! as Text).data],
        ['Save a backup file first', 'Cancel', 'Delete my account'],
      );

      // A backup file first: Your data, and back to the account from there.
      await tester.tap(find.text('Save a backup file first'));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(_location(c), '/settings/data');
      expect(forums.currentUser, isNotNull, reason: 'nothing is deleted');
      await _goBack(tester);
      expect(_location(c), '/community/account');

      // On a wide screen, no wider than Material's dialogs.
      tester.view.physicalSize = const Size(1366, 860);
      await tester.pumpAndSettle();
      await openDialog();
      expect(tester.getSize(find.descendant(of: dialog, matching: find.byType(Material)).first).width, 560);
    });

    // In Settings, Your data opens above the account, and Back comes back to
    // it. Where Your data is beneath the account (its Cloud backup row opened
    // it), the account goes back to that one, rather than opening a second
    // above, which Back would lead round to again.
    testWidgets('in Settings, saves a backup file first in Your data, never a second one above the account',
        (tester) async {
      final forums = DemoForumRepository();
      await forums.verifyCode('reader@example.org', '123456');
      await forums.updateDisplayName('Rivka');
      final c = await _pump(tester, forums: forums);
      Future<void> backUpFirst() async {
        final delete = find.text('Delete my account');
        await tester.ensureVisible(delete);
        await tester.pumpAndSettle();
        await tester.tap(delete);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save a backup file first'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      }

      Future<void> open(String row) async {
        await tester.ensureVisible(find.text(row));
        await tester.pumpAndSettle();
        await tester.tap(find.text(row));
        await tester.pumpAndSettle();
      }

      c.read(routerProvider).go('/settings');
      await tester.pumpAndSettle();
      await open('Account & community');
      expect(_location(c), '/settings/account');
      await backUpFirst();
      expect(_location(c), '/settings/data');
      await _goBack(tester);
      expect(_location(c), '/settings/account');
      await _goBack(tester);
      expect(_location(c), '/settings');

      await open('Your data');
      await open('Cloud backup');
      expect(find.byType(AccountScreen), findsOneWidget);
      await backUpFirst();
      expect(_location(c), '/settings/data');
      expect(find.byType(AccountScreen), findsNothing, reason: 'the account is closed, not left beneath');
      expect(forums.currentUser, isNotNull, reason: 'nothing is deleted');
      await _goBack(tester);
      expect(_location(c), '/settings');
    });

    testWidgets('reads its backup row as one switch, Sync now an item of its own', (tester) async {
      final semantics = tester.ensureSemantics();
      final forums = DemoForumRepository();
      await forums.verifyCode('reader@example.org', '123456');
      await account(tester, forums: forums, settings: const AppSettings(onboardingComplete: true, cloudSync: true));
      final row = find.ancestor(of: find.text('Back up my progress'), matching: find.byType(PaperRow));
      final node = tester.getSemantics(row);
      expect(node, isSemantics(isButton: true, hasTapAction: true, hasToggledState: true, isToggled: true));
      expect(node.label, startsWith('Back up my progress'));
      final sync = tester.getSemantics(find.byTooltip('Sync now'));
      expect(sync, isSemantics(tooltip: 'Sync now', isButton: true, hasTapAction: true));
      expect(sync.id, isNot(node.id));
      // The switch is no tab stop of its own beside the row that toggles it.
      expect(find.descendant(of: find.byType(ExcludeFocus), matching: find.byType(Switch)), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('counts no blocked members it could not fetch, and still opens the list to say why', (tester) async {
      final forums = _NoBlockedList();
      await forums.verifyCode('reader@example.org', '123456');
      await forums.updateDisplayName('Rivka');
      await account(tester, forums: forums);
      expect(find.text('Blocked members (0)'), findsNothing);
      expect(find.text('You haven’t blocked anyone.'), findsNothing);
      await tester.tap(find.text('Blocked members'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(find.descendant(of: sheet, matching: find.byType(ErrorMessage)), findsOneWidget);
      // Tried again, the list comes, in the sheet still open.
      forums.offline = false;
      await tester.tap(find.descendant(of: sheet, matching: find.widgetWithText(FilledButton, 'Try again')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: sheet, matching: find.text('You haven’t blocked anyone.')), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('says in the sheet why an Unblock failed, and sends one at a time', (tester) async {
      final forums = _FailingUnblock();
      await forums.verifyCode('reader@example.org', '123456');
      await forums.updateDisplayName('Rivka');
      final author = (await forums.posts('1')).map((p) => p.authorId).firstWhere((id) => id != null && id != 'me')!;
      await forums.block(author);
      await account(tester, forums: forums);
      await tester.tap(find.text('Blocked members (1)'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      final unblock = find.descendant(of: sheet, matching: find.widgetWithText(TextButton, 'Unblock'));
      forums.gate = Completer<void>();
      await tester.tap(unblock);
      await tester.pump();
      expect(tester.widget<TextButton>(unblock).onPressed, isNull, reason: 'waits while it is sent');
      forums.gate!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(unblock).onPressed, isNotNull);
      expect(forums.calls, 1);
      expect(find.descendant(of: sheet, matching: find.textContaining('connection')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      // In full, however many lines it takes: here, in the test font's wide
      // letters, more than the two a row's subtitle is otherwise cut at.
      final why = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.descendant(of: sheet, matching: find.textContaining('connection')), matching: find.byType(RichText)).first,
      );
      final lines = why.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: why.text.toPlainText().length));
      expect({for (final box in lines) box.top.round()}.length, greaterThan(2));
      expect(why.didExceedMaxLines, isFalse);
    });

    for (final announces in [true, false]) {
      testWidgets(
          'says why an Unblock failed under the member, '
          '${announces ? 'and announces it' : 'a live region where nothing is announced'}', (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(supportsAnnounce: announces);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        final semantics = tester.ensureSemantics();
        final forums = _FailingUnblock();
        await forums.verifyCode('reader@example.org', '123456');
        await forums.updateDisplayName('Rivka');
        await forums.block('demo-author');
        await account(tester, forums: forums);
        await tester.tap(find.text('Blocked members (1)'));
        await tester.pumpAndSettle();
        tester.takeAnnouncements();
        await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.widgetWithText(TextButton, 'Unblock')));
        await tester.pumpAndSettle();
        const why = 'Couldn’t reach the server. Check your connection and try again.';
        final row = find.widgetWithText(PaperRow, 'Avraham');
        expect(tester.widget<PaperRow>(row).subtitle, why);
        expect([for (final a in tester.takeAnnouncements()) a.message], announces ? [why] : isEmpty);
        // The member and why, one item; Unblock an item of its own beside it.
        expect(tester.getSemantics(row), isSemantics(label: 'Avraham\n$why', isLiveRegion: !announces));
        semantics.dispose();
      });
    }

    for (final hebrew in [false, true]) {
      testWidgets(
          '${hebrew ? 'he' : 'en'}: lists each member by their initial, on paper lined up with the sheet\'s title',
          (tester) async {
        final forums = DemoForumRepository();
        await forums.verifyCode('reader@example.org', '123456');
        await forums.updateDisplayName('Rivka');
        for (final id in ['demo-author', 'demo-shira']) {
          await forums.block(id);
        }
        await account(
          tester,
          forums: forums,
          settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.english),
        );
        // Wide enough for Unblock beside each name in the test font, whose
        // every letter is as wide as it is high.
        tester.view.physicalSize = const Size(600, 915);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.block));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(find.descendant(of: sheet, matching: find.byType(ListTile)), findsNothing);
        final rows = find.descendant(of: sheet, matching: find.byType(PaperRow));
        expect(find.descendant(of: sheet, matching: find.byType(PaperGroup)), findsOneWidget);
        // A name in the interface's direction as it is, and one that runs
        // the other way isolated, so that each keeps its own at the row's
        // start.
        final (latin, hebrewName) = ('Avraham', 'שירה');
        expect([for (final r in tester.widgetList<PaperRow>(rows)) r.title],
            hebrew ? ['\u2068$latin\u2069', hebrewName] : [latin, '\u2068$hebrewName\u2069']);
        final box = tester.getRect(sheet);
        final paper = tester.getRect(find.descendant(of: sheet, matching: find.byType(PaperGroup)));
        double fromStart(Rect r) => hebrew ? box.right - r.right : r.left - box.left;
        expect(fromStart(paper), 24);
        for (var i = 0; i < 2; i++) {
          final row = rows.at(i);
          final disc = find.descendant(of: row, matching: find.byType(InitialDisc));
          expect(tester.widget<InitialDisc>(disc).name, [latin, hebrewName][i]);
          // The disc in the icon's slot, the name where a paper row's text
          // starts, and Unblock at the end of the name's line.
          expect(fromStart(tester.getRect(disc)), 24 + 16);
          final name = tester.getRect(find.descendant(of: row, matching: find.text(tester.widget<PaperRow>(row).title)));
          expect(fromStart(name), 24 + PaperGroup.iconInset);
          expect(tester.getCenter(disc).dy, moreOrLessEquals(name.center.dy, epsilon: 0.5));
          final unblock = tester.getRect(find.descendant(of: row, matching: find.byType(TextButton)));
          expect(unblock.center.dy, moreOrLessEquals(name.center.dy, epsilon: 0.5));
        }
      });
    }

    testWidgets('lists the members blocked in a sheet, until none are left', (tester) async {
      final forums = DemoForumRepository();
      await forums.verifyCode('reader@example.org', '123456');
      await forums.updateDisplayName('Rivka');
      final author = (await forums.posts('1')).map((p) => p.authorId).firstWhere((id) => id != null && id != 'me')!;
      await forums.block(author);
      await account(tester, forums: forums);
      expect(find.text('Blocked members (1)'), findsOneWidget);
      await tester.tap(find.text('Blocked members (1)'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(find.descendant(of: sheet, matching: find.text('Blocked members')), findsOneWidget);
      await tester.tap(find.descendant(of: sheet, matching: find.widgetWithText(TextButton, 'Unblock')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: sheet, matching: find.text('You haven’t blocked anyone.')), findsOneWidget);
      expect(await forums.blockedUsers(), isEmpty);
      expect(find.text('Blocked members (0)'), findsOneWidget);
    });

    testWidgets("asks a new account's name, then shows it signed in", (tester) async {
      final forums = DemoForumRepository();
      await account(tester, forums: forums);
      await sendCode(tester);
      await tester.enterText(codeField, '123456');
      await tester.pumpAndSettle();
      expect(find.text('Display name'), findsOneWidget);
      expect(find.text('Shown with your posts. 2–40 characters.'), findsOneWidget);
      // The initial the name will be shown with, as it is typed.
      await tester.enterText(find.byType(TextField), 'rivka');
      await tester.pump();
      expect(find.descendant(of: find.byType(InitialDisc), matching: find.text('R')), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save name'));
      await tester.pumpAndSettle();
      expect((await forums.myProfile())?.displayName, 'rivka');
      expect(find.byType(AccountScreen), findsOneWidget, reason: 'opened for itself, it stays');
      expect(find.text('Display name'), findsNothing);
      expect(find.descendant(of: find.byType(InfoCard).first, matching: find.text('rivka')), findsOneWidget);
    });
  });

  group('InitialDisc', () {
    testWidgets("a member's initial in the serif, on gold-ink paper, kept to its disc at 200%", (tester) async {
      await pumpThemed(tester, const Center(child: InitialDisc('miriam')), textScale: 2);
      expect(tester.getSize(find.byType(InitialDisc)), const Size(32, 32));
      final initial = tester.widget<Text>(find.text('M'));
      expect(initial.style?.fontFamily, 'EBGaramond');
      expect(initial.style?.fontWeight, FontWeight.w600);
      expect(initial.textScaler, TextScaler.noScaling);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a Hebrew initial, or a person before there is a name, and nothing for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpThemed(tester, const Center(child: InitialDisc('שירה', size: 56)));
      expect(find.text('ש'), findsOneWidget);
      expect(tester.getSize(find.byType(InitialDisc)), const Size(56, 56));
      expect(find.bySemanticsLabel('ש'), findsNothing);

      await pumpThemed(tester, const Center(child: InitialDisc(' ')));
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      semantics.dispose();
    });
  });
}
