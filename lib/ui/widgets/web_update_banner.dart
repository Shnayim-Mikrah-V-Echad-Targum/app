import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/web_update.dart';
import '../l10n.dart';
import 'common.dart';

/// The web app's offer of a new version, once one is ready
/// ([webUpdateReadyProvider]): a NoticeBanner (§6.20) with Restart, at the
/// top of Today's reading column and in About, never over the reading, a
/// discussion or a post being written. [onDismiss], where given, puts it
/// away.
class WebUpdateBanner extends ConsumerWidget {
  const WebUpdateBanner({super.key, this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final text = l.webUpdateReady;
    final label = l.webUpdateRestart;
    return LayoutBuilder(
      // Restart beside the sentence while the two fit on one line, and
      // otherwise under it.
      builder: (context, constraints) => NoticeBanner(
        icon: Icons.system_update_alt_outlined,
        text: text,
        actionBelow: !NoticeBanner.actionFitsBeside(
          context,
          constraints.maxWidth,
          text: text,
          label: label,
          dismissible: onDismiss != null,
        ),
        action: TextButton(
          onPressed: () => ref.read(webUpdateReadyProvider.notifier).restart(),
          child: Text(label),
        ),
        onDismiss: onDismiss,
        dismissLabel: onDismiss == null ? null : l.actionDismiss,
      ),
    );
  }
}
