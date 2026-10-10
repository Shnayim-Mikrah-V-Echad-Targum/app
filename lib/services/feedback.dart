import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

/// Status messages that are both visible and announced to screen readers
/// (WCAG 4.1.3).
void showStatus(BuildContext context, String message, {SnackBarAction? action}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(content: Text(message), action: action));
  // The SnackBar is a live region, which Android, iOS and the web read out
  // by themselves (Flutter's iOS engine announces a node that becomes a
  // live region). Windows and macOS take an announcement instead, sent only
  // there so that the message is spoken once.
  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.iOS && MediaQuery.supportsAnnounceOf(context)) {
    SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
  }
}

/// A status message said to screen readers without being shown, for a
/// moment when a SnackBar would cover what the user has come back to, such
/// as the reply box they signed in for; any message still shown goes too.
/// Where the platform takes no announcements (Android), it is shown after
/// all: its live region is the only way to say it.
void announceStatus(BuildContext context, String message) {
  if (MediaQuery.supportsAnnounceOf(context)) {
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
  } else {
    showStatus(context, message);
  }
}

/// Light haptic feedback, if the user hasn't turned it off.
void hapticTap(WidgetRef ref) {
  if (ref.read(settingsProvider).haptics) HapticFeedback.lightImpact();
}

void hapticSuccess(WidgetRef ref) {
  if (ref.read(settingsProvider).haptics) HapticFeedback.mediumImpact();
}
