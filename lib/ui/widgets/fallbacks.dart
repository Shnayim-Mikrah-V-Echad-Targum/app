import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'ornaments.dart';

/// The leading button of the app bar of a page that can open with nothing
/// beneath it, from a link, a notification or a web reload: a way home to
/// Today rather than a dead end. Null, leaving the usual back button, when
/// there is a page to go back to.
Widget? homeLeading(BuildContext context) {
  // Only whether the route can pop: depending on the whole route would
  // rebuild the page each time a menu, sheet or dialog opens over it. The
  // app bar's own test differs only for local history entries, which these
  // pages don't use.
  if (ModalRoute.canPopOf(context) ?? true) return null;
  return IconButton(
    tooltip: context.l10n.navToday,
    icon: const Icon(Icons.home_outlined),
    onPressed: () => context.go('/today'),
  );
}

/// A short message on a page that has nothing else to show, with what to do
/// next beneath it: the first of [actions] a Tonal button (styled with
/// [AppButtons.tonal]), any others Text buttons. Laid out as an [EmptyState]
/// (DESIGN_SYSTEM.md §6.22): a divider, one gentle sentence, centred, at most
/// 320 wide and 40 below the app bar; it scrolls when large text needs it.
class CenteredMessage extends StatelessWidget {
  const CenteredMessage({super.key, required this.text, this.actions = const []});

  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SeferDivider(),
              const Gap(12),
              Text(text, textAlign: TextAlign.center, style: SeferType.of(context).marginalia),
              if (actions.isNotEmpty) ...[
                const Gap(16),
                Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The page for a link that leads nowhere in the app: a mistyped or outdated
/// web address, say, or one to a week or a policy that doesn't exist.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.notFoundTitle)),
      body: CenteredMessage(
        text: l.notFoundBody,
        actions: [
          FilledButton.tonalIcon(
            style: AppButtons.tonal(context),
            icon: const Icon(Icons.home_outlined),
            label: Text(l.goToToday),
            onPressed: () => context.go('/today'),
          ),
        ],
      ),
    );
  }
}
