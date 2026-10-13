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

  /// Beside the sentence and the button: the banner's padding at the start,
  /// the icon and its gap, the button's own padding, and at the end the
  /// close button and its padding, or the end padding alone.
  static double _around({required bool dismissible}) => 16 + 20 + 12 + 24 + (dismissible ? 4 + 48 : 8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final text = l.webUpdateReady;
    final label = l.webUpdateRestart;
    return LayoutBuilder(
      builder: (context, constraints) {
        double width(String s, TextStyle? style) {
          final painter = TextPainter(
            text: TextSpan(text: s, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        }

        // Restart beside the sentence while the two fit on one line, and
        // otherwise under it, as at large text, rather than squeezing the
        // sentence into a narrow column beside it.
        final buttonStyle = theme.textButtonTheme.style?.textStyle?.resolve({}) ?? theme.textTheme.labelLarge;
        final beside = width(text, theme.textTheme.bodyMedium) + width(label, buttonStyle) +
                _around(dismissible: onDismiss != null) <=
            constraints.maxWidth;
        return NoticeBanner(
          icon: Icons.system_update_alt_outlined,
          text: text,
          actionBelow: !beside,
          action: TextButton(
            onPressed: () => ref.read(webUpdateReadyProvider.notifier).restart(),
            child: Text(label),
          ),
          onDismiss: onDismiss,
          dismissLabel: onDismiss == null ? null : l.actionDismiss,
        );
      },
    );
  }
}
