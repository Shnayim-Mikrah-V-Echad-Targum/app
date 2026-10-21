import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/fonts_change_scope.dart';
import '../../../ui/widgets/lang.dart';
import '../../../ui/widgets/lines.dart';
import '../../../ui/widgets/paper_group.dart';

/// One option in a [ChoiceGroup].
class Choice<T> {
  const Choice(this.value, this.title, {this.subtitle, this.semanticsLabel, this.sampleStyle, this.locale});
  final T value;
  final String title;
  final String? subtitle;

  /// What screen readers say for [title], where it would be read badly as
  /// written.
  final String? semanticsLabel;

  /// The language [title] is written in, where it is not the interface's
  /// (a language's own name), so that a screen reader reads it in its own
  /// voice.
  final Locale? locale;

  /// Sets [title] in a style of its own, as a sample of what the option
  /// looks like (a font's letters), which [subtitle] names. Screen readers
  /// read the name alone.
  final TextStyle? sampleStyle;
}

/// The heading of a setting, with its help under it (docs/DESIGN_SYSTEM.md
/// §9 Settings): at [level] 2 an eyebrow ([GroupHeader]), for a setting that
/// is a section of its own; at level 3 a subheading in titleMedium, for one
/// of several settings in a section.
///
/// [help] is bodyMedium in onSurfaceVariant, or with [helpIsSource], where it
/// cites its source, a [SourceNote]. The heading leaves the gap below it to
/// the setting's controls.
class SettingHeading extends StatelessWidget {
  const SettingHeading(this.title, {super.key, this.help, this.helpIsSource = false, this.source, this.level = 2})
      : assert(level == 2 || level == 3),
        assert(source == null || !helpIsSource, 'A source of its own, or the help as one');

  final String title;
  final String? help;
  final bool helpIsSource;

  /// The source the setting rests on, in a [SourceNote] before any [help]:
  /// the citation in the margin's voice, and advice as plain help.
  final String? source;
  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final help = this.help;
    final source = this.source;
    // In line with a group header's eyebrow, 4 in from the paper's edge.
    const inset = EdgeInsetsDirectional.symmetric(horizontal: 4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (level == 2)
          GroupHeader(title)
        else
          Padding(
            padding: inset,
            child: Semantics(
              header: true,
              headingLevel: level,
              child: Text(title, style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurface)),
            ),
          ),
        if (source != null)
          Padding(padding: EdgeInsets.only(top: level == 2 ? 0 : Space.sm), child: SourceNote(source)),
        if (help != null)
          if (helpIsSource)
            Padding(padding: EdgeInsets.only(top: level == 2 ? 0 : Space.sm), child: SourceNote(help))
          else
            Padding(
              padding: inset.add(EdgeInsets.only(top: source != null ? Space.sm : (level == 2 ? 0 : 2))),
              child: Text(help, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ),
        // A group header keeps 8 below itself.
        Gap(help != null || source != null ? Space.md : (level == 2 ? 0 : Space.sm)),
      ],
    );
  }
}

/// A note that cites its source, such as "(Shulchan Aruch OC 285:2)", set as
/// a margin note is in a chumash: marginalia on surfaceContainerLow, radius
/// 12, padding 12, and outlined in high contrast, where the wash is the page.
class SourceNote extends StatelessWidget {
  const SourceNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: SeferColors.of(context).isHighContrast ? Border.all(color: scheme.outline, width: 2) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Text(text, style: SeferType.of(context).marginalia),
      ),
    );
  }
}

