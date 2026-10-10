import 'package:flutter/material.dart';

import '../../../ui/l10n.dart';
import '../../../ui/widgets/common.dart';

/// One option in a [ChoiceGroup].
class Choice<T> {
  const Choice(this.value, this.title, {this.subtitle});
  final T value;
  final String title;
  final String? subtitle;
}

/// A labeled group of radio options. Uses RadioGroup so assistive technology
/// announces "1 of 3" and arrow keys move between options.
class ChoiceGroup<T> extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.title,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.help,
  });

  final String title;
  final T value;
  final List<Choice<T>> choices;
  final ValueChanged<T> onChanged;
  final String? help;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title, level: 3, padding: const EdgeInsetsDirectional.only(top: 16, bottom: 4, start: 16, end: 16)),
        if (help != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(help!, style: Theme.of(context).textTheme.bodySmall),
          ),
        RadioGroup<T>(
          groupValue: value,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          child: Column(
            children: [
              for (final c in choices)
                RadioListTile<T>(
                  value: c.value,
                  title: Text(c.title),
                  subtitle: c.subtitle == null ? null : Text(c.subtitle!),
                ),
            ],
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

/// Settings pages share this scaffold with a readable max width.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: PageBody(padding: const EdgeInsets.only(bottom: 32), children: children),
      );
}
