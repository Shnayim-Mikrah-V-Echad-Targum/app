import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';

/// That the app was made with AI, and where its texts come from: a permanent
/// disclosure, not a notice of something that has happened, so it is not a
/// [NoticeBanner]. Full on About and Texts & sources; on Today, one line at the
/// top of the page, which is itself the link to Texts & sources.
class AiSourcesNotice extends StatelessWidget {
  const AiSourcesNotice({super.key, this.compact = false, this.linkToSources = true});

  /// The one-line strip, on Today.
  final bool compact;

  /// Whether a link to Texts & sources is offered (not on that page).
  final bool linkToSources;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = scheme.onSecondaryContainer;
    if (compact) {
      return Card(
        color: scheme.secondaryContainer,
        child: Semantics(
          // The strip is one link, read by its own words.
          link: true,
          label: l.aiNoticeStrip,
          excludeSemantics: true,
          child: SeferInkWell(
            onTap: () => context.push('/settings/about/sources'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_outlined, size: 20, color: ink),
                  const Gap(Space.sm),
                  Expanded(child: Text(l.aiNoticeStrip, style: theme.textTheme.bodyMedium?.copyWith(color: ink))),
                  Icon(Icons.chevron_right, size: 20, color: ink),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, size: 20, color: ink),
                const Gap(Space.sm),
                Expanded(child: Text(l.aiNoticeTitle, style: theme.textTheme.titleMedium?.copyWith(color: ink))),
              ],
            ),
            const Gap(Space.sm),
            Text(l.aiNoticeBody, style: theme.textTheme.bodyMedium?.copyWith(color: ink)),
            if (linkToSources)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => context.push('/settings/about/sources'),
                  child: Text(l.sourcesTitle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