/// A labeled group of options, one of which is chosen: radio rows on one
/// sheet of paper (§6.3), 56 high or 72 with a subtitle, or with [segmented]
/// a segmented control, for two or three short options. The radios are in a
/// RadioGroup, so assistive technology announces "1 of 3" and arrow keys
/// move between them.
///
/// Its heading is a [SettingHeading] of [headingLevel], with [help] under
/// it, through a [SourceNote] where [helpIsSource], or after the [source]'s
/// note. [margin] surrounds the
/// whole: on a page still padded for list tiles (PageBody.tilePadding), 16
/// at the sides brings the paper to the gutters.
///
/// A [prominent] group is the one question of a page, as each step of
/// onboarding asks (§9 Onboarding): its heading is the question itself, in
/// headlineSmall, and each option a radio card of its own, at least 72 high
/// and 8 apart. The chosen card is washed in primaryContainer within a 2 px
/// primary border; the others are paper within a 1 px outline.
class ChoiceGroup<T> extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.title,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.help,
    this.helpIsSource = false,
    this.source,
    this.segmented = false,
    this.prominent = false,
    this.headingLevel = 2,
    this.margin = EdgeInsets.zero,
  })  : assert(!(segmented && prominent), 'Segments or cards, not both'),
        // A question asked on its own page has plain help, never a source.
        assert(!(prominent && (helpIsSource || source != null)), 'A prominent question takes plain help');

  final String title;
  final T value;
  final List<Choice<T>> choices;
  final ValueChanged<T> onChanged;
  final String? help;
  final bool helpIsSource;

  /// As [SettingHeading.source].
  final String? source;
  final bool segmented;
  final bool prominent;
  final int headingLevel;
  final EdgeInsetsGeometry margin;

  /// The space between two radio cards of a [prominent] group.
  static const cardGap = Space.sm;

  @override
  Widget build(BuildContext context) {
    final Widget options = segmented
        ? _Segments<T>(value: value, choices: choices, onChanged: onChanged)
        : RadioGroup<T>(
            groupValue: value,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            child: prominent
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, c) in choices.indexed) ...[
                        if (i > 0) const Gap(cardGap),
                        _RadioRow<T>(choice: c, card: true, selected: c.value == value),
                      ],
                    ],
                  )
                : PaperGroup(
                    ruleInset: _RadioRow.textStart,
                    children: [for (final c in choices) _RadioRow<T>(choice: c)],
                  ),
          );
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (prominent)
            _Question(title, help: help, level: headingLevel)
          else
            SettingHeading(title, help: help, helpIsSource: helpIsSource, source: source, level: headingLevel),
          options,
        ],
      ),
    );
  }
}

