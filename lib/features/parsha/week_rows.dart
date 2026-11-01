import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../data/models/parsha.dart' show HaftarahNusach;
import '../../services/feedback.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/paper_group.dart';
import '../../ui/widgets/read_date_sheet.dart';
import '../community/ui/community_ui.dart';
import '../progress/domain/progress_models.dart' show ReadingPass, cycleYearOf, kAliyot;
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

/// The readings of the whole parsha, for a reader who reads it through once,
/// then again, then its Targum (or Rashi): a row for each, done once every
/// aliyah's is, which a tap marks read for all seven (on the day the reader
/// picks) or, done, not read, with Undo.
class WholeParshaRows {
  static List<Widget> of(BuildContext context, WidgetRef ref, WeekContext ctx) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final secondName = settings.usesRashi && !settings.usesOnkelos ? l.passRashi : l.passTargum;
    final names = [l.passMikrah1, l.passMikrah2, secondName];
    return [
      for (final pass in ReadingPass.values)
        () {
          final read = [for (var a = 0; a < kAliyot; a++) ctx.progress.isUnitDone(a, pass)].where((d) => d).length;
          final done = read == kAliyot;
          final name = names[pass.index];
          Future<void> toggle() async {
            final progress = ref.read(progressProvider.notifier);
            if (done) {
              final before = ref.read(progressProvider).week(ctx.id);
              progress.markPass(ctx.id, pass, null);
              final container = ProviderScope.containerOf(context, listen: false);
              showStatus(
                context,
                l.passMarkedUnread(name),
                action: SnackBarAction(
                  label: l.actionUndo,
                  onPressed: () => container.read(progressProvider.notifier).restoreWeek(ctx.id, before),
                ),
              );
              return;
            }
            final date = await pickReadDate(context, week: ctx.week, today: ctx.today, oneDayYomTov: settings.oneDayYomTov);
            if (date == null || !context.mounted) return;
            final wasComplete = ref.read(progressProvider).week(ctx.id).isComplete;
            progress.markPass(ctx.id, pass, date);
            hapticRecorded(ref, completedParsha: !wasComplete && ref.read(progressProvider).week(ctx.id).isComplete);
            showStatus(context, l.passMarkedRead(name));
          }

          return PaperRow(
            icon: done ? Icons.check_circle : Icons.radio_button_unchecked,
            title: l.wholeParshaPass(name),
            subtitle: l.aliyotProgress(read, kAliyot),
            toggled: done,
            chevron: false,
            onTap: ctx.isOpen || read > 0 ? toggle : null,
          );
        }(),
    ];
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
