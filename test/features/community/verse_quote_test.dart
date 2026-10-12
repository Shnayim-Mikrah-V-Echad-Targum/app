import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/models.dart';
import 'package:shnayim_mikra/features/community/ui/community_ui.dart';
import 'package:shnayim_mikra/features/community/ui/forum_screen.dart';
import 'package:shnayim_mikra/features/community/ui/thread_screen.dart';

import '../../helpers.dart';

/// Where its first post is a question about a verse, a reply that quotes
/// that post, as a member answering it would write.
class _Answered extends DemoForumRepository {
  @override
  Future<List<Post>> posts(String threadId, {(DateTime, String)? before, int limit = ForumRepository.postsPageSize}) async {
    final posts = await super.posts(threadId, before: before, limit: limit);
    final first = posts.firstOrNull;
    if (first == null || splitVerseQuote(first.body).verse == null) return posts;
    return [
      ...posts,
      Post(
        id: '9999',
        threadId: threadId,
        authorId: 'rivka',
        authorName: 'Rivka',
        body: 'The angels, says Rashi.',
        createdAt: first.createdAt.add(const Duration(minutes: 5)),
        replyToId: first.id,
        quote: QuotedPost(authorName: first.authorName, body: first.body),
      ),
    ];
  }
}

/// A listing as the server gave it before it knew a question about a verse
/// (supabase/migrations/20261012010000_excerpt_after_verse.sql): the post's
/// lines run together, the verse first, cut short within it.
class _ListedAsBefore extends DemoForumRepository {
  @override
  Future<List<ThreadSummary>> threads({
    int? forumId,
    int? parshaNumber,
    (DateTime, String)? after,
    int limit = ForumRepository.threadsPageSize,
  }) async => [
        for (final t in await super.threads(forumId: forumId, parshaNumber: parshaNumber, after: after, limit: limit))
          if (t.authorId == 'me')
            t.copyWith(excerpt: '${(await posts(t.id)).first.body.replaceAll(RegExp(r'\s+'), ' ').substring(0, 60)}…')
          else
            t,
      ];
}

