import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// On Windows, the mouse's back button, Alt+← and a keyboard's Back key go
/// back, as they do in Windows's own apps and its browsers. Android has the
/// system's Back, and on the web the browser keeps these for its history.
///
/// Alt+← stays a text field's own while one has the focus: there it moves the
/// caret to the start of the line.
class WindowsBack extends StatefulWidget {
  const WindowsBack({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  /// Whether the app binds them: in the Windows app alone.
  static bool get applies => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  State<WindowsBack> createState() => _WindowsBackState();
}

class _WindowsBackState extends State<WindowsBack> {
  late final _actions = <Type, Action<Intent>>{_BackIntent: _BackAction(() => widget.router)};

  @override
  Widget build(BuildContext context) {
    if (!WindowsBack.applies) return widget.child;
    return Listener(
      // Over anything, without taking the press from it.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse && event.buttons & kBackMouseButton != 0) {
          unawaited(goBack(widget.router));
        }
      },
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true, includeRepeats: false): _BackIntent(yieldsToText: true),
          SingleActivator(LogicalKeyboardKey.browserBack, includeRepeats: false): _BackIntent(),
        },
        child: Actions(actions: _actions, child: widget.child),
      ),
    );
  }
}

/// Goes back as the system's Back does: it closes a sheet, a dialog or a
/// page, a page's own scope first, and from the root of another tab it
/// returns to Today. On Today's root, and on the welcome, there is nothing to
/// go back to, and it leaves the app open. A page reached with nowhere to go
/// back to returns to Today.
Future<void> goBack(GoRouter router) async {
  final path = router.state.uri.path;
  if (!router.canPop() && (path == '/today' || path == '/welcome' || path.startsWith('/welcome/'))) return;
  if (!await router.routerDelegate.popRoute()) router.go('/today');
}

class _BackIntent extends Intent {
  const _BackIntent({this.yieldsToText = false});

  /// Whether a focused text field keeps the key.
  final bool yieldsToText;
}

class _BackAction extends Action<_BackIntent> {
  _BackAction(this.router);

  final GoRouter Function() router;

  @override
  bool isEnabled(_BackIntent intent) =>
      !intent.yieldsToText ||
      FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() == null;

  @override
  void invoke(_BackIntent intent) => unawaited(goBack(router()));
}
