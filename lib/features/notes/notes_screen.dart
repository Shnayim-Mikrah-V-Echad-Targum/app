import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/text/hebrew_text.dart';
import '../../data/models/parsha.dart';
import '../../data/models/verse_ref.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';
import '../../ui/widgets/paper_group.dart';
import '../community/ui/community_ui.dart' show autoDirection;
import '../parsha/week_context.dart';
import '../reader/reader_screen.dart' show ReaderTexts, readerTextsProvider;
import '../reader/scripture_text.dart';
import '../reader/verse_actions_sheet.dart';
import '../settings/app_settings.dart';
import 'domain/annotations.dart';
import 'note_dialog.dart';

/// Where the list of bookmarks and notes is: of every verse, or with [weekId]
/// of that week's parsha alone.
String notesPath({String? weekId}) =>
    weekId == null ? '/notes' : Uri(path: '/notes', queryParameters: {'week': weekId}).toString();

/// The verses the reader has bookmarked or written a note on (DESIGN.md §3):
/// by book and then chapter, in the Torah's order, each opening the reader's
/// full text at the verse. With [weekId], those of that week's parsha alone,
/// which open in that week.
///
/// A long press or a secondary click on a row, its menu button, or Shift+F10
/// and the menu key, open the verse's options, as in the reader: there the
/// bookmark is taken away, and the note written or deleted.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key, this.weekId});

  final String? weekId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final weekId = this.weekId;
    final week = weekId == null ? null : ref.watch(weekContextProvider(weekId));
    // A link to a week that doesn't exist.
    if (weekId != null && week == null) return const NotFoundPage();
    final s = ref.watch(settingsProvider);
    final repo = ref.watch(parshaRepositoryProvider);
    final annotations = ref.watch(annotationsProvider);
    final range = week?.portion.range;
    // Only verses there are: a key for another verse is kept, not shown.
    final marked = [
      for (final e in range == null ? annotations.inTorah : annotations.within(range))
        if (_exists(repo.chapterLengths(e.$1.book), e.$1.ref)) e,
    ];
    final books = [for (final b in kTorahBooks) if (marked.any((e) => e.$1.book == b)) b];
    // Each book's text, as the reader would copy it: with the Targum and the
    // translation where it shows them.
    final texts = {for (final b in books) b: ref.watch(readerTextsProvider((b, s.usesOnkelos, s.showTranslation, null)))};

    final Widget body;
    if (texts.values.any((t) => t.hasError)) {
      body = CenteredMessage(
        text: l.errorGeneric,
        actions: [FilledButton.tonal(onPressed: () => ref.invalidate(readerTextsProvider), child: Text(l.actionRetry))],
      );
    } else if (texts.values.any((t) => !t.hasValue)) {
      body = Center(child: Semantics(label: l.loading, child: const CircularProgressIndicator()));
    } else {
      body = PageBody(
        children: [
          if (week != null) _Heading.parsha(week.portion, settings: s, first: true),
          if (marked.isEmpty)
            EmptyState(message: week == null ? l.notesEmpty : l.notesEmptyParsha)
          else
            for (final (i, book) in books.indexed) ...[
              if (week == null) _Heading.book(book, first: i == 0),
              for (final chapter in {for (final e in marked) if (e.$1.book == book) e.$1.ref.chapter}) ...[
                _ChapterLabel(chapter),
                PaperGroup(
                  ruleInset: PaperGroup.iconInset,
                  children: [
                    for (final (verse, marks) in marked)
                      if (verse.book == book && verse.ref.chapter == chapter)
                        _NoteRow(
                          key: ValueKey('$verse'),
                          verse: verse,
                          marks: marks,
                          texts: texts[book]!.requireValue,
                          week: week,
                          page: context,
                        ),
                  ],
                ),
              ],
            ],
          if (week != null) ...[
            const Gap(Space.xxl),
            Center(
              child: TextButton(onPressed: () => context.pushReplacement(notesPath()), child: Text(l.notesShowAll)),
            ),
          ],
        ],
      );
    }
    // A right-click on a row opens its options, as on a verse in the
    // reader: on the web, the browser's menu stays away.
    return OwnContextMenu(child: PageScaffold(titleText: l.notesTitle, leading: homeLeading(context), body: body));
  }

  static bool _exists(List<int> chapters, VerseRef r) =>
      r.chapter >= 1 && r.chapter <= chapters.length && r.verse >= 1 && r.verse <= chapters[r.chapter - 1];
}

