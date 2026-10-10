import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/models/parsha.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/common.dart';
import '../progress/domain/progress_models.dart';

/// All 54 parshiyot, grouped by book, for reading any portion of this
/// year's cycle.
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final repo = ref.watch(parshaRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    final current = ref.watch(currentWeekProvider);
    final cycle = cycleYearOf(current.portion, current.occasion);
    final progress = ref.watch(progressProvider);

    bool isDone(PortionInfo p) =>
        progress.weeks.entries.any((e) =>
            e.key.startsWith('$cycle:') &&
            e.value.isComplete &&
            e.key.substring(e.key.indexOf(':') + 1).split('-').contains('${p.id.number}'));

    return Scaffold(
      appBar: AppBar(title: Text(l.browseTitle)),
      body: PageBody(
        children: [
          for (var b = 0; b < kTorahBooks.length; b++) ...[
            SectionHeader(l.bookOfTorah(names.book(kTorahBooks[b]))),
            for (final p in repo.all.where((p) => p.bookIndex == b))
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: isDone(p)
                      ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, semanticLabel: l.stateDone)
                      : const Icon(Icons.menu_book_outlined),
                  title: Text(names.portion(p, ashkenazi: settings.ashkenaziNames)),
                  subtitle: Text(
                    '${names.portionAlt(p, ashkenazi: settings.ashkenaziNames)} · '
                    '${names.range(p.book, p.range.start.chapter, p.range.start.verse, p.range.end.chapter, p.range.end.verse)}',
                  ),
                  selected: current.portion.parshiyot.contains(p.id.number),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/parsha/week/$cycle:${p.id.number}'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
