import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/text/hebrew_text.dart';
import '../../data/text_repository.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';
import '../../ui/widgets/paper_group.dart';
import '../parsha/week_context.dart';
import '../settings/app_settings.dart';
import 'marked_text.dart';
import 'query_direction.dart';
import 'verse_index.dart';

/// The verse index while it is built: the share read so far, then the index
/// itself, or what stopped it.
class VerseIndexState {
  const VerseIndexState({this.progress = 0, this.index, this.error});

  final double progress;
  final VerseIndex? index;
  final Object? error;
}

/// Builds the verse index the first time search opens, and keeps it for the
/// rest of the session, so search opens at once after that.
class VerseIndexLoader extends Notifier<VerseIndexState> {
  @override
  VerseIndexState build() {
    unawaited(_load());
    return const VerseIndexState();
  }

  Future<void> _load() async {
    try {
      final index = await VerseIndex.build(
        ref.read(textRepositoryProvider),
        onProgress: (share) {
          if (ref.mounted) state = VerseIndexState(progress: share);
        },
      );
      if (ref.mounted) state = VerseIndexState(progress: 1, index: index);
    } catch (e) {
      if (ref.mounted) state = VerseIndexState(progress: state.progress, error: e);
    }
  }

  void retry() {
    state = const VerseIndexState();
    unawaited(_load());
  }
}

final verseIndexProvider = NotifierProvider<VerseIndexLoader, VerseIndexState>(VerseIndexLoader.new);