/// A question about a verse, as "Ask about this verse" posts one: the verse
/// quoted, then the question, in one post as it always was, and shown as a
/// quotation over the question.
void main() {
  // Genesis 3:22 as the app quotes it, with the Names written ה׳ and אלקים.
  const verse = 'וַיֹּאמֶר ה׳ אֱלֹקִים הֵן הָאָדָם הָיָה כְּאַחַד מִמֶּנּוּ לָדַעַת טוֹב וָרָע';
  const question = 'Why “like one of us”? Who is “us”?';

  group('splitVerseQuote', () {
    test('parts a question from the verse it quotes, after a left-to-right mark or not', () {
      expect(splitVerseQuote('\u200E> $verse\n\n$question'), (verse: verse, rest: question));
      expect(splitVerseQuote('> $verse\n\nלמה "כאחד ממנו"?'), (verse: verse, rest: 'למה "כאחד ממנו"?'));
      // At the first blank line only: the question's own paragraphs stay.
      expect(
        splitVerseQuote('> $verse\n\n$question\n\nAnd why now?'),
        (verse: verse, rest: '$question\n\nAnd why now?'),
      );
    });

    test('takes all of a body with no blank line for the verse: the question edited away, or an excerpt cut short', () {
      expect(splitVerseQuote('> $verse'), (verse: verse, rest: ''));
      expect(splitVerseQuote('\u200E> $verse\n\n'), (verse: verse, rest: ''));
      // An excerpt, its lines run together, holds no blank line.
      expect(splitVerseQuote('\u200E> $verse $question'), (verse: '$verse $question', rest: ''));
    });

    test('finds no verse in a post that doesn’t begin with one', () {
      for (final body in [
        question,
        '',
        '>$verse\n\n$question',
        ' > $verse\n\n$question',
        '‏> $verse\n\n$question',
        // A quote of words in English, as an email quotes them, is no verse.
        '> Is anyone reading?\n\nCount me in.',
        'As it says:\n\n> $verse',
      ]) {
        expect(splitVerseQuote(body), (verse: null, rest: body), reason: body);
      }
    });

    test('parts what withVerseQuote puts together', () {
      for (final leftToRight in [true, false]) {
        expect(withVerseQuote(verse, question, leftToRight: leftToRight).startsWith('\u200E'), leftToRight);
        expect(splitVerseQuote(withVerseQuote(verse, question, leftToRight: leftToRight)), (verse: verse, rest: question));
        expect(splitVerseQuote(withVerseQuote(verse, '', leftToRight: leftToRight)), (verse: verse, rest: ''));
      }
    });
  });

  // The cases supabase/tests/behavior.sql checks the server's listing with.
  group('an excerpt', () {
    test('of a question about a verse is its question, however long the verse', () {
      final long = List.filled(8, 'וַיֹּאמֶר ה׳ אֱלֹקִים הֵן הָאָדָם').join(' ');
      expect(threadExcerpt('\u200E> $long\n\nWhy "like one of us"?\n\nAnd why now?'), 'Why "like one of us"? And why now?');
      expect(threadExcerpt('> בְּרֵאשִׁית בָּרָא\n\nלמה בבי״ת?'), 'למה בבי״ת?');
    });

    test('is none for a post of nothing but the verse', () {
      expect(threadExcerpt('\u200E> בְּרֵאשִׁית בָּרָא'), isNull);
    });

    test('keeps a quote of words in English, which is no verse', () {
      expect(threadExcerpt('> Is anyone reading?\n\nCount me in.'), '> Is anyone reading? Count me in.');
    });
  });

  group('in the app', () {
    /// A member, Reader, who has asked [question] about Genesis 3:22 in
    /// Questions & answers, as the app posts it from the English UI; with the
    /// app open on [route] (the discussion, where it has no `{id}`).
    Future<(String, DemoForumRepository)> asked(
      WidgetTester tester, {
      String route = '/community/thread/{id}',
      DemoForumRepository? forums,
    }) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      forums ??= _Answered();
      await forums.verifyCode('reader@example.org', '123456');
      await forums.updateDisplayName('Reader');
      await forums.acceptGuidelines();
      final id = await forums.createThread(
        forumId: 2,
        title: 'Question on Genesis 3:22',
        body: withVerseQuote(verse, question, leftToRight: true),
      );
      final c = await pumpApp(tester, forums: forums);
      c.read(routerProvider).go(route.replaceFirst('{id}', id));
      await tester.pumpAndSettle();
      return (id, forums);
    }

    testWidgets('a question about a verse shows the verse as a quotation, over its question', (tester) async {
      final handle = tester.ensureSemantics();
      await asked(tester);
      final post = find.byType(PostCard).first;
      final quote = find.descendant(of: post, matching: find.byType(VerseQuote));
      expect(tester.widget<VerseQuote>(quote).hebrew, verse);
      expect(tester.widget<VerseQuote>(quote).maxLines, isNull, reason: 'the whole verse');
      expect(find.descendant(of: post, matching: find.text(question)), findsOneWidget);
      expect(find.textContaining('> '), findsNothing, reason: 'never the raw quote');
      // Over the question, ruled at its right where the Hebrew begins.
      final text = find.descendant(of: post, matching: find.text(question));
      expect(tester.getBottomLeft(quote).dy, lessThan(tester.getTopLeft(text).dy));
      final rule = tester.widget<Container>(find.descendant(of: quote, matching: find.byType(Container)));
      expect(
        (rule.decoration! as BoxDecoration).border,
        isA<BorderDirectional>().having((b) => b.start.width, 'start', 2).having((b) => b.end, 'end', BorderSide.none),
      );
      expect(Directionality.of(tester.element(find.descendant(of: quote, matching: find.byType(RichText)))), TextDirection.rtl);
      // Read in a Hebrew voice, the Name as it is said.
      final spoken = tester.getSemantics(find.descendant(of: quote, matching: find.byType(RichText)));
      expect(spoken.label, contains('אֲדֹנָי אֱלֹקִים'));
      expect(spoken.getSemanticsData().locale, const Locale('he'));
      handle.dispose();
    });

    testWidgets('its forum lists it by its question', (tester) async {
      await asked(tester, route: '/community/forum/questions');
      final row = find.ancestor(of: find.text('Question on Genesis 3:22'), matching: find.byType(ThreadTile));
      expect(find.descendant(of: row, matching: find.text(question)), findsOneWidget);
      expect(find.descendant(of: row, matching: find.textContaining('>')), findsNothing);
    });

    testWidgets('a forum listing from before, whose excerpt begins with the verse, shows none of it', (tester) async {
      await asked(tester, route: '/community/forum/questions', forums: _ListedAsBefore());
      final row = find.ancestor(of: find.text('Question on Genesis 3:22'), matching: find.byType(ThreadTile));
      // Cut short within the verse, it holds nothing of the question.
      expect(find.descendant(of: row, matching: find.textContaining(verse.substring(0, 10))), findsNothing);
      expect(find.descendant(of: row, matching: find.textContaining('Reader')), findsOneWidget, reason: 'the facts stay');
    });

    testWidgets('a reply quotes its question, the verse being the post’s own', (tester) async {
      await asked(tester);
      expect(find.text('Reader: $question'), findsOneWidget);
      expect(find.byType(VerseQuote), findsOneWidget, reason: 'the question’s own, not the reply’s');
    });

    testWidgets('editing it edits the question, and keeps the verse quoted', (tester) async {
      final (id, forums) = await asked(tester);
      await tester.tap(find.byTooltip('More options for Reader'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(tester.widget<VerseQuote>(find.descendant(of: dialog, matching: find.byType(VerseQuote))).hebrew, verse);
      final field = find.descendant(of: dialog, matching: find.byType(TextField));
      expect(tester.widget<TextField>(field).controller!.text, question);

      await tester.enterText(field, 'Why “like one of us”, in the plural?');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      final posts = await forums.posts(id);
      expect(posts.first.body, '\u200E> $verse\n\nWhy “like one of us”, in the plural?');
      expect(find.text('Why “like one of us”, in the plural?'), findsOneWidget);
    });
  });
}
