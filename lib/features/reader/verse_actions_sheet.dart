import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/text/hebrew_text.dart';
import '../../data/models/parsha.dart' show kTorahBooks;
import '../../data/models/scripture.dart';
import '../../data/models/verse_ref.dart';
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/paper_group.dart';
import '../notes/note_dialog.dart';
import '../settings/app_settings.dart';
import 'scripture_text.dart';
import 'whole_parsha.dart' show topInView;

/// A verse whose options are offered (DESIGN.md §3): where it is, and its
/// text in each layer the reader shows with it.
class ChosenVerse {
  const ChosenVerse({required this.at, required this.hebrew, this.targum, this.english});

  final BookVerse at;
  final Verse hebrew;

  /// Targum Onkelos and the translation, where the reader shows them.
  final Verse? targum;
  final String? english;
}

/// [verse] as text that leaves the app, copied, shared or quoted in a post:
/// as the reader shows it, with the vowels and cantillation it shows, the
/// qere, and the ketiv where it is shown, but without notes; and with the
/// Divine Name written ה׳ unless the reader has turned that off. Unlike
/// [displayHebrew], it adds no word joiners or no-break spaces, which would
/// travel with the text.
String verseText(Verse verse, AppSettings s) {
  String shown(String text) => HebrewText.forDisplay(text, nikud: s.showNikud, teamim: s.showTeamim);
  final b = StringBuffer();
  for (final segment in verse.segments) {
    switch (segment) {
      case PlainText(:final text) || SizedLetters(:final text):
        b.write(shown(text));
      case KetivQere(:final ketiv, :final qere):
        if (qere.isNotEmpty) b.write(shown(qere));
        if (s.showKetiv && ketiv.isNotEmpty) b.write(qere.isEmpty ? '[$ketiv]' : ' ($ketiv)');
      case AlternateReading(:final text):
        b.write(' (${shown(text)}) ');
      case PisqaGap():
        b.write(' ');
      case TextNote():
        break;
    }
  }
  final text = b.toString().replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return s.copyDivineNameAsHashem ? HebrewText.replaceDivineName(text) : text;
}

/// [verse] as it is copied or shared: its Hebrew, then its Targum and its
/// translation where the reader shows them, each on a line of its own, and
/// last its [reference] ("— Genesis 3:22").
String verseCopy(ChosenVerse verse, AppSettings s, {required String reference}) => [
      verseText(verse.hebrew, s),
      if (verse.targum case final targum?) verseText(targum, s),
      if (verse.english case final english? when english.isNotEmpty) english,
      '— $reference',
    ].join('\n');

/// [verse] quoted at the head of a question about it: "> " and its Hebrew,
/// then a blank line for the question.
///
/// A question asked from the English UI is likely to be written in English,
/// so with [leftToRight] the quote begins with a left-to-right mark. The post
/// then runs from the left, as its question will, rather than taking its
/// direction from the Hebrew quoted first (autoDirection).
String verseQuote(Verse verse, AppSettings s, {required bool leftToRight}) =>
    '${leftToRight ? '\u200E' : ''}> ${verseText(verse, s)}\n\n';

/// Where "Ask about this verse" leads: a new discussion in Questions &
/// answers, which begins with the verse ([ComposeScreen.verse]). Within
/// Community, or [overTabs], over the page asked from (the reader), which
/// closing it or posting goes back to.
String askAboutVersePath(BookVerse verse, {bool overTabs = false}) => overTabs
    ? Uri(path: '/ask', queryParameters: {'verse': '$verse'}).toString()
    : Uri(path: '/community/new', queryParameters: {'forum': 'questions', 'verse': '$verse'}).toString();

/// Opens the question on [verse] from [page]: from a page within a tab (the
/// haftarah of Today's week, say), in Community, whose back button returns
/// to it; from one shown over the tabs (the reader, a week's notes), over it
/// too, so that the reader keeps its place, its mode and its scroll.
void askAboutVerse(BuildContext page, BookVerse verse) =>
    page.push(askAboutVersePath(verse, overTabs: StatefulNavigationShell.maybeOf(page) == null));

/// Opens the options of [verse] (bookmark it or write a note on it, where it
/// is a verse of the Torah; copy, share, or ask about it) from [context],
/// over the whole window, the navigation too.
Future<void> showVerseActions(BuildContext context, ChosenVerse verse) => showAppSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _VerseActionsSheet(verse: verse, page: context),
    );

