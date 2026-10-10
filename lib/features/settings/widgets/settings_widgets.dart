import 'package:flutter/material.dart';

import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/fonts_change_scope.dart';
import '../../../ui/widgets/paper_group.dart';

/// One option in a [ChoiceGroup].
class Choice<T> {
  const Choice(this.value, this.title, {this.subtitle, this.semanticsLabel});
  final T value;
  final String title;
  final String? subtitle;

  /// What screen readers say for [title], where it would be read badly as
  /// written.
  final String? semanticsLabel;
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
  const SettingHeading(this.title, {super.key, this.help, this.helpIsSource = false, this.level = 2})
      : assert(level == 2 || level == 3);

  final String title;
  final String? help;
  final bool helpIsSource;
  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final help = this.help;
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
        if (help != null)
          if (helpIsSource)
            Padding(padding: EdgeInsets.only(top: level == 2 ? 0 : Space.sm), child: SourceNote(help))
          else
            Padding(
              padding: inset.add(EdgeInsets.only(top: level == 2 ? 0 : 2)),
              child: Text(help, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ),
        // A group header keeps 8 below itself.
        Gap(help != null ? Space.md : (level == 2 ? 0 : Space.sm)),
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
/// it, through a [SourceNote] where [helpIsSource]. [margin] surrounds the
/// whole: on a page still padded for list tiles (PageBody.tilePadding), 16
/// at the sides brings the paper to the gutters.
class ChoiceGroup<T> extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.title,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.help,
    this.helpIsSource = false,
    this.segmented = false,
    this.headingLevel = 2,
    this.margin = EdgeInsets.zero,
  });

  final String title;
  final T value;
  final List<Choice<T>> choices;
  final ValueChanged<T> onChanged;
  final String? help;
  final bool helpIsSource;
  final bool segmented;
  final int headingLevel;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final Widget options = segmented
        ? _Segments<T>(value: value, choices: choices, onChanged: onChanged)
        : RadioGroup<T>(
            groupValue: value,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            child: PaperGroup(
              ruleInset: _RadioRow.textStart,
              children: [for (final c in choices) _RadioRow<T>(choice: c)],
            ),
          );
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingHeading(title, help: help, helpIsSource: helpIsSource, level: headingLevel),
          options,
        ],
      ),
    );
  }
}

/// A [ChoiceGroup]'s options as a segmented control across the column, each
/// label in two lines at most, with no word broken, and in as many lines
/// whichever segment is selected and bears the check, so that nothing moves
/// as the choice changes. Where the labels don't fit so beside the check,
/// they go without it, the selected segment's fill and bold label marking
/// it; except in high contrast, where the fill is close to the paper and the
/// check stays, as it does where they don't fit even so (large text, a
/// narrow phone): then the segments stand one under another.
class _Segments<T> extends StatelessWidget {
  const _Segments({required this.value, required this.choices, required this.onChanged});

  final T value;
  final List<Choice<T>> choices;
  final ValueChanged<T> onChanged;

  /// A segment's padding (12 at each side), its borders and a little to
  /// spare, and the check before the selected one's label (18, then a gap of
  /// 8).
  static const _padding = 24.0 + 2 + 4;
  static const _check = 18.0 + 8;

