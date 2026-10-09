import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/l10n.dart';
import 'week_context.dart';
import 'week_overview_screen.dart';

/// The "Parsha" tab: this week's portion, with access to the whole Torah.
class ParshaTab extends ConsumerWidget {
  const ParshaTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(currentWeekContextProvider);
    return WeekOverview(
      ctx: ctx,
      actions: [
        IconButton(
          tooltip: context.l10n.browseAll,
          icon: const Icon(Icons.list_alt),
          onPressed: () => context.go('/parsha/browse'),
        ),
      ],
    );
  }
}
