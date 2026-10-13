import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/calendar/parsha_schedule.dart';
import '../../core/text/hebrew_text.dart';
import '../../data/models/parsha.dart';
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';
import '../../ui/widgets/lang.dart';
import '../../ui/widgets/lines.dart';
import '../../ui/widgets/ornaments.dart';
import '../progress/domain/milestones.dart';

/// The page shown once, as a whole book of the Torah is finished
/// (DESIGN_SYSTEM.md §6.23), set as a printed book's colophon: in a title
/// page's frame, "חֲזַק חֲזַק וְנִתְחַזֵּק", said as a book is finished in
/// synagogue, a divider, the book named complete, what was read, and the day
/// it was finished. Finishing Deuteronomy with the year's reading is the
/// Siyum HaTorah, which five lozenges mark, one for each book.
///
/// It fades in, its frame's rule draws around it, and it stays until
/// Continue. It offers nothing to share and counts no streak.
///
/// [celebrationKey] is the book's [seferKey], as the celebration listener
/// opens it ("sefer:5787:0").
class SeferCompleteScreen extends ConsumerStatefulWidget {
  const SeferCompleteScreen({super.key, required this.celebrationKey});

  final String celebrationKey;

  /// Untranslated in either language, as it is said.
  static const chazak = 'חֲזַק חֲזַק וְנִתְחַזֵּק';

  @override
  ConsumerState<SeferCompleteScreen> createState() => _SeferCompleteScreenState();
}