/// Opens a sheet of [choices] under [title], over the whole window, the
/// navigation too: radio rows on one sheet of paper, as a [ChoiceGroup]'s,
/// with [value] chosen, for a setting whose row shows its value. [onChanged]
/// is given each choice as it is made. A tap, or Space or Enter, chooses and
/// closes the sheet, on the choice already made too; the arrow keys move the
/// choice from row to row, and leave the sheet open for the next. [T] may be
/// nullable, for a choice of none (a default).
Future<void> showChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required T value,
  required List<Choice<T>> choices,
  required ValueChanged<T> onChanged,
}) {
  // The rows are radios of the choices' places, so that a null from the
  // group says only that the chosen row was activated again (its radio is
  // toggleable), never that a choice of none was made.
  var chosen = choices.indexWhere((c) => c.value == value);
  return showAppSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(title),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: sheetPadding(context)),
              child: StatefulBuilder(
                builder: (context, setState) => RadioGroup<int>(
                  groupValue: chosen,
                  onChanged: (i) {
                    // A choice made, by a tap, Space or Enter on another row,
                    // or by an arrow key, which leaves the sheet open; or,
                    // null, the chosen row tapped, or Space or Enter on it,
                    // which confirms it.
                    if (i != null) {
                      setState(() => chosen = i);
                      onChanged(choices[i].value);
                      if (HardwareKeyboard.instance.logicalKeysPressed.any(_arrowKeys.contains)) return;
                    }
                    Navigator.pop(context);
                  },
                  child: PaperGroup(
                    ruleInset: _RadioRow.textStart,
                    children: [
                      for (final (i, c) in choices.indexed)
                        _RadioRow<int>(
                          choice: Choice(
                            i,
                            c.title,
                            subtitle: c.subtitle,
                            semanticsLabel: c.semanticsLabel,
                            sampleStyle: c.sampleStyle,
                            locale: c.locale,
                          ),
                          toggleable: true,
                          balanced: true,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The keys that move a radio group's choice from row to row.
final _arrowKeys = {
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
};

/// The heading of a [ChoiceGroup.prominent]: the question in headlineSmall,
/// and any help under it in bodyMedium, inset 4 as a group header's eyebrow
/// is, and 16 above the cards.
class _Question extends StatelessWidget {
  const _Question(this.title, {this.help, required this.level});

  final String title;
  final String? help;
  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final help = this.help;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, 0, Space.xs, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            headingLevel: level,
            child: Text(title, style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onSurface)),
          ),
          if (help != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(help, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

/// A [ChoiceGroup]'s options as a segmented control across the column, each
/// label in two lines at most, with no word broken. The selected segment
/// always bears the check, its non-colour cue (§6.8), and every other label
/// keeps the check's room beside it, so that each is set as narrow as the
/// selected one and nothing moves as the choice changes. Where the labels
/// don't fit so (large text, a narrow phone), the segments stand one under
/// another, each the column's width.
class _Segments<T> extends StatelessWidget {
  const _Segments({required this.value, required this.choices, required this.onChanged});

  final T value;
  final List<Choice<T>> choices;
  final ValueChanged<T> onChanged;

  /// A segment's padding (12 at each side), its borders and a little to
  /// spare; and the room the check takes in the selected one, which every
  /// label keeps: the check (18), the gap after it (8), and the 4 more at
  /// the end that a button with an icon pads itself by.
  static const _padding = 24.0 + 2 + 4;
  static const _check = 18.0 + 8 + 4;

  /// Whether every label fits beside the check in a segment [room] wide.
  bool _fit(BuildContext context, double room) {
    final width = room - _check;
    if (width <= 0) return false;
    // Bold, as the selected segment sets it.
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700);
    final painter = TextPainter(textDirection: Directionality.of(context), textScaler: MediaQuery.textScalerOf(context));
    try {
      return choices.every((c) {
        painter
          ..text = TextSpan(text: c.title, style: style)
          ..layout(maxWidth: width);
        if (painter.computeLineMetrics().length > 2) return false;
        return c.title.split(RegExp(r'\s')).every((word) {
          painter
            ..text = TextSpan(text: word, style: style)
            ..layout();
          return painter.width <= width;
        });
      });
    } finally {
      painter.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Measured as it builds: again when a font loaded on demand arrives.
    FontsChangeScope.watch(context);
    return LayoutBuilder(builder: (context, constraints) {
      final across = _fit(context, constraints.maxWidth / choices.length - _padding);
      return SizedBox(
        width: double.infinity,
        child: SegmentedButton<T>(
          // Built anew as it turns, since a SegmentedButton keeps whether it
          // was expanded from when it was first built.
          key: ValueKey(across),
          segments: [
            for (final c in choices)
              ButtonSegment<T>(
                value: c.value,
                label: Padding(
                  // The check's room, kept by the labels without it, half on
                  // either side so that they stay centred.
                  padding: EdgeInsets.symmetric(horizontal: across && c.value != value ? _check / 2 : 0),
                  child: Text(c.title, semanticsLabel: c.semanticsLabel, textAlign: TextAlign.center),
                ),
              ),
          ],
          selected: {value},
          onSelectionChanged: (selected) => onChanged(selected.single),
          showSelectedIcon: true,
          // Across, the segments share the width; stacked, each takes it.
          expandedInsets: across ? EdgeInsets.zero : null,
          direction: across ? Axis.horizontal : Axis.vertical,
        ),
      );
    });
  }
}

/// One option of a [ChoiceGroup], as a row of its paper: a radio, then the
/// title and subtitle where a [PaperRow]'s text starts. Underneath it is a
/// RadioListTile, a member of the group's RadioGroup; focused from the
/// keyboard it is ringed as a paper row is (§6.1), rather than washed.
///
/// As a [card], it is a sheet of its own (see [ChoiceGroup.prominent]),
/// marked as [selected] by its wash and border as well as its radio.
class _RadioRow<T> extends StatefulWidget {
  const _RadioRow({
    super.key,
    required this.choice,
    this.card = false,
    this.selected = false,
    this.toggleable = false,
    this.balanced = false,
  });

  final Choice<T> choice;
  final bool card;
  final bool selected;

  /// Whether the title's lines are balanced, so that one wrapped by large
  /// text leaves no word alone on its last ("15 minutes / before sunset").
  final bool balanced;

  /// Whether activating the row already chosen tells the group, with null,
  /// rather than doing nothing (see [RadioListTile.toggleable]).
  final bool toggleable;

  /// Where the text starts, as in a [PaperRow] with an icon: the radio's
  /// circle (20 in a 40 box) at 16, as an icon is.
  static const textStart = PaperGroup.iconInset;
  static const _radioBox = 40.0;
  static const _start = PaperGroup.plainInset - 10;

  static const _cardCorners = BorderRadius.all(Radius.circular(12));
  static const _cardMinHeight = 72.0;

  @override
  State<_RadioRow<T>> createState() => _RadioRowState<T>();
}

class _RadioRowState<T> extends State<_RadioRow<T>> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_highlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_highlightModeChanged);
    super.dispose();
  }

  // A tap after tabbing hides the ring; a key press brings it back.
  void _highlightModeChanged(FocusHighlightMode mode) {
    if (_focused) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sefer = SeferColors.of(context);
    final card = widget.card;
    final corners = card ? _RadioRow._cardCorners : PaperGroup.rowCorners(context);
    final choice = widget.choice;
    final ring = _focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    Widget title = switch (choice.sampleStyle) {
      // In the list tile's own title style, which it measures in.
      null when widget.balanced && choice.semanticsLabel == null =>
        BalancedText(choice.title, style: theme.textTheme.bodyLarge, textAlign: TextAlign.start),
      null => Text(choice.title, semanticsLabel: choice.semanticsLabel),
      final sample => ExcludeSemantics(child: Text(choice.title, style: sample)),
    };
    if (choice.locale case final locale?) title = Lang(locale, child: title);
    Widget tile = Theme(
      // The ring marks focus; the tile's wash as well would read as a
      // second selection.
      data: theme.copyWith(focusColor: Colors.transparent),
      child: RadioListTile<T>(
        value: choice.value,
        toggleable: widget.toggleable,
        title: title,
        subtitle: choice.subtitle == null ? null : Text(choice.subtitle!),
        // The ink keeps to the paper's corners.
        shape: RoundedRectangleBorder(borderRadius: corners),
        minTileHeight: card ? _RadioRow._cardMinHeight : null,
        contentPadding: const EdgeInsetsDirectional.only(start: _RadioRow._start, end: 12),
        horizontalTitleGap: _RadioRow.textStart - _RadioRow._start - _RadioRow._radioBox,
        onFocusChange: (focused) => setState(() => _focused = focused),
      ),
    );
    if (card) {
      final selected = widget.selected;
      tile = Material(
        // The tile's ink is drawn on this sheet, over its wash. High contrast,
        // whose wash barely shows on the page, borders the chosen card the
        // more heavily.
        color: selected ? scheme.primaryContainer : sefer.paper,
        animationDuration: Motion.of(context).d(Motion.short),
        shape: RoundedRectangleBorder(
          borderRadius: corners,
          side: selected
              ? BorderSide(color: scheme.primary, width: sefer.isHighContrast ? 3 : 2)
              : BorderSide(color: scheme.outline, width: sefer.isHighContrast ? 2 : 1),
        ),
        child: tile,
      );
    }
    return DecoratedBox(
      // Always present, so that showing the ring never rebuilds the tile
      // (and drops its focus).
      position: DecorationPosition.foreground,
      decoration: switch ((ring, card)) {
        (false, _) => const BoxDecoration(),
        // Clear of the card's own border, which may be primary too (§6.1).
        (true, true) => ShapeDecoration(
            shape: FocusRingBorder(borderRadius: corners, ring: sefer.focus, gap: sefer.focusGap),
          ),
        (true, false) => ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: corners,
              side: BorderSide(color: sefer.focus, width: 3, strokeAlign: BorderSide.strokeAlignOutside),
            ),
          ),
      },
      child: tile,
    );
  }
}

/// A slider with a visible, spoken value and +/- buttons for users who
/// can't drag precisely. Assistive technology reads the slider by its
/// setting and value ("Reading size, 100%"), and each button by what it does.
///
/// Its value ends the title's line, or goes under the title where the two
/// don't fit side by side (§6.8): decided alike for every slider of a
/// [group], and whatever the value is, so that none of them lays out apart
/// from the rest, nor changes its layout as its value moves.
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    required this.format,
    this.group = const [],
  });

  final String title;

  /// The titles of the sliders shown with this one, as on the same paper,
  /// which set their values beside their titles or under them alike.
  final List<String> group;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final divisions = ((max - min) / step).round();
    double snap(double v) => (min + ((v - min) / step).round() * step).clamp(min, max);
    // In line with the list tiles around it: 16 on a settings page, and a
    // sheet's own inset in a sheet (showAppSheet).
    final inset = ListTileTheme.of(context).contentPadding?.resolve(Directionality.of(context)) ??
        const EdgeInsets.symmetric(horizontal: 16);
    return Padding(
      padding: EdgeInsets.fromLTRB(inset.left, 4, inset.right, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The slider says all of this itself.
          ExcludeSemantics(
            child: _SliderHead(
              title: title,
              value: format(value),
              // Every value it may show: the widest needn't be at an end of
              // the range ("Normal" at the speech rate's middle).
              values: [for (var i = 0; i <= divisions; i++) format(snap(min + i * step))],
              group: group,
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: l.decreaseSetting(title),
                icon: const Icon(Icons.remove),
                onPressed: value > min ? () => onChanged(snap(value - step)) : null,
              ),
              Expanded(
                // In an overlay of its own, which its value indicator goes
                // in: in the app's, that indicator's semantics node, sent as
                // the sheet holding the slider opens, isn't yet under any
                // other, and a desktop's accessibility bridge (Windows')
                // refuses the update, and every one after it.
                child: Overlay.wrap(
                  alwaysSizeToContent: true,
                  clipBehavior: Clip.none,
                  // One node, read as "Reading size, 100%". No value
                  // indicator: the value already shows above.
                  child: MergeSemantics(
                    child: Semantics(
                      label: title,
                      child: Slider(
                        value: value.clamp(min, max),
                        min: min,
                        max: max,
                        divisions: divisions,
                        semanticFormatterCallback: format,
                        onChanged: (v) => onChanged(snap(v)),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: l.increaseSetting(title),
                icon: const Icon(Icons.add),
                onPressed: value < max ? () => onChanged(snap(value + step)) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A [LabeledSlider]'s title with its value at the end of the line, or,
/// where the title, whole on one line, wouldn't fit beside the value at its
/// size (large text on a phone), the value under the title: the title is
/// never squeezed, as a stacked [PaperRow]'s isn't, and its words stay
/// whole. The title of each slider of its [group] is held to the same, so
/// that they all decide alike; and so is the widest of its [values], so that
/// the head keeps its layout as the value moves.
class _SliderHead extends StatelessWidget {
  const _SliderHead({required this.title, required this.value, required this.values, required this.group});

  final String title;
  final String value;

  /// Every value the slider may show.
  final List<String> values;

  /// The titles of the sliders shown with it.
  final List<String> group;

  /// What the value is allowed at least, as wide as a percentage: so that
  /// the sliders of a group, whose values are as wide or narrower, decide
  /// alike whether to set it under the title.
  static const _allowance = '100%';

  static const _gap = Space.md;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.bodyLarge;
    // Tabular figures, so the value doesn't jiggle as it changes.
    final valueStyle = textTheme.labelLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // Measured as drawn: bold where the platform asks for bold text.
    final bold = MediaQuery.boldTextOf(context);
    double width(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: bold ? style?.copyWith(fontWeight: FontWeight.bold) : style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final valueWidth = {...values, _allowance}.map((v) => width(v, valueStyle)).reduce(math.max);
    final titleWidth = {title, ...group}.map((t) => width(t, titleStyle)).reduce(math.max);
    return LayoutBuilder(builder: (context, constraints) {
      final beside = titleWidth + _gap + valueWidth <= constraints.maxWidth;
      final titleText = WholeWords(title, style: titleStyle, textAlign: TextAlign.start);
      final valueText = Text(value, style: valueStyle);
      if (beside) {
        return Row(children: [Expanded(child: titleText), const Gap(_gap), valueText]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [titleText, valueText]);
    });
  }
}

/// Settings pages share this scaffold with a readable max width. A [paper]
/// page is set in paper groups (§6.3), which stand on the gutters; any other
/// is a page of list tiles, which line up with the title
/// (PageBody.tilePadding).
///
/// A page may show a [preview] of what its settings change above them (§9
/// Display), [previewMaxHeight] high. Where the window is tall enough and the
/// text not so large that it would crowd the settings out (at least 640
/// high, and 16 sp text no larger than 24), the preview stays at the top as
/// the settings scroll under it, shrinking to [previewMinHeight] first; it
/// is built with how far it has shrunk, from 0 to 1. Elsewhere it scrolls
/// away with them, whole.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children, this.paper = false, this.preview});

  final String title;
  final List<Widget> children;
  final bool paper;
  final Widget Function(BuildContext context, double shrunk)? preview;

  static const previewMaxHeight = 220.0;
  static const previewMinHeight = 140.0;

  /// Whether a [preview] stays in view in [context], as above.
  static bool previewPinned(BuildContext context) =>
      MediaQuery.sizeOf(context).height >= 640 && MediaQuery.textScalerOf(context).scale(16) <= 24;

  @override
  Widget build(BuildContext context) {
    final preview = this.preview;
    final padding = paper ? null : PageBody.tilePadding(context);
    return PageScaffold(
      titleText: title,
      body: preview == null
          ? PageBody(padding: padding, children: children)
          : _PreviewedBody(preview: preview, padding: padding, children: children),
    );
  }
}

/// A settings page's body under its preview, laid out as a [PageBody]'s: in
/// the page's column, with its padding.
class _PreviewedBody extends StatelessWidget {
  const _PreviewedBody({required this.preview, required this.padding, required this.children});

  final Widget Function(BuildContext context, double shrunk) preview;
  final EdgeInsets? padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = (padding ?? PageBody.defaultPadding(context)) +
        EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom);
    final pinned = SettingsPage.previewPinned(context);
    Widget column(Widget child) => Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: ContentWidth.list), child: child),
        );
    final scrollView = CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          pinned: pinned,
          delegate: _PreviewHeader(
            preview: preview,
            // On the gutters, as paper is, with the page's 8 above it.
            padding: EdgeInsets.fromLTRB(Gutter.of(context), Space.sm, Gutter.of(context), Space.md),
            maxHeight: SettingsPage.previewMaxHeight,
            minHeight: pinned ? SettingsPage.previewMinHeight : SettingsPage.previewMaxHeight,
          ),
        ),
        SliverToBoxAdapter(
          child: column(
            Padding(
              padding: p.copyWith(top: 0),
              // Each heading, text and control a node of its own.
              child: Semantics(
                explicitChildNodes: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ),
        ),
      ],
    );
    // Held at the top, the preview carries on the app bar: the rule that
    // marks the settings scrolled under it is its own, not the app bar's.
    if (!pinned) return scrollView;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) => true,
      child: NotificationListener<ScrollNotification>(onNotification: (_) => true, child: scrollView),
    );
  }
}

