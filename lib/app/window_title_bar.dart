import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/l10n.dart';

/// The Windows runner's window (windows/runner/flutter_window.cpp).
const windowChannel = MethodChannel('shnayim/window');

/// Keeps the Windows title bar dark or light with the app's theme, which may
/// differ from the system's: choosing Dark in the app darkens the title bar
/// too. The runner starts the title bar with the system's app theme and
/// leaves it alone after that; elsewhere, [SystemBars] styles the system's
/// bars, or the platform draws none.
///
/// The window's title, which the taskbar and Alt+Tab show too, is the app's
/// name in its language: the runner opens the window as "Shnayim Mikra".
class WindowTitleBar extends StatefulWidget {
  const WindowTitleBar({super.key, required this.child});

  final Widget child;

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> {
  /// The brightness last sent to the runner.
  Brightness? _sent;

  /// The title last sent to the runner.
  String? _sentTitle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
    // An animated theme change flips the brightness halfway through.
    final brightness = Theme.of(context).brightness;
    if (brightness != _sent) {
      _sent = brightness;
      unawaited(setDarkTitleBar(brightness == Brightness.dark));
    }
    final title = context.l10n.appTitle;
    if (title != _sentTitle) {
      _sentTitle = title;
      unawaited(setWindowTitle(title));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Draws the Windows title bar dark or light.
Future<void> setDarkTitleBar(bool dark) async {
  try {
    await windowChannel.invokeMethod<void>('setDarkTitleBar', dark);
  } on MissingPluginException {
    // A runner without the channel keeps the system's theme.
  } on PlatformException catch (e) {
    debugPrint('Title bar theme unavailable: $e');
  }
}

/// Sets the Windows window's title.
Future<void> setWindowTitle(String title) async {
  try {
    await windowChannel.invokeMethod<void>('setTitle', title);
  } on MissingPluginException {
    // A runner without the channel keeps the title it opened with.
  } on PlatformException catch (e) {
    debugPrint('Window title unavailable: $e');
  }
}