/// Opens the options of the verse in view on [context]'s page, as Shift+F10
/// or the menu key does where no verse is chosen: the first whose top is in
/// view, below any heading held at the top of the text ([topInView]), as
/// Listen starts there; or else the one the view is within. Returns whether
/// there was one.
bool openVerseOptionsInView(BuildContext context) {
  // Each verse, in the page's order: where its top is in what shows of the
  // view, its height, and how tall that view is. A Targum beneath its verse
  // is the verse's, which begins above it.
  final verses = <({double top, double height, double view, VoidCallback open})>[];
  void visit(Element element) {
    final widget = element.widget;
    if (widget is ScriptureVerse && widget.onLongPress != null && !widget.secondary) {
      final box = element.renderObject;
      final position = Scrollable.maybeOf(element)?.position;
      if (box is RenderBox && box.hasSize) {
        verses.add((
          top: position == null ? 0 : topInView(box, position),
          height: box.size.height,
          view: position != null && position.hasViewportDimension ? position.viewportDimension : double.infinity,
          open: widget.onLongPress!,
        ));
      }
      return;
    }
    element.visitChildElements(visit);
  }

  context.visitChildElements(visit);
  final open = verses.where((v) => v.top >= -1 && v.top < v.view).firstOrNull ??
      verses.where((v) => v.top < 0 && v.top + v.height > 0).lastOrNull;
  open?.open();
  return open != null;
}

/// What can be done with a verse: bookmark it and write a note on it, in a
/// paper group of their own for a verse of the Torah (a verse of the
/// haftarah has neither, as the list of them opens the Torah's verses in
/// the reader); then copy it, share it, or ask about it in the community.
/// The sheet is headed by the verse's reference, over the verse as it will
/// go (DESIGN_SYSTEM.md §6.27).
class _VerseActionsSheet extends ConsumerStatefulWidget {
  const _VerseActionsSheet({required this.verse, required this.page});

  final ChosenVerse verse;

  /// The page the sheet was opened over, which says what became of a copy
  /// and opens the question.
  final BuildContext page;

  @override
  ConsumerState<_VerseActionsSheet> createState() => _VerseActionsSheetState();
}

class _VerseActionsSheetState extends ConsumerState<_VerseActionsSheet> {
  // Where the share sheet points from, on an iPad.
  final _shareRow = GlobalKey();
  bool _sharing = false;

  String get _reference {
    final at = widget.verse.at;
    return Names(context).reference(at.book, at.ref.chapter, at.ref.verse);
  }

  String get _copy => verseCopy(widget.verse, ref.read(settingsProvider), reference: _reference);

  /// Closes the sheet, and then says [message] on the page beneath.
  void _closeSaying(String message) {
    final page = widget.page;
    Navigator.pop(context);
    if (page.mounted) showStatus(page, message);
  }

  void _copyVerse() {
    unawaited(Clipboard.setData(ClipboardData(text: _copy)));
    _closeSaying(context.l10n.verseCopied);
  }

