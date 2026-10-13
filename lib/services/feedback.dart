import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../ui/theme/layout.dart';
import '../ui/theme/motion.dart';

/// Status messages that are both visible and announced to screen readers
/// (WCAG 4.1.3), shown for 4 s, or 8 s when they offer an [action]
/// (docs/DESIGN_SYSTEM.md §6.19). Each page shows it as its
/// [StatusMessageArea] sets it, wherever it was shown from.
///
/// A message with an action is held, with a Close button, for screen-reader
/// users and while focus is shown for the keyboard (WCAG 2.2.1): on a
/// desktop, or in a desktop's browser, until a touch, and on a phone or
/// tablet once a key is pressed. A desktop doesn't tell the app that a
/// screen reader is on, and the keyboard takes a while to reach the action.
/// Otherwise it leaves after 8 s. A held message leaves as the page that
/// showed it is left (popped, covered by another page, or hidden with its
/// tab): its action, an Undo say, is about what was done there, and could
/// undo more by the time it was pressed elsewhere. Unless it
/// [outlivesPage], as one shown by a page as it closes, about what it did.
void showStatus(BuildContext context, String message, {SnackBarAction? action, bool outlivesPage = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger != null) {
    final reduced = Motion.of(context).reduced;
    // Without motion the last message goes at once (so does one that was
    // shown without motion). Either way it is gone before a changed setting
    // makes showSnackBar replace the animation controller it runs on.
    _dismissCurrent(messenger, reduced: reduced);
    // One that stays goes as the next is shown, above.
    final persist = action != null &&
        (MediaQuery.accessibleNavigationOf(context) ||
            FocusManager.instance.highlightMode == FocusHighlightMode.traditional);
    // The page that showed it. A sheet or a dialog closing as it shows it
    // has it held, as before, rather than gone at once.
    final page = ModalRoute.of(context);
    final content = Text(message);
    final shown = messenger.showSnackBar(
      SnackBar(
        content: persist && !outlivesPage && page is PageRoute
            ? _LeavesWithPage(page: page, shown: TickerMode.getValuesNotifier(context), child: content)
            : content,
        action: action,
        duration: Duration(seconds: action == null ? 4 : 8),
        persist: persist,
        showCloseIcon: persist,
      ),
      // Always named, so the messenger keeps one animation controller for as
      // long as the setting doesn't change.
      snackBarAnimationStyle: reduced ? AnimationStyle.noAnimation : _snackBarMotion,
    );
    _shown[messenger] = (_shown[messenger] ?? 0) + 1;
    shown.closed.whenComplete(() => _shown[messenger] = (_shown[messenger] ?? 1) - 1);
  }
  // The SnackBar is a live region, which Android, iOS and the web read out
  // by themselves (Flutter's iOS engine announces a node that becomes a
  // live region). Windows and macOS take an announcement instead, sent only
  // there so that the message is spoken once.
  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.iOS && MediaQuery.supportsAnnounceOf(context)) {
    SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
  }
}

/// How many status messages each messenger has on show: one, but for the
/// moment one leaves as the next comes.
final _shown = Expando<int>('status messages shown');

/// Whether a status message is on show to [context]'s page, from its first
/// frame until it has gone.
bool statusMessageShown(BuildContext context) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  return messenger != null && (_shown[messenger] ?? 0) > 0;
}

/// A held message's content, which takes the message away once [page] is
/// no longer on show: popped, covered by another page, or hidden with its
/// tab ([shown], its tickers, stopped). Every page's Scaffold shows the
/// message, and each copy watches the page that showed it.
class _LeavesWithPage extends StatefulWidget {
  const _LeavesWithPage({required this.page, required this.shown, required this.child});

  final ModalRoute<Object?> page;
  final ValueListenable<TickerModeData> shown;
  final Widget child;

  @override
  State<_LeavesWithPage> createState() => _LeavesWithPageState();
}

class _LeavesWithPageState extends State<_LeavesWithPage> {
  bool _leaving = false;

  bool get _onShow {
    final page = widget.page;
    return (page.animation?.isForwardOrCompleted ?? false) &&
        (page.secondaryAnimation?.isDismissed ?? true) &&
        widget.shown.value.enabled;
  }

  @override
  void initState() {
    super.initState();
    widget.page.animation?.addStatusListener(_statusChanged);
    widget.page.secondaryAnimation?.addStatusListener(_statusChanged);
    widget.shown.addListener(_check);
    // Shown on a page that has been left already, as a copy on the page
    // beneath one being popped is.
    _check();
  }

  @override
  void dispose() {
    widget.page.animation?.removeStatusListener(_statusChanged);
    widget.page.secondaryAnimation?.removeStatusListener(_statusChanged);
    widget.shown.removeListener(_check);
    super.dispose();
  }

  void _statusChanged(AnimationStatus _) => _check();

  void _check() {
    if (_leaving || _onShow) return;
    _leaving = true;
    // After the frame: the tickers' notice comes as the page rebuilds.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    var messages = statusMessageTheme(
      base,
      windowWidth: MediaQuery.sizeOf(context).width,
      width: width,
      padding: MediaQuery.paddingOf(context),
    );
    // Material weighs the action against the message's width at its
    // unscaled size; enlarged, it takes that much more of the line.
    final threshold = messages.actionOverflowThreshold;
    final scale = MediaQuery.textScalerOf(context).scale(_actionFontSize) / _actionFontSize;
    if (threshold != null && scale > 1) messages = messages.copyWith(actionOverflowThreshold: threshold / scale);
    return _StatusMessageBase(
      theme: base,
      child: Theme(data: messages == theme.snackBarTheme ? theme : theme.copyWith(snackBarTheme: messages), child: child),
    );
  }
}

/// labelLarge's size, an action's, for the text scale it is set at.
const _actionFontSize = 14.0;

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

// Haptics, in three levels, each firmer than the last (docs/DESIGN_SYSTEM.md
// §8, Haptics): at most one for a press, and none for what happens by
// itself. They are a phone's and a tablet's: none on the web or a desktop,
// or once the user has turned Haptic feedback off. Android and iOS keep to
// their own setting too, and play nothing where it is off.

/// A step: Next, on to the next reading. The faintest, a selection tick
/// (Android's CLOCK_TICK).
void hapticStep(WidgetRef ref) {
  if (_hapticPlatform(ref) != null) HapticFeedback.selectionClick();
}

/// Reading recorded: an aliyah finished or marked read, a check-in or the
/// haftarah logged. A click, firmer than a step's tick; on Android
/// lightImpact (VIRTUAL_KEY), as mediumImpact plays the same click there.
void hapticSuccess(WidgetRef ref) => switch (_hapticPlatform(ref)) {
      TargetPlatform.iOS => HapticFeedback.mediumImpact(),
      TargetPlatform.android => HapticFeedback.lightImpact(),
      _ => null,
    };

/// A parsha or a book finished, once: iOS's success notification, and on
/// Android a long press's heavy click (heavyImpact plays a tick there,
/// lighter than a success's click).
void hapticCelebrate(WidgetRef ref) => switch (_hapticPlatform(ref)) {
      TargetPlatform.iOS => HapticFeedback.successNotification(),
      TargetPlatform.android => HapticFeedback.vibrate(),
      _ => null,
    };

/// The platform whose haptics play, if any do: Android or iOS, with Haptic
/// feedback on.
TargetPlatform? _hapticPlatform(WidgetRef ref) {
  if (kIsWeb || !ref.read(settingsProvider).haptics) return null;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => defaultTargetPlatform,
    _ => null,
  };
}
