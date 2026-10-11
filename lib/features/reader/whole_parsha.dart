import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/text/hebrew_text.dart';
import '../../data/models/verse_ref.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import 'scripture_text.dart' show VerseGroup;

/// The verses of a parsha's seven aliyot, in order, for the full text of the
/// whole parsha: each verse has one index among them all.
class ParshaVerses {
  ParshaVerses(this.aliyot)
      : verses = [for (final a in aliyot) ...a],
        starts = _starts(aliyot);

  /// Each aliyah's verses.
  final List<List<VerseRef>> aliyot;

  /// Every verse of the parsha.
  final List<VerseRef> verses;

  /// The index among [verses] of each aliyah's first verse.
  final List<int> starts;

  static List<int> _starts(List<List<VerseRef>> aliyot) {
    final starts = <int>[];
    var at = 0;
    for (final a in aliyot) {
      starts.add(at);
      at += a.length;
    }
    return starts;
  }

  /// The aliyah verse [index] of [verses] belongs to.
  int aliyahOf(int index) {
    var a = 0;
    while (a + 1 < starts.length && starts[a + 1] <= index) {
      a++;
    }
    return a;
  }
}

/// Where the top of [box] is, on a page scrolled to [position]: how far
/// below the top of what shows of the text, beneath any heading held there
/// (an aliyah's, in the whole parsha), whose height the viewport reckons in
/// revealing what lies beneath it. Negative where it is scrolled out of view
/// at the top, or held under such a heading.
double topInView(RenderBox box, ScrollPosition position) {
  final viewport = RenderAbstractViewport.maybeOf(box);
  if (viewport == null || !position.hasPixels) return 0;
  return viewport.getOffsetToReveal(box, 0).offset - position.pixels;
}

/// The head of an aliyah in the full text of the whole parsha, which stays
/// at the top of the text while its aliyah is read: the aliyah's Hebrew
/// ordinal in gold, its name and its verses, and a check once it is read.
/// On the page's own colour, so the text passes under it, and ruled off from
/// it by a hairline while it does ([held]), as the app bar is. One heading
/// to a screen reader: "Revi'i, aliyah 4 of 7, Genesis 3:22–4:18, read".
class AliyahHeader extends StatelessWidget {
  const AliyahHeader({
    super.key,
    required this.aliyah,
    required this.range,
    required this.done,
    required this.width,
    required this.padding,
    this.held = false,
  });

  final int aliyah;

  /// Its verses: "Genesis 3:22–4:18".
  final String range;

  /// Whether the aliyah is read.
  final bool done;

  /// The text's measure, which the heading keeps to.
  final double width;

  /// The page's side padding, around [width].
  final double padding;

  /// Whether it is held at the top of the text, which passes beneath it.
  final bool held;

  /// Above and below its line.
  static const double _vertical = 10;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sefer = SeferColors.of(context);
    final name = Names(context).aliyah(aliyah);
    final label = [l.aliyahTabLabel(name, aliyah + 1), range, if (done) l.tabRead].join(', ');
    final scaler = MediaQuery.textScalerOf(context);
    return DecoratedBox(
      // The rule keeps its width when it isn't drawn, so that nothing moves
      // as it comes and goes.
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(
            color: sefer.hairline,
            width: sefer.hairlineWidth,
            style: held ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width + 2 * padding),
          child: Padding(
            // As the verses' text is inset within its block.
            padding: EdgeInsets.symmetric(horizontal: padding + VerseGroup.padding.left, vertical: _vertical),
            child: Semantics(
              header: true,
              headingLevel: 2,
              label: label,
              child: ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      HebrewText.gematria(aliyah + 1, punctuate: false),
                      style: SeferType.of(context).ordinal.copyWith(color: scheme.secondary),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(width: 12),
                    // The name and the verses wrap, rather than squeeze, at a
                    // large text size.
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 12,
                        children: [
                          Text(name, style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurface)),
                          Text(
                            range,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (done) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.check, size: scaler.clamp(maxScaleFactor: 1.3).scale(20), color: scheme.primary),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds an aliyah's heading in the whole parsha's text with whether it is
/// held at the top: whether [scroll] has taken the text past where the
/// aliyah begins ([start], a scroll offset, null until it is laid out).
class HeldHeading extends StatefulWidget {
  const HeldHeading({super.key, required this.scroll, required this.start, required this.builder});

  final ScrollController scroll;
  final double? Function() start;
  final Widget Function(BuildContext context, bool held) builder;

  @override
  State<HeldHeading> createState() => _HeldHeadingState();
}

class _HeldHeadingState extends State<HeldHeading> {
  bool _held = false;

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_check);
    // Once the text is laid out: it may open scrolled.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didUpdateWidget(HeldHeading old) {
    super.didUpdateWidget(old);
    if (old.scroll != widget.scroll) {
      old.scroll.removeListener(_check);
      widget.scroll.addListener(_check);
    }
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted) return;
    final start = widget.start();
    final held = start != null && widget.scroll.hasClients && widget.scroll.position.pixels > start + 0.5;
    if (held != _held) setState(() => _held = held);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _held);
}
