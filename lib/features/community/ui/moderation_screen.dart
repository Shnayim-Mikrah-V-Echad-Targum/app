import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../data/backend.dart';
import '../data/models.dart';
import 'community_ui.dart';

final _reportsProvider = FutureProvider<List<Report>>((ref) => ref.watch(forumRepositoryProvider).openReports());

/// The moderators' queue of open reports.
class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final reports = ref.watch(_reportsProvider);
    final repo = ref.read(forumRepositoryProvider);
    String reason(ReportReason r) => switch (r) {
          ReportReason.spam => l.reasonSpam,
          ReportReason.lashonHara => l.reasonLashonHara,
          ReportReason.disrespect => l.reasonDisrespect,
          ReportReason.misinformation => l.reasonMisinformation,
          ReportReason.offTopic => l.reasonOffTopic,
          ReportReason.other => l.reasonOther,
        };

    Future<void> act(Future<void> Function() f) async {
      try {
        await f();
        ref.invalidate(_reportsProvider);
      } catch (e) {
        if (context.mounted) showStatus(context, communityError(l, e));
      }
    }

    Future<void> refresh() async {
      ref.invalidate(_reportsProvider);
      await ref.read(_reportsProvider.future);
    }

    return RefreshablePage(
      refresh: refresh,
      builder: (context, refreshButton) => Scaffold(
        appBar: AppBar(title: Text(l.moderationQueue), actions: [refreshButton]),
        body: reports.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(communityError(l, e))),
          data: (list) => RefreshIndicator(
            // A failure shows in place of the reports.
            onRefresh: () => refresh().catchError((Object _) {}),
            child: PageBody(
              children: [
                if (list.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(l.noReports, textAlign: TextAlign.center)),
                for (final r in list)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reason(r.reason), style: Theme.of(context).textTheme.titleSmall),
                          Text(relativeTime(context, r.createdAt), style: Theme.of(context).textTheme.bodySmall),
                          if (r.details != null && r.details!.isNotEmpty) ...[const Gap(4), Text(r.details!)],
                          if (r.postBody != null) ...[
                            const Gap(8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Text(
                                r.postBody!,
                                textDirection: autoDirection(r.postBody!, fallback: Directionality.of(context)),
                              ),
                            ),
                          ],
                          const Gap(8),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (r.postId != null)
                                FilledButton.tonal(
                                  style: AppButtons.tonal(context),
                                  onPressed: () => act(() async {
                                    await repo.moderate('hide_post', r.postId!);
                                    await repo.moderate('resolve_report', r.id);
                                  }),
                                  child: Text(l.removePost),
                                ),
                              OutlinedButton(
                                onPressed: () => act(() => repo.moderate('dismiss_report', r.id)),
                                child: Text(l.dismissReport),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
