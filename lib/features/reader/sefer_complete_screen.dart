import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/text/hebrew_text.dart';
import '../../data/models/parsha.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';
import '../../ui/widgets/lang.dart';
import '../../ui/widgets/ornaments.dart';
import '../progress/domain/milestones.dart';
import '../settings/app_settings.dart';

/// The page shown once, as a whole book of the Torah is finished
/// (DESIGN_SYSTEM.md §6.23): "חֲזַק חֲזַק וְנִתְחַזֵּק", said as a book is
/// finished in synagogue, between two dividers, and a line on what was read.
/// It fades in, and stays until Continue.
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
  late final AnimationController _fade = AnimationController(vsync: this, duration: Motion.long);
  late final Animation<double> _opacity = CurvedAnimation(parent: _fade, curve: Motion.decelerate);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Under Reduce Motion it is simply there.
    if (Motion.of(context).reduced) {
      _fade.value = 1;
    } else {
      _fade.forward();
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  /// What was read after the Torah's two readings, as the settings say.
  String _second(AppSettings settings) {
    final l = context.l10n;
    return switch (settings.secondReading) {
      SecondReading.onkelos => l.passTargum,
      SecondReading.rashi || SecondReading.rashiEnglish => l.passRashi,
      SecondReading.onkelosAndRashi => l.secondBoth,
    };
  }

  @override
  Widget build(BuildContext context) {
    final sefer = parseSeferKey(widget.celebrationKey);
    // A link that names no book.
    if (sefer == null) return const NotFoundPage();
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final english = kTorahBooks[sefer.book];
    final book = Names(context).book(english);
    final verses = ref.watch(parshaRepositoryProvider).chapterLengths(english).fold(0, (a, b) => a + b);
    final display = SeferType.of(context).hebrewDisplay.copyWith(
          fontSize: 40,
          height: 56 / 40,
          color: scheme.primary,
          fontWeight: SeferColors.of(context).isHighContrast ? FontWeight.w700 : null,
        );

    return DocumentTitle(
      title: l.seferDoneTitle(book),
      child: Scaffold(
        body: SafeArea(
          child: FadeTransition(
            opacity: _opacity,
            alwaysIncludeSemantics: true,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: Gutter.of(context), vertical: Space.s40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SeferDivider(),
                      const Gap(Space.xxl),
                      Semantics(
                        header: true,
                        headingLevel: 1,
                        child: Lang(
                          const Locale('he'),
                          child: Text(
                            SeferCompleteScreen.chazak,
                            // Read from its letters, as screen readers read verses.
                            semanticsLabel: HebrewText.stripNikud(SeferCompleteScreen.chazak),
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            locale: const Locale('he'),
                            style: display,
                          ),
                        ),
                      ),
                      const Gap(Space.xxl),
                      const SeferDivider(),
                      const Gap(Space.xxl),
                      Text(
                        l.seferDoneBody(book, verses, _second(settings)),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const Gap(Space.s32),
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(160, 52)),
                        onPressed: () => context.canPop() ? context.pop() : context.go('/today'),
                        child: Text(l.actionContinue),
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
