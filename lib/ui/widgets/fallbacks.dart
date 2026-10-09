import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n.dart';
import 'common.dart';

/// The leading button of the app bar of a page that can open with nothing
/// beneath it, from a link, a notification or a web reload: a way home to
/// Today rather than a dead end. Null, leaving the usual back button, when
/// there is a page to go back to.
Widget? homeLeading(BuildContext context) {
  // The app bar's own test for its back button, so exactly one of the two
  // shows.
  if (ModalRoute.of(context)?.impliesAppBarDismissal ?? true) return null;
  return IconButton(
    tooltip: context.l10n.navToday,
    icon: const Icon(Icons.home_outlined),
    onPressed: () => context.go('/today'),
  );
}

/// A short message in the middle of a page that has nothing else to show,
/// with what to do next beneath it.
class CenteredMessage extends StatelessWidget {
  const CenteredMessage({super.key, required this.text, this.actions = const []});

  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
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
