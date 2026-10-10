import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Draws the app behind the status and navigation bars on Android 10 and
/// later, as Android 15 and later require anyway; [SystemBars] keeps the bars
/// transparent over it. iOS always draws edge to edge.
Future<void> enableEdgeToEdge() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

/// Styles the system bars for the app's theme, wherever an app bar doesn't
/// style the status bar itself (see [systemBarsStyle]).
class SystemBars extends StatelessWidget {
  const SystemBars({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A navigation bar over the app leaves its inset in the view padding:
    // at the bottom, or at a side on a phone held sideways.
    final inset = MediaQuery.viewPaddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBarsStyle(
        Theme.of(context),
        behindNavigationBar: inset.bottom > 0 || inset.left > 0 || inset.right > 0,
      ),
      child: child,
    );
  }
}

/// The system bars over [theme]: transparent, so the app's own surface runs
/// beneath them, with icons that contrast with it. The launch themes
/// (android/app/src/main/res/values*/styles.xml) start the bars the same way,
/// so nothing changes when the first frame arrives.
///
/// On the [web], the status bar's colour is the page's theme-color: the
/// browser's toolbar, or the installed app's title bar. There it is the
/// surface, as MaterialApp's color is; a transparent one would turn it black.
///
/// Android 9 and earlier can't draw an app beneath the navigation bar, so
/// unless the app is [behindNavigationBar], the bar is painted the theme's
/// surface colour: what shows through a transparent one is the window's
/// background, which follows the system's dark mode rather than the app's
/// theme. (Flutter can't style that bar at all before Android 8.0, and a
/// theme can give it dark icons only from 8.1, so until then the light launch
/// theme keeps it black.)
SystemUiOverlayStyle systemBarsStyle(ThemeData theme, {required bool behindNavigationBar, bool web = kIsWeb}) {
  final icons = theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: web ? theme.colorScheme.surface : Colors.transparent,
    statusBarIconBrightness: icons,
    // iOS asks for the brightness of what lies behind the status bar instead.
    statusBarBrightness: theme.brightness,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: behindNavigationBar ? Colors.transparent : theme.colorScheme.surface,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: icons,
    // No translucent scrim behind three-button navigation.
    systemNavigationBarContrastEnforced: false,
  );
}