  /// Shares the verse while the sheet stays open beneath the share sheet,
  /// which points from its row; once it is done with, the sheet closes. A
  /// browser lets a page share only straight from a tap, so nothing is
  /// awaited before it. A browser without one fails rather than open an
  /// email in its place, and the verse is copied.
  Future<void> _shareVerse() async {
    if (_sharing) return;
    _sharing = true;
    final l = context.l10n;
    final text = _copy;
    final row = _shareRow.currentContext?.findRenderObject();
    final origin = row is RenderBox ? row.localToGlobal(Offset.zero) & row.size : null;
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: _reference, sharePositionOrigin: origin, mailToFallbackEnabled: false),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // Nothing here can share it: copied instead, as the page then says.
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) _closeSaying(l.shareCopiedInstead);
    } finally {
      _sharing = false;
    }
  }

  void _ask() {
    final page = widget.page;
    Navigator.pop(context);
    if (page.mounted) askAboutVerse(page, widget.verse.at);
  }

  /// Bookmarks the verse, or takes the bookmark away. The sheet stays, its
  /// switch showing the change.
  void _bookmark(bool bookmarked) => ref.read(annotationsProvider.notifier).setBookmark(widget.verse.at, bookmarked);

  /// Closes the sheet and opens the verse's note for writing over the page.
  void _note() {
    final page = widget.page;
    Navigator.pop(context);
    if (page.mounted) editVerseNote(page, widget.verse.at);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(settingsProvider);
    final padding = sheetPadding(context);
    final apple = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
    // The verse as search sets one (§6.25), in the scripture's font.
    final style = ScriptureStyles(context, s).style(ScriptureKind.mikra).copyWith(fontSize: 20, height: 1.7);
    final annotatable = kTorahBooks.contains(widget.verse.at.book);
    final marks = annotatable ? ref.watch(annotationsProvider)[widget.verse.at] : null;
    final bookmarked = marks?.bookmarked ?? false;
    final note = marks?.note;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(_reference),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Which verse it is, as it will go, set off as a quotation
                // is (§6.21) at the right, where the Hebrew begins. The
                // title has named it to screen readers already.
                ExcludeSemantics(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Container(
                      padding: const EdgeInsetsDirectional.only(start: Space.md),
                      decoration: BoxDecoration(
                        border: BorderDirectional(start: BorderSide(color: scheme.secondary, width: 2)),
                      ),
                      child: Text(
                        verseText(widget.verse.hebrew, s),
                        style: style,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        locale: const Locale('he'),
                      ),
                    ),
                  ),
                ),
                const Gap(Space.lg),
                if (annotatable) ...[
                  PaperGroup(
                    children: [
                      // One item for screen readers, a switch in its state,
                      // which the row's tap toggles.
                      PaperRow(
                        icon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
                        iconColor: bookmarked ? scheme.primary : null,
                        title: l.bookmarkVerse,
                        toggled: bookmarked,
                        chevron: false,
                        onTap: () => _bookmark(!bookmarked),
                        trailing: ExcludeFocus(
                          child: ExcludeSemantics(child: Switch(value: bookmarked, onChanged: _bookmark)),
                        ),
                      ),
                      PaperRow(
                        icon: note == null ? Icons.note_add_outlined : Icons.sticky_note_2_outlined,
                        title: note == null ? l.addNote : l.yourNote,
                        // In its own direction, whatever the interface's,
                        // and read in its own language.
                        subtitle: note == null ? null : '\u2068$note\u2069',
                        subtitleLocale: note == null ? null : noteLocale(context, note),
                        chevron: false,
                        onTap: _note,
                      ),
                    ],
                  ),
                  const Gap(Rhythm.cardGap),
                ],
                PaperGroup(
                  children: [
                    PaperRow(
                      icon: Icons.content_copy_outlined,
                      title: l.copyVerse,
                      chevron: false,
                      onTap: _copyVerse,
                    ),
                    PaperRow(
                      key: _shareRow,
                      icon: apple ? Icons.ios_share : Icons.share_outlined,
                      title: l.actionShare,
                      chevron: false,
                      onTap: _shareVerse,
                    ),
                    PaperRow(
                      icon: Icons.help_outline,
                      title: l.askAboutVerse,
                      subtitle: l.askAboutVerseDesc,
                      onTap: _ask,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A page of verses whose options open from the keyboard too: Shift+F10, or
/// the menu key, opens those of the first verse in view
/// ([openVerseOptionsInView]), as do the page's own [bindings]. The reader
/// binds the keys among its own.
class VerseOptionsKeys extends StatelessWidget {
  const VerseOptionsKeys({super.key, this.bindings = const {}, required this.child});

  final Map<ShortcutActivator, VoidCallback> bindings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    void open() => openVerseOptionsInView(context);
    return OwnContextMenu(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f10, shift: true, includeRepeats: false): open,
          const SingleActivator(LogicalKeyboardKey.contextMenu, includeRepeats: false): open,
          ...bindings,
        },
        // The page's own focus, which the keys reach before anything on it
        // has been tapped or tabbed to; Tab goes on from the top.
        child: Focus(autofocus: true, skipTraversal: true, child: child),
      ),
    );
  }
}

/// While its page is shown on the web, a right-click on a verse opens its
/// options, and the browser's own menu, which would open over them, stays
/// away. It comes back while another page covers this one, or another tab
/// is shown over this one's (which keeps it, out of sight), so that the
/// fields of a discussion opened from a verse have the browser's menu.
/// Sheets, menus and dialogs over the page leave it away.
class OwnContextMenu extends StatefulWidget {
  const OwnContextMenu({super.key, required this.child});

  final Widget child;

  /// Whether a page shown has the browser's menu kept away (on the web).
  @visibleForTesting
  static bool get browserMenuAway => _OwnContextMenuState._away > 0;

  @override
  State<OwnContextMenu> createState() => _OwnContextMenuState();
}

class _OwnContextMenuState extends State<OwnContextMenu> {
  // Pages shown that want it away: the browser's menu comes back once none
  // does.
  static var _away = 0;

  bool _keepsAway = false;

  /// Whether this page's tab is shown: a tab out of sight has its tickers
  /// off.
  bool _tabShown = true;

  /// Runs forward as another page comes over this one; only pages drive it,
  /// not sheets, menus or dialogs.
  Animation<double>? _covering;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabShown = TickerMode.valuesOf(context).enabled;
    final covering = ModalRoute.of(context)?.secondaryAnimation;
    if (covering != _covering) {
      _covering?.removeStatusListener(_coveringChanged);
      _covering = covering?..addStatusListener(_coveringChanged);
    }
    _update();
  }

  void _coveringChanged(AnimationStatus _) => _update();

  void _update() => _keepAway(_tabShown && (_covering?.isDismissed ?? true));

  void _keepAway(bool away) {
    if (away == _keepsAway) return;
    _keepsAway = away;
    if (away) {
      if (_away++ == 0 && kIsWeb) unawaited(BrowserContextMenu.disableContextMenu().catchError((_) {}));
    } else {
      if (--_away == 0 && kIsWeb) unawaited(BrowserContextMenu.enableContextMenu().catchError((_) {}));
    }
  }

  @override
  void dispose() {
    _covering?.removeStatusListener(_coveringChanged);
    _keepAway(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
