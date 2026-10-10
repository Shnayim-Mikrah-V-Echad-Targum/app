import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../ui/theme/motion.dart';

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
    reduced ? messenger.removeCurrentSnackBar() : messenger.hideCurrentSnackBar();
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
  // Android announces SnackBars through their live region; other platforms
  // need an explicit announcement.
  if (MediaQuery.supportsAnnounceOf(context)) {
    SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
  }
}

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
