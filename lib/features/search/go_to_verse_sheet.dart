import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/calendar/parsha_schedule.dart';
import '../../core/text/hebrew_text.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/paper_group.dart';
import '../parsha/week_context.dart';
import 'reference_parser.dart';
import 'verse_index.dart';

final referenceParserProvider = Provider<ReferenceParser>(
  (ref) => ReferenceParser.of(ref.watch(parshaRepositoryProvider)),
);

/// Opens the sheet where a verse is reached by its reference, or words are
/// handed to search: from the Parsha tab's search button, and Ctrl+K (⌘K).
///
/// It covers the whole window, the navigation too, from wherever it opens.
Future<void> showGoToVerse(BuildContext context) => showAppSheet<void>(
      context: Navigator.of(context, rootNavigator: true).context,
      isScrollControlled: true,
      builder: (_) => const GoToVerseSheet(),
    );

/// Ctrl+K (⌘K on Apple devices) opens [showGoToVerse] from anywhere in
/// [child], as it does in many apps.
class GoToVerseShortcut extends StatelessWidget {
  const GoToVerseShortcut({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final apple = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyK, control: !apple, meta: apple, includeRepeats: false): () =>
            showGoToVerse(context),
      },
      // The routes of the tabs, below, hold the focus as they open, so the
      // keys reach the shortcut before anything has been tapped or tabbed to.
      child: child,
    );
  }
}

/// One field: a reference typed there ("Bereshit 28:12", "בראשית כח, יב",
/// "3:22" in this week's book) is offered as a verse to open, in the reader
/// at that verse; anything worth searching for, as a search of the Torah.
class GoToVerseSheet extends ConsumerStatefulWidget {
  const GoToVerseSheet({super.key});

  @override
  ConsumerState<GoToVerseSheet> createState() => _GoToVerseSheetState();
}

/// What the field holds, and where it can lead.
class _Choices {
  const _Choices({required this.query, this.reference, this.location});

  final String query;

  /// The reference the query makes, if it makes one.
  final TypedReference? reference;

  /// Where a verse referred to is read this year: the week and its aliyah.
  final ({String weekId, int aliyah})? location;

  /// Whether the query is worth a search of the text: words, not a
  /// reference by its numbers (which the text has none of), though a name
  /// alone, such as ויצא, may be a word.
  bool get canSearch =>
      isSearchable(query) &&
      !query.contains(_digit) &&
      switch (reference) {
        null => true,
        VerseReference(:final byName) => byName,
        MissingVerse() => false,
      };

  static final _digit = RegExp(r'\d');
}

class _GoToVerseSheetState extends ConsumerState<GoToVerseSheet> {
  final _query = TextEditingController();
  final _field = FocusNode(debugLabel: 'go to verse');
  Timer? _announcement;

  @override
  void dispose() {
    _announcement?.cancel();
    _query.dispose();
    _field.dispose();
    super.dispose();
  }

  _Choices _choices() {
    final query = _query.text.trim();
    final repo = ref.read(parshaRepositoryProvider);
    final book = repo.portion(ref.read(currentWeekProvider).portion).book;
    final reference = ref.read(referenceParserProvider).parse(query, currentBook: book);
    return _Choices(
      query: query,
      reference: reference,
      location: reference is VerseReference ? ref.read(verseLocatorProvider)(reference.book, reference.verse) : null,
    );
  }

  void _changed() {
    setState(() {});
    _announceSoon();
  }

  /// Says what the first row now offers, once typing pauses.
  void _announceSoon() {
    _announcement?.cancel();
    _announcement = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || !MediaQuery.supportsAnnounceOf(context)) return;
      final message = _rows(_choices()).firstOrNull?.label;
      if (message == null) return;
      SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
    });
  }

  void _clear() {
    _query.clear();
    _field.requestFocus();
    _changed();
  }

  void _openVerse(VerseReference reference, ({String weekId, int aliyah}) at) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push('/read/${at.weekId}/${at.aliyah}?verse=${reference.verse}');
  }

  void _search(String query) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push('/search?q=${Uri.encodeQueryComponent(query)}');
  }

  /// Enter: the first row that leads somewhere.
  void _submit() {
    final first = _rows(_choices()).where((r) => r.onTap != null).firstOrNull;
    if (first == null) {
      _field.requestFocus();
      return;
    }
    first.onTap!();
  }

  /// The rows the sheet offers for [c], in order: the verse referred to (or
  /// why there is none), then a search for the words.
  List<_Row> _rows(_Choices c) {
    final l = context.l10n;
    final names = Names(context);
    final ashkenazi = ref.read(settingsProvider).ashkenaziNames;
    final repo = ref.read(parshaRepositoryProvider);
    return [
      switch ((c.reference, c.location)) {
        (final VerseReference r, final at?) => _Row(
            icon: Icons.menu_book_outlined,
            title: names.reference(r.book, r.verse.chapter, r.verse.verse),
            subtitle: '${names.portion(repo.portion(PortionId.parse(at.weekId.split(':').last)), ashkenazi: ashkenazi)}'
                ' · ${names.aliyah(at.aliyah)}',
            onTap: () => _openVerse(r, at),
          ),
        (MissingVerse(:final book, :final chapter, verses: final verses?), _) => _Row(
            icon: Icons.info_outline,
            title: l.goToVerseVerses(names.book(book), names.verseNumber(chapter), verses),
          ),
        (MissingVerse(:final book, :final chapters), _) => _Row(
            icon: Icons.info_outline,
            title: l.goToVerseChapters(names.book(book), chapters),
          ),
        _ => null,
      },
      // The query keeps its own direction inside the sentence.
      if (c.canSearch)
        _Row(icon: Icons.search, title: l.goToVerseSearch('\u2068${c.query}\u2069'), onTap: () => _search(c.query)),
    ].nonNulls.toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Rebuilt as the week or the names change under it.
    ref.watch(currentWeekProvider);
    final ashkenazi = ref.watch(settingsProvider.select((s) => s.ashkenaziNames));
    final padding = sheetPadding(context);
    final rows = _rows(_choices());
    // The hint names the first parsha as the reader spells parsha names.
    final bereshit = Names(context).portion(ref.watch(parshaRepositoryProvider).byNumber(1), ashkenazi: ashkenazi);
    return Padding(
      // Above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(l.searchTitle),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _query,
                    focusNode: _field,
                    autofocus: true,
                    textInputAction: TextInputAction.go,
                    autocorrect: false,
                    enableSuggestions: false,
                    // Hebrew is written from the right, whatever the language
                    // of the app.
                    textDirection: HebrewText.containsHebrew(_query.text) ? TextDirection.rtl : null,
                    decoration: InputDecoration(
                      labelText: l.goToVerseLabel,
                      hintText: l.goToVerseHint(bereshit),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(tooltip: l.searchClear, icon: const Icon(Icons.close), onPressed: _clear),
                    ),
                    onChanged: (_) => _changed(),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (rows.isNotEmpty) ...[
                    const Gap(16),
                    PaperGroup(
                      children: [
                        for (final r in rows)
                          PaperRow(icon: r.icon, title: r.title, subtitle: r.subtitle, onTap: r.onTap),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row the sheet offers.
class _Row {
  const _Row({required this.icon, required this.title, this.subtitle, this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Null for a row that only informs.
  final VoidCallback? onTap;

  /// What a screen reader says of it.
  String get label => subtitle == null ? title : '$title, $subtitle';
}