  /// Whether every label fits a segment [room] wide, beside a check or with
  /// none, as above.
  bool _fit(BuildContext context, double room, {required bool checked}) {
    if (room - (checked ? _check : 0) <= 0) return false;
    // Bold, as the selected segment sets it.
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700);
    final painter = TextPainter(textDirection: Directionality.of(context), textScaler: MediaQuery.textScalerOf(context));
    int lines(String text, double width) => (painter
          ..text = TextSpan(text: text, style: style)
          ..layout(maxWidth: width))
        .computeLineMetrics()
        .length;
    double width(String word) => (painter
          ..text = TextSpan(text: word, style: style)
          ..layout())
        .width;
    try {
      return choices.every((c) {
        final narrowest = checked ? room - _check : room;
        final n = lines(c.title, narrowest);
        return n <= 2 &&
            (!checked || n == lines(c.title, room)) &&
            c.title.split(RegExp(r'\s')).every((word) => width(word) <= narrowest);
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
      final segment = constraints.maxWidth / choices.length - _padding;
      final checked = _fit(context, segment, checked: true);
      final across = checked || (!SeferColors.of(context).isHighContrast && _fit(context, segment, checked: false));
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
                label: Text(c.title, semanticsLabel: c.semanticsLabel, textAlign: TextAlign.center),
              ),
          ],
          selected: {value},
          onSelectionChanged: (selected) => onChanged(selected.single),
          showSelectedIcon: checked || !across,
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
class _RadioRow<T> extends StatefulWidget {
  const _RadioRow({super.key, required this.choice});

  final Choice<T> choice;

  /// Where the text starts, as in a [PaperRow] with an icon: the radio's
  /// circle (20 in a 40 box) at 16, as an icon is.
  static const textStart = PaperGroup.iconInset;
  static const _radioBox = 40.0;
  static const _start = PaperGroup.plainInset - 10;

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
    final corners = PaperGroup.rowCorners(context);
    final choice = widget.choice;
    final ring = _focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return DecoratedBox(
      // Always present, so that showing the ring never rebuilds the tile
      // (and drops its focus).
      position: DecorationPosition.foreground,
      decoration: ring
          ? ShapeDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: corners,
                side: BorderSide(
                  color: SeferColors.of(context).focus,
                  width: 3,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
            )
          : const BoxDecoration(),
      child: Theme(
        // The ring marks focus; the tile's wash as well would read as a
        // second selection.
        data: theme.copyWith(focusColor: Colors.transparent),
        child: RadioListTile<T>(
          value: choice.value,
          title: Text(choice.title, semanticsLabel: choice.semanticsLabel),
          subtitle: choice.subtitle == null ? null : Text(choice.subtitle!),
          // The ink keeps to the paper's corners.
          shape: RoundedRectangleBorder(borderRadius: corners),
          contentPadding: const EdgeInsetsDirectional.only(start: _RadioRow._start, end: 12),
          horizontalTitleGap: _RadioRow.textStart - _RadioRow._start - _RadioRow._radioBox,
          onFocusChange: (focused) => setState(() => _focused = focused),
        ),
      ),
    );
  }
}

/// A slider with a visible, spoken value and +/- buttons for users who
/// can't drag precisely. Assistive technology reads the slider by its
/// setting and value ("Reading size, 100%"), and each button by what it does.
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
  });

  final String title;
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
    final textTheme = Theme.of(context).textTheme;
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
            child: Row(
              children: [
                Expanded(child: Text(title, style: textTheme.bodyLarge)),
                // Tabular figures, so the value doesn't jiggle as it changes.
                Text(
                  format(value),
                  style: textTheme.labelLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
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
                // One node, read as "Reading size, 100%". No value indicator:
                // the value already shows above.
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

/// Settings pages share this scaffold with a readable max width. A [paper]
/// page is set in paper groups (§6.3), which stand on the gutters; any other
/// is a page of list tiles, which line up with the title
/// (PageBody.tilePadding).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children, this.paper = false});

  final String title;
  final List<Widget> children;
  final bool paper;

  @override
  Widget build(BuildContext context) => PageScaffold(
        titleText: title,
        body: PageBody(padding: paper ? null : PageBody.tilePadding(context), children: children),
      );
}

/// A setting that is on or off, as a row of paper (§6.3): its title and
/// description, never cut short, and at the end a switch that the whole row
/// toggles. It reads as one item, a switch; with no [onChanged] it shows
/// what it would set, disabled. It is a [PaperRow], so that its group rules
/// it off as one.
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
}
