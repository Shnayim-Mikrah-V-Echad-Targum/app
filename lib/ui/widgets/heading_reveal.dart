import 'package:flutter/widgets.dart';

/// For a page that sets its heading in its body, as a title page does: tracks
/// whether the heading has scrolled under the app bar, which then shows the
/// title itself (`PageScaffold.titleRevealed`).
///
/// Give the heading [headingKey], pass [headingHidden] as `titleRevealed`,
/// and wrap the page's scroll view in [watchHeading].
mixin HeadingReveal<T extends StatefulWidget> on State<T> {
  /// The heading at the head of the page.
  final headingKey = GlobalKey();

  /// Whether the heading has scrolled out of view, under the app bar.
  bool headingHidden = false;

  /// Whether a look at the heading is due after the next frame.
  bool _checkDue = false;

  /// [page], its heading looked at again whenever it scrolls, and whenever
  /// its size or its content's changes without a scroll: a resized window,
  /// say, or larger text, which can bring the heading back into view or
  /// take it out.
  Widget watchHeading(Widget page) => NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => _look(n.depth, n.context),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => _look(n.depth, n.context),
          child: page,
        ),
      );

  bool _look(int depth, BuildContext? viewport) {
    if (depth != 0 || _checkDue) return false;
    // Once the frame has laid the page out at its new offset.
    _checkDue = true;
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
