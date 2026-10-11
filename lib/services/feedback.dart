import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../ui/theme/layout.dart';
import '../ui/theme/motion.dart';
import '../ui/widgets/common.dart' show RailPane;

/// Status messages that are both visible and announced to screen readers
/// (WCAG 4.1.3), shown for 4 s, or 8 s when they offer an [action]
/// (docs/DESIGN_SYSTEM.md §6.19). A screen reader user keeps an action's
/// message until they dismiss it.
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
        margin: _wideMargin(context),
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
const _maxWidth = 640.0;

/// A status message's margin from [Breakpoints.medium]: at most [_maxWidth]
/// wide, centred on the page that shows it (within a tab, the pane beside
/// the navigation rail), 16 from the window's foot. Null on a phone, whose
/// messages keep the theme's 16 all round.
EdgeInsets? _wideMargin(BuildContext context) {
  final window = MediaQuery.sizeOf(context);
  // A margin is a floating message's alone.
  final floating = SnackBarTheme.of(context).behavior == SnackBarBehavior.floating;
  if (window.width < Breakpoints.medium || !floating) return null;
  final page = RailPane.rectOf(context) ?? Offset.zero & window;
  const inset = 16.0;
  final width = math.min(_maxWidth, page.width - 2 * inset);
  final start = page.left + (page.width - width) / 2;
  // The message pads itself clear of the window's sides as well.
  final view = MediaQuery.paddingOf(context);
  final left = math.max(0.0, start - view.left);
  final right = math.max(0.0, window.width - start - width - view.right);
  return EdgeInsets.fromLTRB(left, inset, right, inset);
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
