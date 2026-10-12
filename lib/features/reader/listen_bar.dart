import 'package:flutter/material.dart';

import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import 'listen_along.dart';
import 'reader_screen.dart';

/// The player that shows while Listen reads (docs/DESIGN_SYSTEM.md §6.28),
/// above the reader's bottom bar or at the foot of the page: the speech rate
/// at its start, back a verse, pause or go on, and on a verse at its centre,
/// and Stop at its end.
///
/// Like the bottom bar, it runs under the gesture bar in the page's own
/// colour, and keeps to the reading column. Its text grows to 200% at most
/// ([ReaderScreen.chromeMaxTextScale]), wherever it shows, as the rest of
/// the reader's chrome.
class ListenBar extends StatelessWidget {
  const ListenBar({
    super.key,
    required this.paused,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.rate,
    required this.onRate,
    required this.onStop,
    required this.maxWidth,
  });

  final bool paused;
  final VoidCallback onPlayPause;

  /// Null where there is no verse to go back, or on, to.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// The speech rate, as the setting holds it.
  final double rate;
  final ValueChanged<double> onRate;
  final VoidCallback onStop;

  /// The reading column's width.
  final double maxWidth;

  /// The side padding of the reading column, which [maxWidth] is within, as
  /// the bottom bar's.
  static const double _side = 16;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final sefer = SeferColors.of(context);
    // Media controls run left to right in either language: back a verse on
    // the left, on a verse on the right, as every player sets them.
    final transport = Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l.listenPreviousVerse,
            onPressed: onPrevious,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          const SizedBox(width: 8),
          // Tonal, as the design system's tonal buttons are: techelet's
          // container, never gold (§3.1).
          IconButton.filledTonal(
            tooltip: paused ? l.listenResume : l.listenPause,
            style: IconButton.styleFrom(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
            ),
            onPressed: onPlayPause,
            icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: l.listenNextVerse,
            onPressed: onNext,
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
    );
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: sefer.hairline, width: sefer.hairlineWidth)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth + 2 * _side),
            // The buttons' own padding brings their glyphs in line with the
            // column's edges.
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _side - 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      heightFactor: 1,
                      child: _RateButton(rate: rate, onRate: onRate),
                    ),
                  ),
                  transport,
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      heightFactor: 1,
                      child: IconButton(
                        tooltip: l.stopListening,
                        onPressed: onStop,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return MediaQuery.withClampedTextScaling(maxScaleFactor: ReaderScreen.chromeMaxTextScale, child: bar);
  }
}

/// The speech rate, which opens a menu of rates.
class _RateButton extends StatelessWidget {
  const _RateButton({required this.rate, required this.onRate});

  final double rate;
  final ValueChanged<double> onRate;

  Future<void> _open(BuildContext context) async {
    final l = context.l10n;
    final button = context.findRenderObject()! as RenderBox;
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    // Over the button, as a popup menu button opens its menu.
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final rates = speechRatesWith(rate);
    final chosen = await showMenu<double>(
      context: context,
      position: position,
      semanticLabel: l.speechRate,
      popUpAnimationStyle: Motion.of(context).style,
      initialValue: rates.firstWhere((r) => sameSpeechRate(r, rate)),
      items: [
        for (final r in rates) SeferMenuItem(value: r, child: _RateChoice(rate: r, chosen: sameSpeechRate(r, rate))),
      ],
    );
    if (chosen != null && !sameSpeechRate(chosen, rate)) onRate(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = speechRateLabel(l, rate);
    final style = theme.textTheme.labelLarge!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The icon goes only where the rate would have no room beside it,
        // even set a little smaller (a phone under about 350 dp, large
        // text); the rate itself is set smaller before it is ever cut short.
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final withIcon = constraints.maxWidth >= painter.width * _minLabelScale + _iconExtra;
        painter.dispose();
        final text = Text(
          label,
          maxLines: 1,
          style: style,
          semanticsLabel: l.speechRateValue(label),
        );
        final fitted = FittedBox(fit: BoxFit.scaleDown, child: text);
        final buttonStyle = TextButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          iconColor: scheme.onSurfaceVariant,
          padding: withIcon ? _iconPadding : null,
        );
        return Tooltip(
          message: l.speechRate,
          excludeFromSemantics: true,
          child: Builder(
            // The button's own context, which the menu opens over.
            builder: (context) => TextButton(
              style: buttonStyle,
              onPressed: () => _open(context),
              child: withIcon
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.speed_rounded, size: _iconSize),
                        const SizedBox(width: _iconGap),
                        Flexible(child: fitted),
                      ],
                    )
                  : fitted,
            ),
          ),
        );
      },
    );
  }

  /// The rate beside its icon: closer than a text button with an icon sets
  /// them (12, 18, 8 and 16), so that "Normal" keeps its icon on a 360 dp
  /// phone, where each side of the player has 96. The start stays 12, which
  /// with the player's own 4 brings the icon to the column's edge.
  static const _iconPadding = EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8);
  static const double _iconSize = 18;
  static const double _iconGap = 6;
  static const double _iconExtra = 12 + _iconSize + _iconGap + 8;

  /// How much smaller the rate may be set beside its icon before the icon
  /// goes.
  static const double _minLabelScale = 0.9;
}

/// One rate in the menu, the one chosen marked as a radio button is.
class _RateChoice extends StatelessWidget {
  const _RateChoice({required this.rate, required this.chosen});

  final double rate;
  final bool chosen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: chosen,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            chosen ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 20,
            color: chosen ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(
            speechRateLabel(l, rate),
            style: TextStyle(
              fontWeight: chosen ? FontWeight.w700 : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
