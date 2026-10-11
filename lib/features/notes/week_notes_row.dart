import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/paper_group.dart';
import '../parsha/week_context.dart';
import 'notes_screen.dart';

/// On a week's page, the reader's bookmarks and notes on its parsha, as a
/// row of a [PaperGroup] (beside the haftarah and the discussion): "Your
/// notes on this parsha", with how many of each beneath it ("2 notes · 1
/// bookmark"), that opens them. The page shows it only once there are any
/// ([shows]).
class WeekNotesRow extends ConsumerWidget {
  const WeekNotesRow({super.key, required this.ctx});

  final WeekContext ctx;

  /// Whether the reader has bookmarked or written a note on any verse of
  /// [ctx]'s parsha, and so whether the page shows the row.
  static bool shows(WidgetRef ref, WeekContext ctx) =>
      ref.watch(annotationsProvider).within(ctx.portion.range).isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final marked = ref.watch(annotationsProvider).within(ctx.portion.range);
    final notes = marked.where((e) => e.$2.hasNote).length;
    final bookmarks = marked.where((e) => e.$2.bookmarked).length;
    return PaperRow(
      icon: Icons.bookmarks_outlined,
      title: l.parshaNotes,
      subtitle: [if (notes > 0) l.notesCount(notes), if (bookmarks > 0) l.bookmarksCount(bookmarks)].join(' · '),
      onTap: () => context.push(notesPath(weekId: ctx.id)),
    );
  }
}