class _PreviewHeader extends SliverPersistentHeaderDelegate {
  const _PreviewHeader({required this.preview, required this.padding, required this.maxHeight, required this.minHeight});

  final Widget Function(BuildContext context, double shrunk) preview;
  final EdgeInsets padding;
  final double maxHeight;
  final double minHeight;

  @override
  double get maxExtent => maxHeight + padding.vertical;

  @override
  double get minExtent => minHeight + padding.vertical;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final sefer = SeferColors.of(context);
    final range = maxExtent - minExtent;
    final shrunk = range == 0 ? 0.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final height = math.max(minExtent, maxExtent - shrinkOffset);
    return SizedBox(
      height: height,
      child: DecoratedBox(
        // The page's own surface, which hides the settings scrolled under it.
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          // A rule once the settings pass under it.
          border: range > 0 && shrinkOffset > range
              ? Border(bottom: BorderSide(color: sefer.hairline, width: sefer.hairlineWidth))
              : null,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ContentWidth.list),
            child: SizedBox(
              width: double.infinity,
              height: height,
              child: Padding(padding: padding, child: preview(context, shrunk)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_PreviewHeader old) =>
      old.preview != preview || old.padding != padding || old.maxHeight != maxHeight || old.minHeight != minHeight;
}

/// A setting that is on or off, as a row of paper (§6.3): its title and
/// description, never cut short, and at the end a switch that the whole row
/// toggles. It reads as one item, a switch; with no [onChanged] it shows
/// what it would set, disabled, its subtitle saying why (§9). It is a
/// [PaperRow], so that its group rules it off as one.
class SwitchRow extends PaperRow {
  SwitchRow({
    super.key,
    super.icon,
    required super.title,
    super.subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) : super(
          subtitleMaxLines: null,
          onTap: onChanged == null ? null : () => onChanged(!value),
          chevron: false,
          mergeTrailing: true,
          // The row takes the focus and rings itself; the switch shows the
          // state, and toggles it when tapped itself.
          trailing: ExcludeFocus(
            child: Switch(value: value, onChanged: onChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
        );

  @override
  Widget build(BuildContext context) {
    if (onTap != null) return super.build(context);
    // Disabled: its title and icon dimmed as Material dims a disabled
    // control's (38%), so that the row doesn't look as if a tap would do
    // something; the switch shows it in its own way. Its subtitle is not:
    // it says why the switch won't move (the device has the setting on),
    // for readers who may well have low vision.
    final scheme = Theme.of(context).colorScheme;
    return PaperRow(
      icon: icon,
      iconColor: (iconColor ?? scheme.onSurfaceVariant).withValues(alpha: 0.38),
      title: title,
      breakTitleAtHyphens: breakTitleAtHyphens,
      titleStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.38)).merge(titleStyle),
      subtitle: subtitle,
      subtitleMaxLines: subtitleMaxLines,
      subtitleLocale: subtitleLocale,
      subtitleStyle: subtitleStyle,
      detail: detail,
      trailing: trailing,
      mergeTrailing: mergeTrailing,
      chevron: chevron,
    );
  }
}
