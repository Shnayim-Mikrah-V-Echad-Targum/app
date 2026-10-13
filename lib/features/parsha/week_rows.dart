import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../data/models/parsha.dart' show HaftarahNusach;
import '../../ui/l10n.dart';
import '../../ui/widgets/paper_group.dart';
import '../community/ui/community_ui.dart';
import '../progress/domain/progress_models.dart' show cycleYearOf;
import 'week_context.dart';

/// The week's haftarah as a row of a [PaperGroup]: its reference, and in a
/// week with a special haftarah, a detail line naming it. For Chabad, whose
/// custom is to read the regular haftarah as well where the special one
/// displaces it, the line says so; the other customs' pages offer it folded.
/// It opens the haftarah within the tab it is shown in.
class HaftarahRow extends ConsumerWidget {
  const HaftarahRow({super.key, required this.ctx});

  final WeekContext ctx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final nusach = ref.watch(settingsProvider.select((s) => s.nusach));
    final h = ctx.haftarah;
    return PaperRow(
      icon: Icons.auto_stories_outlined,
      title: ctx.progress.haftarah != null ? l.haftarahRead : l.haftarahLabel,
      // Broken between passages, never inside one, and never cut short:
      // two lines hold all but the longest, Re'eh's for Sephardim on Rosh
      // Chodesh Elul, with verses of two more haftarot.
      subtitleParts: [for (final p in h.parts) names.passage(p)],
      detail: switch (h.specialKey) {
        final key? when h.regular != null && nusach == HaftarahNusach.chabad =>
          l.haftarahSpecialChabadRegular(names.specialHaftarah(key)),
        final key? => names.specialHaftarah(key),
        null => null,
      },
      onTap: () => context.push(haftarahPath(context, ctx.id)),
    );
  }
}

/// The week's discussion as a row of a [PaperGroup], with a spinner at its
/// end while the thread opens.
class DiscussRow extends StatelessWidget {
  const DiscussRow({super.key, required this.ctx});

  final WeekContext ctx;

  @override
  Widget build(BuildContext context) => WeeklyThreadOpener(
        portion: ctx.portion,
        hebrewYear: cycleYearOf(ctx.week.portion, ctx.week.occasion),
        builder: (context, progress, open) => PaperRow(
          icon: Icons.forum_outlined,
          title: context.l10n.discussThisWeek,
          // In the chevron's place, so the row keeps its layout.
          progress: progress,
          onTap: open,
        ),
      );
}
