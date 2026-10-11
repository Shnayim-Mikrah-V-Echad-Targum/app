import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/l10n.dart';
import '../search/go_to_verse_sheet.dart';
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
        // Every parsha of the Torah, named in words rather than by an icon.
        TextButton(
          onPressed: () => context.push('/parsha/browse'),
          child: ConstrainedBox(
            // With very large text on a phone, set smaller than it would be,
            // rather than pushing the other actions off the app bar.
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.4),
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(context.l10n.browseAll)),
          ),
        ),
        // A verse by its reference, or words to search for.
        IconButton(
          tooltip: context.l10n.searchTitle,
          icon: const Icon(Icons.search),
          onPressed: () => showGoToVerse(context),
        ),
      ],
    );
  }
}