/// Finds a word or phrase in the Torah, Targum Onkelos and the translation.
/// Each verse found opens the reader at that verse, in full text.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  /// What to search for as the page opens, if anything.
  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _query = TextEditingController(text: widget.initialQuery);
  final _field = FocusNode(debugLabel: 'search');
  Timer? _announcement;

  // The last search, kept while nothing it depends on changes.
  SearchResults? _results;
  (String, bool, VerseIndex)? _searched;

  @override
  void initState() {
    super.initState();
    // Handed a search (by Go to verse): its count is said as it would be
    // once typing paused.
    if (isSearchable(widget.initialQuery)) _announceSoon();
  }

  @override
  void dispose() {
    _announcement?.cancel();
    _query.dispose();
    _field.dispose();
    super.dispose();
  }

  SearchResults? _search(VerseIndex? index, bool nikud) {
    if (index == null) return null;
    final key = (_query.text, nikud, index);
    if (key != _searched) {
      _results = index.search(_query.text, nikud: nikud);
      _searched = key;
    }
    return _results;
  }

  void _changed() {
    setState(() {});
    _announceSoon();
  }

  /// Tells a screen reader how many verses were found, once typing pauses.
  void _announceSoon() {
    _announcement?.cancel();
    _announcement = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final results = _search(ref.read(verseIndexProvider).index, ref.read(settingsProvider).showNikud);
      if (results == null || !isSearchable(_query.text)) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.l10n.searchResultsAnnounced(results.total),
        Directionality.of(context),
      );
    });
  }

  void _clear() {
    _query.clear();
    _field.requestFocus();
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = ref.watch(verseIndexProvider);
    final nikud = ref.watch(settingsProvider.select((s) => s.showNikud));
    // A search typed while the index was built is answered once it's ready.
    ref.listen(verseIndexProvider.select((s) => s.index), (before, now) {
      if (before == null && now != null) _announceSoon();
    });
    final query = _query.text.trim();
    final results = _search(status.index, nikud);

    final Widget body;
    if (status.error != null) {
      body = ListView(children: [
        EmptyState(
          message: l.errorGeneric,
          actionLabel: l.actionRetry,
          onAction: () => ref.read(verseIndexProvider.notifier).retry(),
        ),
      ]);
    } else if (results == null) {
      body = ListView(children: [_Preparing(progress: status.progress)]);
    } else if (!isSearchable(query)) {
      body = ListView(children: [EmptyState(message: l.searchIntro)]);
    } else if (results.total == 0) {
      body = _NoResults(query: query);
    } else {
      body = _Results(results: results, onOpen: () => _field.unfocus());
    }

    return Scaffold(
      // Opened from a link or a web reload, with nothing beneath: a way home.
      appBar: AppBar(leading: homeLeading(context), title: Text(l.searchTitle)),
      body: Column(
        children: [
          _Width(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _query,
                focusNode: _field,
                autofocus: true,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                enableSuggestions: false,
                // Hebrew is written from the right and English from the left,
                // whatever the language of the app.
                textDirection: queryDirection(_query.text),
                decoration: InputDecoration(
                  labelText: l.searchFieldLabel,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(tooltip: l.searchClear, icon: const Icon(Icons.close), onPressed: _clear),
                ),
                onChanged: (_) => _changed(),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Content at the page's width, between its gutters.
class _Width extends StatelessWidget {
  const _Width({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SizedBox(
            width: double.infinity,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child),
          ),
        ),
      );
}

/// The index being built, the first time search opens.
class _Preparing extends StatelessWidget {
  const _Preparing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Text(l.searchPreparing, style: SeferType.of(context).marginalia, textAlign: TextAlign.center),
              ),
              const Gap(16),
              LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
                semanticsLabel: l.searchPreparing,
                semanticsValue: '${(progress * 100).round()}%',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A search that found nothing, and what might find something.
class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final hebrew = HebrewText.containsHebrew(query);
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _Width(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 24, 4, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The query keeps its own direction inside the sentence.
                Text(l.searchNoResults('\u2068$query\u2069'), style: theme.textTheme.bodyLarge),
                const Gap(8),
                Text(
                  hebrew ? l.searchNoResultsHint : l.searchNoResultsHintEnglish,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The verses found, under the parsha of each.
class _Results extends ConsumerWidget {
  const _Results({required this.results, required this.onOpen});

  final SearchResults results;

  /// Called as a verse opens.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final names = Names(context);
    final ashkenazi = ref.watch(settingsProvider.select((s) => s.ashkenaziNames));
    final groups = groupByParsha(results.hits, ref.watch(parshaRepositoryProvider).all);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final summary = results.truncated
        ? l.searchResultsFirst(results.hits.length, results.total)
        : l.searchResultsCount(results.total);
    // Built as they scroll into view: a search can list 200 verses. Each
    // search's list starts at its top, with its count.
    return ListView.builder(
      key: ValueKey(results.query),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: groups.length + (results.truncated ? 2 : 1),
      itemBuilder: (context, i) {
        if (i == 0) {
          return _Width(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 4, 0),
              child: Text(summary, style: muted),
            ),
          );
        }
        if (i > groups.length) {
          return _Width(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 4, 0),
              child: Text(l.searchNarrow, style: muted),
            ),
          );
        }
        final group = groups[i - 1];
        return _Width(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GroupHeader(names.portion(group.parsha, ashkenazi: ashkenazi)),
              PaperGroup(children: [for (final hit in group.hits) _HitRow(hit: hit, onOpen: onOpen)]),
            ],
          ),
        );
      },
    );
  }
}

/// One verse found: its reference, and its text around what was found.
class _HitRow extends ConsumerWidget {
  const _HitRow({required this.hit, required this.onOpen});

  final VerseHit hit;
  final VoidCallback onOpen;

