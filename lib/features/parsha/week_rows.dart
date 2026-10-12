import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/paper_group.dart';
import '../community/ui/community_ui.dart';
import '../progress/domain/progress_models.dart' show cycleYearOf;
import 'week_context.dart';

/// The week's haftarah as a row of a [PaperGroup]: its reference, and a line
/// for a special haftarah and for the regular one its page also offers. It
/// opens the haftarah within the tab it is shown in.
class HaftarahRow extends StatelessWidget {
  const HaftarahRow({super.key, required this.ctx});

  final WeekContext ctx;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    final h = ctx.haftarah;
    return PaperRow(
      icon: Icons.auto_stories_outlined,
      title: ctx.progress.haftarah != null ? l.haftarahRead : l.haftarahLabel,
      subtitle: [
        h.parts.map((p) => names.range(p.book, p.start.chapter, p.start.verse, p.end.chapter, p.end.verse)).join(' · '),
        if (h.specialKey case final key?) l.specialHaftarah(names.specialHaftarah(key)),
        if (h.regular != null) l.alsoRegularHaftarah,
      ].join('\n'),
      // A line for each fact, none cut short.
      subtitleMaxLines: null,
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
