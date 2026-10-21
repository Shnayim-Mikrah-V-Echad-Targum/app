import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/support_details.dart';
import '../../services/updates/updates.dart';
import '../l10n.dart';
import 'common.dart';

/// The Windows app's offer of a new version, once one is found and while
/// it isn't Shabbat or Yom Tov, nor their eve after the reminders' cutoff
/// ([UpdateState.offered]): a calm NoticeBanner (§6.20), "Version 0.0.2 is
/// ready to install", with Install, at the top of Today's reading column and
/// in About, Updates. Install asks first ([confirmUpdate]), then prepares the
/// release and closes the app for its installer; meanwhile the banner says
/// "Preparing the update…". A release that couldn't be prepared is told of
/// in its place, with Copy details for support and Try again. [onDismiss],
/// where given, puts it away.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key, this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(updateControllerProvider);
    final release = state.offered;
    if (release == null) return const SizedBox.shrink();
    final dismissLabel = onDismiss == null ? null : l.actionDismiss;
    if (state.problem == UpdateProblem.install && !state.installing) {
      return NoticeBanner(
        icon: Icons.error_outline,
        text: l.updateInstallFailed,
        liveRegion: true,
        actionBelow: true,
        // Stacked at large text, the way on first, as in a dialog.
        action: OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          overflowAlignment: OverflowBarAlignment.end,
          overflowDirection: VerticalDirection.up,
          children: [
            TextButton(onPressed: () => copySupportDetails(context, ref), child: Text(l.copySupportDetails)),
            TextButton(
              onPressed: () => unawaited(ref.read(updateControllerProvider.notifier).install()),
              child: Text(l.actionRetry),
            ),
          ],
        ),
        onDismiss: onDismiss,
        dismissLabel: dismissLabel,
      );
    }
    final text = l.updateReady(context.ltrRun(release.versionName));
    final label = state.installing ? l.updatePreparing : l.updateInstall;
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSecondaryContainer;
    return LayoutBuilder(
      // Install beside the sentence while the two fit on one line, and
      // otherwise under it.
      builder: (context, constraints) => NoticeBanner(
        icon: Icons.system_update_alt_outlined,
        text: text,
        actionBelow: !NoticeBanner.actionFitsBeside(
          context,
          constraints.maxWidth,
          text: text,
          // The spinner beside "Preparing the update…" takes a word's room.
          label: state.installing ? '$label    ' : label,
          dismissible: onDismiss != null,
        ),
        action: state.installing
            ? Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ink)),
                      const SizedBox(width: 8),
                      Flexible(child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: ink))),
                    ],
                  ),
                ),
              )
            : TextButton(onPressed: () => confirmUpdate(context, ref), child: Text(label)),
        // Nothing to put away while the app is closing for the update.
        onDismiss: state.installing ? null : onDismiss,
        dismissLabel: state.installing ? null : dismissLabel,
      ),
    );
  }
}

/// Asks whether to install the release offered, "Install version 0.0.2?":
/// the app will close, install it and open again, the reading and settings
/// as they are. Installs it if asked to ([UpdateController.install]).
Future<void> confirmUpdate(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final release = ref.read(updateControllerProvider).offered;
  if (release == null) return;
  final ok = await showAppDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.updateInstallTitle(context.ltrRun(release.versionName))),
      content: Text(l.updateInstallBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.updateInstall)),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await ref.read(updateControllerProvider.notifier).install();
}
