import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../l10n.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
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
/// 320 wide and 40 below the app bar; it scrolls when large text needs it,
/// and with [AlwaysScrollableScrollPhysics] as its [physics] even when it
/// fits, so that it can be pulled to refresh.
class CenteredMessage extends StatelessWidget {
  const CenteredMessage({super.key, required this.text, this.actions = const [], this.physics});

  final String text;
  final List<Widget> actions;
  final ScrollPhysics? physics;

  /// 40 below the app bar, and within the page's sides.
  static const padding = EdgeInsets.fromLTRB(24, 40, 24, 24);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: physics,
      padding: padding,
      child: _Message(text: text, actions: actions),
    );
  }
}

/// Why something couldn't load, in the midst of a page that shows more
/// (DESIGN_SYSTEM.md §6.22, Error state): laid out as an [EmptyState], with
/// Try again under the sentence, and no scrolling of its own. For a page
/// that has nothing else to show, see [ErrorState].
///
/// While it is [retrying], the button's icon turns to a spinner, and the
/// message stays until the outcome, so that nothing moves and the button
/// keeps the keyboard focus. Should it fail again, the message, which looks
/// just as it did, is said again to screen readers.
class ErrorMessage extends StatelessWidget {
  const ErrorMessage({super.key, required this.message, required this.onRetry, this.retrying = false});

  final String message;
  final VoidCallback onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) => _Failure(message: message, onRetry: onRetry, retrying: retrying);
}

/// A page that couldn't load what it shows (DESIGN_SYSTEM.md §6.22, Error
/// state): why, centred under the app bar as a [CenteredMessage], with Try
/// again under it, then any other [actions] as Text buttons. It scrolls even
/// when it fits, so that it can be pulled to refresh in the
/// [RefreshIndicator] the page it stands for has.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.retrying = false,
    this.actions = const [],
  });

  final String message;
  final VoidCallback onRetry;

  /// As [ErrorMessage.retrying].
  final bool retrying;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: CenteredMessage.padding,
        child: _Failure(message: message, onRetry: onRetry, retrying: retrying, actions: actions),
      );
}

/// The message of an [ErrorMessage] or an [ErrorState], with Try again and
/// any other [actions] under it.
class _Failure extends StatefulWidget {
  const _Failure({required this.message, required this.onRetry, required this.retrying, this.actions = const []});

  final String message;
  final VoidCallback onRetry;
  final bool retrying;
  final List<Widget> actions;

  @override
  State<_Failure> createState() => _FailureState();
}

class _FailureState extends State<_Failure> {
  /// How often trying again has failed, where a live region says so.
  int _failedAgain = 0;

  @override
  void didUpdateWidget(_Failure old) {
    super.didUpdateWidget(old);
    // Tried again, and failed again: nothing on the page changes, and the
    // button keeps the focus, so the message is said again, as an
    // announcement, or where the platform takes none (Android) as a live
    // region new each time.
    if (old.retrying && !widget.retrying) {
      if (MediaQuery.supportsAnnounceOf(context)) {
        SemanticsService.sendAnnouncement(View.of(context), widget.message, Directionality.of(context));
      } else {
        _failedAgain++;
      }
    }
  }

  @override
  Widget build(BuildContext context) => _Message(
        text: widget.message,
        live: _failedAgain == 0 ? null : _failedAgain,
        actions: [_RetryButton(onRetry: widget.onRetry, retrying: widget.retrying), ...widget.actions],
      );
}

/// The divider, the sentence and the actions of a [CenteredMessage] and of
/// what couldn't load. The sentence is a live region, new for each value of
/// [live], where it is given.
class _Message extends StatelessWidget {
  const _Message({required this.text, required this.actions, this.live});

  final String text;
  final List<Widget> actions;
  final Object? live;

  @override
  Widget build(BuildContext context) {
    Widget sentence = Text(text, textAlign: TextAlign.center, style: SeferType.of(context).marginalia);
    if (live != null) sentence = Semantics(key: ValueKey(live), container: true, liveRegion: true, child: sentence);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SeferDivider(),
            const Gap(12),
            sentence,
            if (actions.isNotEmpty) ...[
              const Gap(16),
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

/// Try again, a Tonal button with the refresh icon, which turns to a
/// spinner while [retrying].
class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onRetry, required this.retrying});

  final VoidCallback onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final size = Theme.of(context).textTheme.labelLarge?.fontSize ?? 14;
    return FilledButton.tonalIcon(
      style: AppButtons.tonal(context).copyWith(
        // Material's padding for a button with an icon, but where its own
        // leaves nothing above and below large text, 8, so that the label
        // doesn't run into the fill's edges (as AppButtons.roomy).
        padding: WidgetStatePropertyAll(
          ButtonStyleButton.scaledPadding(
            const EdgeInsetsDirectional.fromSTEB(16, 0, 24, 0),
            const EdgeInsetsDirectional.fromSTEB(8, 8, 12, 8),
            const EdgeInsetsDirectional.fromSTEB(4, 8, 6, 8),
            MediaQuery.textScalerOf(context).scale(size) / 14,
          ),
        ),
      ),
      // In the button's ink, as its icon is.
      icon: retrying
          ? Builder(
              builder: (context) => SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: IconTheme.of(context).color,
                  semanticsLabel: l.loading,
                ),
              ),
            )
          : const Icon(Icons.refresh),
      label: Text(l.actionRetry),
      // Enabled while it retries, so that it keeps the keyboard focus;
      // presses meanwhile do nothing.
      onPressed: retrying ? () {} : onRetry,
    );
  }
}

