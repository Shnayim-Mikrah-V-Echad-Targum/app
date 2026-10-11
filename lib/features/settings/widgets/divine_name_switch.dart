import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../ui/l10n.dart';

/// Display → Text: whether a verse that leaves the app, copied, shared or
/// quoted in a question, writes the Divine Name as ה׳ (DESIGN.md §3). On by
/// default.
class DivineNameSwitch extends ConsumerWidget {
  const DivineNameSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return SwitchListTile(
      title: Text(l.copyDivineName),
      subtitle: Text(l.copyDivineNameDesc),
      value: ref.watch(settingsProvider.select((s) => s.copyDivineNameAsHashem)),
      onChanged: (v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(copyDivineNameAsHashem: v)),
    );
  }
}
