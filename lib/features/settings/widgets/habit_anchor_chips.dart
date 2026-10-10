import 'package:flutter/material.dart';

import '../../../ui/l10n.dart';
import '../../../ui/widgets/sefer_choice_chip.dart';
import '../app_settings.dart';

/// The routines the daily reading can be tied to, as chips completing
/// "After I…". At most one is chosen; choosing it again clears it.
class HabitAnchorChips extends StatelessWidget {
  const HabitAnchorChips({super.key, required this.selected, required this.onChanged});

  final HabitAnchor? selected;
  final ValueChanged<HabitAnchor?> onChanged;

  @override
  Widget build(BuildContext context) {
    final names = Names(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.habitAnchorLabel, style: Theme.of(context).textTheme.titleSmall),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final a in HabitAnchor.values)
              SeferChoiceChip(
                label: Text(names.habitAnchor(a)),
                selected: selected == a,
                onSelected: (on) => onChanged(on ? a : null),
              ),
          ],
        ),
      ],
    );
  }
}