/// What a widget that fails to build shows in its place, in a release or
/// profile build (see [install]), where Flutter's own is a grey box: the
/// surface it lies on, a card's or the page's, left as it is, with
/// "Something on this page didn’t load." centred on it where the line has
/// room, and said to screen readers either way. The error itself reaches
/// `recentErrors` (lib/services/recent_errors.dart) by FlutterError.onError,
/// as every error does, and About offers to copy it for support.
///
/// It stands in a tree that a failure has left in disarray, so, as the
/// framework asks, it does as little as it can and copes with any
/// constraints: it looks up only what has a fallback, and takes its words
/// straight from the app's translations, in the interface's language,
/// rather than through the Localizations it may have failed under.
class AppErrorPanel extends StatelessWidget {
  const AppErrorPanel({super.key});

  /// Has each widget that fails to build show an [AppErrorPanel], but in a
  /// [debug] build, whose red screen says what went wrong.
  static void install({bool debug = kDebugMode}) {
    if (!debug) ErrorWidget.builder = (_) => const AppErrorPanel();
  }

  static const _fontSize = 16.0;
  static const _lineHeight = 24.0;

  /// The least room the sentence is shown in: a row's height, and a few
  /// words' width.
  static const _minHeight = 48.0;
  static const _minWidth = 120.0;

  @override
  Widget build(BuildContext context) {
    final hebrew = Localizations.maybeLocaleOf(context)?.languageCode == 'he';
    final message = lookupAppLocalizations(Locale(hebrew ? 'he' : 'en')).errorPanelMessage;
    // The sentence's own direction, whatever its surroundings'.
    final direction = hebrew ? TextDirection.rtl : TextDirection.ltr;
    final (paper, ink) = _colors(context);
    final scaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final line = scaler.scale(_fontSize) * _lineHeight / _fontSize;
    return Semantics(
      container: true,
      label: message,
      textDirection: direction,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boundedHeight = constraints.hasBoundedHeight;
            // As many lines as fit a bounded height, the last ending in an
            // ellipsis should the sentence need more.
            final lines = boundedHeight ? (constraints.maxHeight / line + 0.001).floor() : null;
            final room = constraints.maxWidth >= _minWidth && constraints.maxHeight >= _minHeight && (lines ?? 1) > 0;
            final sentence = Center(
              widthFactor: 1,
              heightFactor: 1,
              child: room
                  ? Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: boundedHeight ? 0 : 12),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        textDirection: direction,
                        maxLines: lines,
                        overflow: lines == null ? null : TextOverflow.ellipsis,
                        style: TextStyle(
                          inherit: false,
                          color: ink,
                          fontFamily: hebrew ? 'NotoSansHebrew' : 'NotoSans',
                          fontFamilyFallback: hebrew ? const ['NotoSans'] : const ['NotoSansHebrew'],
                          fontSize: _fontSize,
                          height: _lineHeight / _fontSize,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                        ),
                      ),
                    )
                  : null,
            );
            return ConstrainedBox(
              // The whole of a bounded slot; in a list as tall as the line
              // and 12 either side, in a row as wide as it.
              constraints: BoxConstraints(
                minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
                minHeight: boundedHeight ? constraints.maxHeight : 0,
              ),
              child: paper == null ? sentence : ColoredBox(color: paper, child: sentence),
            );
          },
        ),
      ),
    );
  }

  /// The paper the panel paints, if any, and its ink. Within the app's
  /// theme it paints none: the surface it lies on shows through, whatever
  /// paints it (a card, a sheet, a group's row with its hairline, a notice's
  /// wash, the page), so that it is of a piece with it. Its ink is the
  /// theme's, or where the nearest Material beneath is of the other
  /// brightness, as a filled button is, the theme's surface. Above the app's
  /// theme, where nothing else would paint, it paints the light or dark
  /// theme's paper, as the device is set, and writes in its ink.
  static (Color?, Color) _colors(BuildContext context) {
    if (context.findAncestorWidgetOfExactType<Theme>() == null) {
      final scheme = switch (MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light) {
        Brightness.light => Palettes.light,
        Brightness.dark => Palettes.dark,
      };
      return (scheme.surface, scheme.onSurface);
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final beneath = _materialBeneath(context, theme) ?? scheme.surface;
    final brightness = ThemeData.estimateBrightnessForColor;
    return (null, brightness(beneath) == brightness(scheme.surface) ? scheme.onSurface : scheme.surface);
  }

  /// The colour of the nearest Material above [context] that paints one, as
  /// it paints it.
  static Color? _materialBeneath(BuildContext context, ThemeData theme) {
    Color? found;
    context.visitAncestorElements((element) {
      if (element.widget case final Material material when material.type != MaterialType.transparency) {
        final color = material.color ??
            switch (material.type) {
              MaterialType.canvas => theme.canvasColor,
              MaterialType.card => theme.cardColor,
              _ => null,
            };
        if (color != null && color.a > 0) {
          found = ElevationOverlay.applySurfaceTint(color, material.surfaceTintColor, material.elevation);
        }
      }
      return found == null;
    });
    return found;
  }
}

/// The page for a link that leads nowhere in the app: a mistyped or outdated
/// web address, say, or one to a week or a policy that doesn't exist.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PageScaffold(
      titleText: l.notFoundTitle,
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