  void _open(BuildContext context, WidgetRef ref) {
    final at = ref.read(verseLocatorProvider)(hit.book, hit.ref);
    if (at == null) return;
    onOpen();
    context.push('/read/${at.weekId}/${at.aliyah}?mode=full&verse=${hit.ref.chapter}:${hit.ref.verse}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final reference = Names(context).reference(hit.book, hit.ref.chapter, hit.ref.verse);
    // Found only in the Targum: say so, as the verse above it is unmarked.
    // The translation is labelled as such, a study aid (DESIGN.md §3).
    final targumOnly = hit.snippets.length > 1 && !hit.snippets.first.matched;
    final english = hit.snippets.first.layer == TextLayer.english;
    final heading = targumOnly
        ? '$reference · ${l.passTargum}'
        : english
            ? '$reference · ${l.translationLabel}'
            : reference;

    // One item for a screen reader: the reference, then each layer, each
    // tagged with its language and the Hebrew as the reader's verses are
    // spoken.
    final label = StringBuffer('$reference. ');
    final languages = <StringAttribute>[];
    for (final (i, s) in hit.snippets.indexed) {
      final hebrew = s.layer != TextLayer.english;
      // A verse spoken whole already ends in a full stop.
      if (i > 0) label.write(label.toString().endsWith('.') ? ' ' : '. ');
      if (s.layer == TextLayer.onkelos) label.write('${l.targumLabel}: ');
      if (s.layer == TextLayer.english) label.write('${l.translationLabel}: ');
      // From the pointed words, whether or not the vowels are shown.
      final text = hebrew ? _spoken(s.spoken, settings) : s.snippet.text;
      languages.add(LocaleStringAttribute(
        range: TextRange(start: label.length, end: label.length + text.length),
        locale: Locale(hebrew ? 'he' : 'en'),
      ));
      label.write(text);
    }

    return Semantics(
      container: true,
      button: true,
      attributedLabel: AttributedString(label.toString(), attributes: languages),
      child: SeferInkWell(
        onTap: () => _open(context, ref),
        borderRadius: PaperGroup.rowCorners(context),
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          heading,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        for (final s in hit.snippets)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _SnippetText(snippet: s, settings: settings),
                          ),
                      ],
                    ),
                  ),
                  const Gap(12),
                  Icon(Icons.chevron_right, size: 20, color: scheme.outline),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _spoken(String text, AppSettings s) => switch (s.screenReaderText) {
        ScreenReaderText.simplified => HebrewSpeech.spoken(text, divineName: s.divineName),
        ScreenReaderText.consonants => HebrewSpeech.spoken(text, keepNikud: false, divineName: s.divineName),
        ScreenReaderText.allMarks => text,
      };
}

/// A layer of a verse found, with each match in bold on a gold wash, the way
/// a reader marks a page. The Hebrew is set in the reader's scripture font,
/// the Targum smaller and quieter under it, as in the reader.
class _SnippetText extends StatelessWidget {
  const _SnippetText({required this.snippet, required this.settings});

  final LayerSnippet snippet;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hebrew = snippet.layer != TextLayer.english;
    final targum = snippet.layer == TextLayer.onkelos;
    final base = hebrew
        ? TextStyle(
            fontFamily: settings.scriptureFont.family,
            fontFamilyFallback: const ['NotoSerifHebrew', 'NotoSansHebrew'],
            fontSize: targum ? 18 : 20,
            height: 1.7,
            leadingDistribution: TextLeadingDistribution.even,
            letterSpacing: 0,
            fontWeight: FontWeight.w400,
            color: targum ? scheme.onSurfaceVariant : scheme.onSurface,
          )
        : theme.textTheme.bodyLarge!.copyWith(color: scheme.onSurface);
    final match = TextStyle(fontWeight: FontWeight.w700, color: scheme.onSecondaryContainer);
    final s = snippet.snippet;
    // The ellipses never stand on a line of their own.
    final lead = s.clippedStart ? '…\u00A0' : '';
    final spans = <TextSpan>[if (lead.isNotEmpty) TextSpan(text: lead)];
    final marks = <TextRange>[];
    var at = 0;
    for (final m in s.matches) {
      if (m.start > at) spans.add(TextSpan(text: s.text.substring(at, m.start)));
      spans.add(TextSpan(text: s.text.substring(m.start, m.end), style: match));
      marks.add(TextRange(start: lead.length + m.start, end: lead.length + m.end));
      at = m.end;
    }
    if (at < s.text.length) spans.add(TextSpan(text: s.text.substring(at)));
    if (s.clippedEnd) spans.add(const TextSpan(text: '\u00A0…'));
    // With bold text every letter is bold, and in high contrast the wash is
    // close to the paper: each mark is outlined too.
    final outlined = MediaQuery.boldTextOf(context) || SeferColors.of(context).isHighContrast;
    return MarkedText(
      TextSpan(children: spans, style: base),
      marks: marks,
      color: scheme.secondaryContainer,
      outline: outlined ? scheme.onSecondaryContainer : null,
      textDirection: hebrew ? TextDirection.rtl : TextDirection.ltr,
      locale: Locale(hebrew ? 'he' : 'en'),
    );
  }
}
