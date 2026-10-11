import 'package:flutter/widgets.dart';

/// For a page that sets its heading in its body, as a title page does: tracks
/// whether the heading has scrolled under the app bar, which then shows the
/// title itself (`PageScaffold.titleRevealed`).
///
/// Give the heading [headingKey], pass [headingHidden] as `titleRevealed`,
/// and put [onPageScroll] in a `NotificationListener<ScrollNotification>`
/// around the page's scroll view.
mixin HeadingReveal<T extends StatefulWidget> on State<T> {
  /// The heading at the head of the page.
  final headingKey = GlobalKey();

  /// Whether the heading has scrolled out of view, under the app bar.
  bool headingHidden = false;

  /// Whether a look at the heading is due after the next frame.
  bool _checkDue = false;

  bool onPageScroll(ScrollNotification notification) {
    if (notification.depth != 0 || _checkDue) return false;
    // Once the frame has laid the page out at its new offset.
    _checkDue = true;
    final viewport = notification.context;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDue = false;
      if (!mounted || viewport == null || !viewport.mounted) return;
      final heading = headingKey.currentContext?.findRenderObject() as RenderBox?;
      final view = viewport.findRenderObject() as RenderBox?;
      if (heading == null || view == null || !heading.attached || !view.attached) return;
      final hidden = heading.localToGlobal(Offset(0, heading.size.height)).dy <= view.localToGlobal(Offset.zero).dy;
      if (hidden != headingHidden) setState(() => headingHidden = hidden);
    });
    return false;
  }
}