/// The heading over a book's verses, as Browse heads a book: its Hebrew
/// name in Frank Ruhl Libre and, in the English UI, its English name after
/// it, one paragraph, so that large text wraps the one under the other. Over
/// a parsha's, the parsha's name, set the same way.
class _Heading extends StatelessWidget {
  _Heading.book(String book, {required this.first})
      : hebrew = kTorahBooksHe[kTorahBooks.indexOf(book)],
        latin = book,
        parsha = null;

  _Heading.parsha(PortionInfo this.parsha, {required AppSettings settings, required this.first})
      : hebrew = HebrewText.stripNikud(parsha.nameHe),
        latin = parsha.displayName(ashkenazi: settings.ashkenaziNames);

  final String hebrew;
  final String latin;
  final PortionInfo? parsha;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hebrewUi = context.isHebrewUi;
    final parsha = this.parsha != null;
    // "פרשת בראשית" in the Hebrew UI, where a parsha's name alone would read
    // as its book's.
    final he = parsha && hebrewUi ? l.parshaLabel(hebrew) : hebrew;
    final label = hebrewUi ? he : (parsha ? l.parshaLabel(latin) : latin);
    final style = SeferType.of(context).hebrewDisplay.copyWith(
          fontSize: 20,
          fontWeight: SeferColors.of(context).isHighContrast ? FontWeight.w700 : FontWeight.w600,
          color: scheme.onSurface,
        );
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(Space.xs, first ? Space.sm : Rhythm.sectionGap, 0, Space.xs),
      child: Semantics(
        header: true,
        headingLevel: 2,
        label: label,
        child: ExcludeSemantics(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: he, style: style, locale: const Locale('he')),
              if (!hebrewUi) ...[
                const TextSpan(text: '  '),
                TextSpan(
                  text: parsha ? l.parshaLabel(latin) : latin,
                  style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// The label over a chapter's verses: "Chapter 3", or "פרק ג" in the Hebrew
/// UI. A heading of level 3, under its book's.
class _ChapterLabel extends StatelessWidget {
  const _ChapterLabel(this.chapter);

  final int chapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = context.isHebrewUi ? HebrewText.gematria(chapter, punctuate: false) : '$chapter';
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.lg, 0, Space.sm),
      child: Semantics(
        header: true,
        headingLevel: 3,
        child: Text(
          context.l10n.chapterLabel(number),
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// One verse marked: a bookmark in techelet, or a note's icon, where a
/// row's icon sits; the reference; the verse, as search sets one (§6.25);
/// and the reader's note in their own words, in its own direction. A tap
/// opens the reader at the verse; its menu button, a long press or a
/// secondary click, the verse's options.
class _NoteRow extends ConsumerWidget {
  const _NoteRow({
    super.key,
    required this.verse,
    required this.marks,
    required this.texts,
    this.week,
    required this.page,
  });

  final BookVerse verse;
  final Annotation marks;
  final ReaderTexts texts;

  /// The list's page, which the verse's options open over: unlike the row,
  /// which goes once its bookmark is taken away in them, it stays to open
  /// the note, ask about the verse or say that it was copied.
  final BuildContext page;

  /// The week whose parsha the list is of, where the verse opens; otherwise
  /// the week of this year's cycle that reads it.
  final WeekContext? week;

  void _open(BuildContext context, WidgetRef ref) {
    final week = this.week;
    final at = week == null
        ? ref.read(verseLocatorProvider)(verse.book, verse.ref)
        : (weekId: week.id, aliyah: week.portion.aliyot.indexWhere((a) => a.contains(verse.ref)));
    if (at == null || at.aliyah < 0) return;
    context.push('/read/${at.weekId}/${at.aliyah}?mode=full&verse=${verse.ref}');
  }

  void _options() => showVerseActions(
        page,
        ChosenVerse(
          at: verse,
          hebrew: texts.mikrah.verse(verse.ref),
          targum: texts.onkelos?.verse(verse.ref),
          english: texts.english?.verse(verse.ref).readText,
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = ref.watch(settingsProvider);
    final hebrew = texts.mikrah.verse(verse.ref);
    final reference = Names(context).reference(verse.book, verse.ref.chapter, verse.ref.verse);
    final note = marks.note;
    final scaler = MediaQuery.textScalerOf(context);
    // Text is never cut short once it is enlarged (WCAG 1.4.4).
    final enlarged = scaler.scale(1) > 1;
    final referenceStyle = theme.textTheme.titleSmall!.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final verseStyle = TextStyle(
      fontFamily: s.scriptureFont.family,
      fontFamilyFallback: const ['NotoSerifHebrew', 'NotoSansHebrew'],
      fontSize: 20,
      height: 1.7,
      leadingDistribution: TextLeadingDistribution.even,
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
      color: scheme.onSurface,
    );

    // One item for a screen reader: the reference, the marks, the verse
    // spoken as the reader's are, tagged as Hebrew, and the note, tagged
    // with its own language where it isn't the interface's.
    final spoken = spokenVerse(hebrew, s, kind: ScriptureKind.mikrah);
    final label = StringBuffer('$reference. ');
    if (marks.bookmarked) label.write('${l.verseBookmarked}. ');
    final hebrewStart = label.length;
    label.write(spoken);
    final hebrewEnd = label.length;
    final attributes = <StringAttribute>[
      LocaleStringAttribute(range: TextRange(start: hebrewStart, end: hebrewEnd), locale: const Locale('he')),
    ];
    if (note != null) {
      final said = l.yourNoteLabel(note);
      final start = label.length + 2 + said.indexOf(note);
      label.write('. $said');
      if (noteLocale(context, note) case final locale?) {
        attributes.add(LocaleStringAttribute(range: TextRange(start: start, end: start + note.length), locale: locale));
      }
    }

    void options() => _options();
    final row = Semantics(
      container: true,
      button: true,
      attributedLabel: AttributedString(label.toString(), attributes: attributes),
      // The ink well's long press, which opens them too, is the row's.
      customSemanticsActions: {CustomSemanticsAction(label: l.verseOptions): options},
      child: GestureDetector(
        // A right-click, as on a verse in the reader. Screen readers have the
        // ink well's tap, and the options among the row's actions.
        excludeFromSemantics: true,
        onSecondaryTapUp: (_) => options(),
        child: SeferInkWell(
          onTap: () => _open(context, ref),
          onLongPress: () {
            Feedback.forLongPress(context);
            options();
          },
          borderRadius: PaperGroup.rowCorners(context),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 0, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Where a row's icon sits, centred on the reference's line.
                SizedBox(
                  width: PaperGroup.iconInset - 16,
                  height: scaler.scale(referenceStyle.fontSize!) * referenceStyle.height!,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ExcludeSemantics(
                      child: marks.bookmarked
                          ? Icon(Icons.bookmark, size: 22, color: scheme.primary)
                          : Icon(Icons.sticky_note_2_outlined, size: 22, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(reference, style: referenceStyle),
                        const Gap(Space.xs),
                        Text(
                          displayHebrew(hebrew.readText, s.copyWith(showTeamim: false)),
                          style: verseStyle,
                          textDirection: TextDirection.rtl,
                          locale: const Locale('he'),
                          maxLines: enlarged ? null : 2,
                          overflow: enlarged ? null : TextOverflow.ellipsis,
                        ),
                        if (note != null) ...[
                          const Gap(Space.xs),
                          Text(
                            note,
                            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
                            textDirection: autoDirection(note, fallback: Directionality.of(context)),
                            maxLines: enlarged ? null : 4,
                            overflow: enlarged ? null : TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Its own item and tab stop beside the row's, as a paper
                // row's menu is.
                IconButton(tooltip: l.verseOptions, icon: const Icon(Icons.more_vert), onPressed: options),
              ],
            ),
          ),
        ),
      ),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f10, shift: true, includeRepeats: false): options,
        const SingleActivator(LogicalKeyboardKey.contextMenu, includeRepeats: false): options,
      },
      child: row,
    );
  }
}