class _SeferCompleteScreenState extends ConsumerState<SeferCompleteScreen> with SingleTickerProviderStateMixin {
  // The moment (§8), once: the page fades in over Motion.long, then the
  // frame's gold-leaf rule draws around it over Motion.frame, and the
  // celebrate haptic comes as it closes.
  static final _fadeShare = Motion.long.inMilliseconds / (Motion.long + Motion.frame).inMilliseconds;
  late final AnimationController _moment = AnimationController(vsync: this, duration: Motion.long + Motion.frame);
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _moment, curve: Interval(0, _fadeShare, curve: Motion.decelerate));
  late final Animation<double> _rule =
      CurvedAnimation(parent: _moment, curve: Interval(_fadeShare, 1, curve: Motion.standard));
  bool _started = false;

  /// Whether the page gives the celebrate haptic: not where the finish that
  /// opened it was felt a moment before (a parsha completed in the full
  /// text, or its rings closed at once under Reduce Motion).
  bool _felt = true;

  /// [celebrationsPlayed] as the page opened.
  int _playedAtOpen = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _felt = !celebratedWithin(celebrateQuiet);
    _playedAtOpen = celebrationsPlayed;
    // Under Reduce Motion it is simply there, and the haptic comes at once.
    if (Motion.of(context).reduced) {
      _moment.value = 1;
      _celebrate();
    } else {
      _moment
        ..addStatusListener(_closed)
        ..forward();
    }
  }

  void _closed(AnimationStatus status) {
    if (status.isCompleted) _celebrate();
  }

  /// The book's completion felt, as the frame closes: once for one finish,
  /// so none where it has been felt already, as the page opened or since.
  void _celebrate() {
    if (_felt && celebrationsPlayed == _playedAtOpen) hapticCelebrate(ref);
  }

  @override
  void dispose() {
    _moment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sefer = parseSeferKey(widget.celebrationKey);
    // A link that names no book.
    if (sefer == null) return const NotFoundPage();
    final l = context.l10n;
    final names = Names(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final progress = ref.watch(progressProvider).weeks;
    final repo = ref.watch(parshaRepositoryProvider);
    int versesOf(String book) => repo.chapterLengths(book).fold(0, (a, b) => a + b);
    final english = kTorahBooks[sefer.book];
    final second = names.secondReading(settings.secondReading);
    // Deuteronomy, finished with the year's reading: the Siyum HaTorah.
    final siyum = sefer.book == 4 ? cycleSiyum(progress, sefer.cycleYear) : null;
    final finishedOn = seferCompletions(progress, sefer.cycleYear)[sefer.book];

    final title = switch (siyum) {
      null => l.seferDoneTitle(names.book(english)),
      Milestone(fromParsha: final from?) =>
        l.milestoneSiyumFrom(names.portion(repo.portion(PortionId(from)), ashkenazi: settings.ashkenaziNames)),
      _ => l.milestoneSiyum,
    };
    // The whole Torah, for a reader who read it all this year; a reader who
    // joined partway is told of the book they finished.
    final facts = siyum != null && siyum.fromParsha == null
        ? l.siyumBody(kTorahBooks.map(versesOf).fold(0, (a, b) => a + b), second, names.hebrewYear(sefer.cycleYear))
        : l.seferDoneFacts(versesOf(english), second);

    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= Breakpoints.medium;
    final display = SeferType.of(context).hebrewDisplay.copyWith(
          fontSize: wide ? 48 : 40,
          height: wide ? 64 / 48 : 56 / 40,
          color: scheme.primary,
          fontWeight: SeferColors.of(context).isHighContrast ? FontWeight.w700 : null,
        );

    final colophon = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The page's heading, in Hebrew whatever the interface: the heading
        // within the language, so that the node read out is both.
        Lang(
          const Locale('he'),
          child: Semantics(
            header: true,
            headingLevel: 1,
            // Its words whole, in the frame's narrow column at a very large
            // text size too.
            child: WholeWords(
              SeferCompleteScreen.chazak,
              // Read from its letters, as screen readers read verses.
              semanticsLabel: HebrewText.stripNikud(SeferCompleteScreen.chazak),
              textDirection: TextDirection.rtl,
              locale: const Locale('he'),
              style: display,
            ),
          ),
        ),
        const Gap(Space.lg),
        if (siyum != null) const _FiveBooks() else const SeferDivider(),
        const Gap(Space.lg),
        BalancedText(title, style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onSurface)),
        const Gap(Space.xs),
        BalancedText(facts, style: SeferType.of(context).marginalia, holdDashes: true),
        if (finishedOn != null) ...[
          const Gap(Space.sm),
          // Where it takes two lines, they break after the day, never inside
          // the date.
          DotLine(
            [l.seferDoneOn(names.weekday(finishedOn), names.hebrewDate(finishedOn))],
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    return DocumentTitle(
      title: title,
      child: Scaffold(
        body: SafeArea(
          child: FadeTransition(
            opacity: _opacity,
            alwaysIncludeSemantics: true,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: Gutter.of(context), vertical: Space.s40),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 560 : 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedBuilder(
                        animation: _rule,
                        builder: (context, child) => TitlePageFrame(
                          padding: width < Breakpoints.narrow
                              ? const EdgeInsets.fromLTRB(16, 28, 16, 24)
                              : const EdgeInsets.fromLTRB(24, 40, 24, 32),
                          drawProgress: _rule.value,
                          child: child!,
                        ),
                        child: colophon,
                      ),
                      const Gap(Space.s32),
                      Center(
                        child: FilledButton(
                          style: AppButtons.roomy(context, (24, 12, 6))
                              .copyWith(minimumSize: const WidgetStatePropertyAll(Size(200, 52))),
                          onPressed: () => context.canPop() ? context.pop() : context.go('/today'),
                          child: Text(l.actionContinue, textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Five lozenges, one for each book of the Torah, in a divider's place for
/// the Siyum HaTorah: 8 px gold leaf, 8 apart, as high as a divider.
class _FiveBooks extends StatelessWidget {
  const _FiveBooks();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: SeferDivider.height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var b = 0; b < kTorahBooks.length; b++) ...[
              if (b > 0) const SizedBox(width: Space.sm),
              const Lozenge(),
            ],
          ],
        ),
      );
}
