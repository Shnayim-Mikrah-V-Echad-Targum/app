import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/text/hebrew_text.dart';
import '../../data/models/scripture.dart';
import '../../data/models/verse_ref.dart';
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/paper_group.dart';
import '../settings/app_settings.dart';
import 'scripture_text.dart';

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
/// answers, which begins with the verse ([ComposeScreen.verse]).
String askAboutVersePath(BookVerse verse) =>
    Uri(path: '/community/new', queryParameters: {'forum': 'questions', 'verse': '$verse'}).toString();

/// Opens the options of [verse] (copy, share, or ask about it) from
/// [context], over the whole window, the navigation too.
Future<void> showVerseActions(BuildContext context, ChosenVerse verse) => showAppSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _VerseActionsSheet(verse: verse, page: context),
    );

/// Opens the options of the verse in view on [context]'s page, as Shift+F10
/// or the menu key does where no verse is chosen: the first whose top is in
/// view, or else the one the view is within. Returns whether there was one.
bool openVerseOptionsInView(BuildContext context) {
  final verses = <(Rect, Rect, VoidCallback)>[];
  void visit(Element element) {
    final widget = element.widget;
    if (widget is ScriptureVerse && widget.onLongPress != null) {
      final box = element.renderObject;
      final scrollable = element.findAncestorStateOfType<ScrollableState>()?.context.findRenderObject();
      if (box is RenderBox && box.hasSize && scrollable is RenderBox && scrollable.hasSize) {
        verses.add((
          box.localToGlobal(Offset.zero) & box.size,
          scrollable.localToGlobal(Offset.zero) & scrollable.size,
          widget.onLongPress!,
        ));
      }
      return;
    }
    element.visitChildElements(visit);
  }

  context.visitChildElements(visit);
  final open = verses.where((v) => v.$1.top >= v.$2.top - 1 && v.$1.top < v.$2.bottom).firstOrNull ??
      verses.where((v) => v.$1.top < v.$2.top && v.$1.bottom > v.$2.top).lastOrNull;
  open?.$3();
  return open != null;
}

/// What can be done with a verse: copy it, share it, or ask about it in the
/// community. The sheet is headed by the verse's reference, over the verse
/// as it will go, and offers each in one paper group (DESIGN_SYSTEM.md
/// §6.27).
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
  /// awaited before it.
  Future<void> _shareVerse() async {
    if (_sharing) return;
    _sharing = true;
    final l = context.l10n;
    final text = _copy;
    final row = _shareRow.currentContext?.findRenderObject();
    final origin = row is RenderBox ? row.localToGlobal(Offset.zero) & row.size : null;
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: _reference, sharePositionOrigin: origin));
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
    final path = askAboutVersePath(widget.verse.at);
    Navigator.pop(context);
    if (page.mounted) openTabPage(page, path);
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
/// ([openVerseOptionsInView]). The reader binds the keys among its own.
class VerseOptionsKeys extends StatelessWidget {
  const VerseOptionsKeys({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    void open() => openVerseOptionsInView(context);
    return OwnContextMenu(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f10, shift: true, includeRepeats: false): open,
          const SingleActivator(LogicalKeyboardKey.contextMenu, includeRepeats: false): open,
        },
        // The page's own focus, which the keys reach before anything on it
        // has been tapped or tabbed to; Tab goes on from the top.
        child: Focus(autofocus: true, skipTraversal: true, child: child),
      ),
    );
  }
}

/// While shown on the web, a right-click on a verse opens its options, and
/// the browser's own menu, which would open over them, stays away.
class OwnContextMenu extends StatefulWidget {
  const OwnContextMenu({super.key, required this.child});

  final Widget child;

  @override
  State<OwnContextMenu> createState() => _OwnContextMenuState();
}

class _OwnContextMenuState extends State<OwnContextMenu> {
  // Pages that want it off: the browser's menu comes back with the last.
  static var _shown = 0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && _shown++ == 0) unawaited(BrowserContextMenu.disableContextMenu().catchError((_) {}));
  }

  @override
  void dispose() {
    if (kIsWeb && --_shown == 0) unawaited(BrowserContextMenu.enableContextMenu().catchError((_) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
