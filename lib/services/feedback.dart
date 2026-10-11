import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../ui/theme/layout.dart';
import '../ui/theme/motion.dart';

/// Status messages that are both visible and announced to screen readers
/// (WCAG 4.1.3), shown for 4 s, or 8 s when they offer an [action]
/// (docs/DESIGN_SYSTEM.md §6.19). A screen reader user keeps an action's
/// message until they dismiss it. Each page shows it as its
/// [StatusMessageArea] sets it, wherever it was shown from.
void showStatus(BuildContext context, String message, {SnackBarAction? action}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger != null) {
    final reduced = Motion.of(context).reduced;
    // Without motion the last message goes at once (so does one that was
    // shown without motion). Either way it is gone before a changed setting
    // makes showSnackBar replace the animation controller it runs on.
    _dismissCurrent(messenger, reduced: reduced);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: Duration(seconds: action == null ? 4 : 8),
        persist: action != null && MediaQuery.accessibleNavigationOf(context),
      ),
      // Always named, so the messenger keeps one animation controller for as
      // long as the setting doesn't change.
      snackBarAnimationStyle: reduced ? AnimationStyle.noAnimation : _snackBarMotion,
    );
  }
  // The SnackBar is a live region, which Android, iOS and the web read out
  // by themselves (Flutter's iOS engine announces a node that becomes a
  // live region). Windows and macOS take an announcement instead, sent only
  // there so that the message is spoken once.
  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.iOS && MediaQuery.supportsAnnounceOf(context)) {
    SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
  }
}

/// The widest a status message is set from [Breakpoints.medium]: a sheet's
/// width (§6.19), rather than a line across a desktop's whole window.
const statusMessageMaxWidth = 640.0;

/// The theme of the status messages shown by a page (a Scaffold) [width]
/// wide, in a window [windowWidth] wide, whose sides the safe area insets by
/// [padding]: from [Breakpoints.medium], at most [statusMessageMaxWidth]
/// wide and centred on the page. On a phone, or on a page with no room for
/// that, [theme] as it is: its margin all round, within the safe area.
SnackBarThemeData statusMessageTheme(
  SnackBarThemeData theme, {
  required double windowWidth,
  required double width,
  required EdgeInsets padding,
}) {
  final margin = theme.insetPadding ?? const EdgeInsets.all(16);
  final safe = width - padding.horizontal;
  // A width or a margin is a floating message's alone.
  if (windowWidth < Breakpoints.medium ||
      theme.behavior != SnackBarBehavior.floating ||
      safe - margin.horizontal <= statusMessageMaxWidth) {
    return theme;
  }
  // With nothing at the page's sides, as on a desktop, a width, which the
  // page centres. The theme then stays the same as the window is resized,
  // where a margin would change, and rebuild the page, with every width.
  if (padding.left == 0 && padding.right == 0) return theme.copyWith(width: statusMessageMaxWidth);
  // Otherwise a margin, which the message sets within the safe area, so the
  // sides of the safe area come off it: centred on the page where the
  // safe area leaves room, and else as near as it does.
  final left = ((width - statusMessageMaxWidth) / 2 - padding.left)
      .clamp(margin.left, safe - statusMessageMaxWidth - margin.right);
  final right = safe - statusMessageMaxWidth - left;
  return theme.copyWith(insetPadding: EdgeInsets.fromLTRB(left, margin.top, right, margin.bottom));
}

/// Sets the status messages that the pages within [child] show
/// ([statusMessageTheme]): pages as wide as the window ([window]), the
/// reader and the others over the tabs; or as wide as [child] is laid out
/// ([pane]), the pages of a tab, beside the navigation rail. Each page
/// shows a message in its own Scaffold, so that it is placed by what it is
/// shown over, and is set again as the window is resized.
class StatusMessageArea extends StatelessWidget {
  const StatusMessageArea.window({super.key, required this.child}) : _pane = false;
  const StatusMessageArea.pane({super.key, required this.child}) : _pane = true;

  final Widget child;
  final bool _pane;

  @override
  Widget build(BuildContext context) => _pane
      ? LayoutBuilder(builder: (context, constraints) => _themed(context, constraints.maxWidth))
      : _themed(context, MediaQuery.sizeOf(context).width);

  Widget _themed(BuildContext context, double width) {
    final theme = Theme.of(context);
    // Set from the app's own theme, rather than from what an area around
    // this one (the window's, around the pane's) made of it.
    final base = context.dependOnInheritedWidgetOfExactType<_StatusMessageBase>()?.theme ?? theme.snackBarTheme;
    final messages = statusMessageTheme(
      base,
      windowWidth: MediaQuery.sizeOf(context).width,
      width: width,
      padding: MediaQuery.paddingOf(context),
    );
    return _StatusMessageBase(
      theme: base,
      child: Theme(data: messages == theme.snackBarTheme ? theme : theme.copyWith(snackBarTheme: messages), child: child),
    );
  }
}

/// The app's own theme for status messages, under a [StatusMessageArea].
class _StatusMessageBase extends InheritedWidget {
  const _StatusMessageBase({required this.theme, required super.child});

  final SnackBarThemeData theme;

  @override
  bool updateShouldNotify(_StatusMessageBase old) => theme != old.theme;
}

/// A status message said to screen readers without being shown, for a
/// moment when a SnackBar would cover what the user has come back to, such
/// as the reply box they signed in for; any message still shown goes too.
/// Where the platform takes no announcements (Android), it is shown after
/// all: its live region is the only way to say it.
void announceStatus(BuildContext context, String message) {
  if (MediaQuery.supportsAnnounceOf(context)) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) _dismissCurrent(messenger, reduced: Motion.of(context).reduced);
    SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
  } else {
    showStatus(context, message);
  }
}

/// Takes the current message away: at once without motion, otherwise with
/// its exit animation.
void _dismissCurrent(ScaffoldMessengerState messenger, {required bool reduced}) =>
    reduced ? messenger.removeCurrentSnackBar() : messenger.hideCurrentSnackBar();

// Material's own snack bar timing, stated so it compares equal from one
// message to the next.
const _snackBarMotion = AnimationStyle(duration: Motion.medium);

/// Light haptic feedback, if the user hasn't turned it off.
void hapticTap(WidgetRef ref) {
  if (ref.read(settingsProvider).haptics) HapticFeedback.lightImpact();
}

void hapticSuccess(WidgetRef ref) {
  if (ref.read(settingsProvider).haptics) HapticFeedback.mediumImpact();
}
