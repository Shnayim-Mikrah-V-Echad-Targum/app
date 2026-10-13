import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../features/settings/app_settings.dart';

/// MainActivity's (android/app/src/main/kotlin/org/shnayimmikrah/shnayim_mikrah/MainActivity.kt).
const uiModeChannel = MethodChannel('shnayim_mikrah/ui_mode');

/// Whether the app runs on Android, where it holds the system's night mode
/// for itself to its theme ([setAndroidNightMode]).
bool get holdsAndroidNightMode => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// The night mode Android holds the app in for [theme]: 'yes' for the dark
/// themes, 'no' for the light ones, and 'auto', the system's own, when the
/// app follows it.
String androidNightMode(AppThemeMode theme) => switch (theme) {
      AppThemeMode.system => 'auto',
      AppThemeMode.dark || AppThemeMode.highContrastDark => 'yes',
      AppThemeMode.light || AppThemeMode.sepia || AppThemeMode.highContrastLight => 'no',
    };

/// Asks Android to hold the app in night [mode] ([androidNightMode]). From
/// Android 12, which keeps it for the app, the launch screen drawn on a cold
/// start is then the theme's, dark for a reader who chose Dark on a light
/// phone, and nothing changes colour between it and the first frame
/// (docs/DESIGN_SYSTEM.md §3.6). Earlier versions ignore it.
Future<void> setAndroidNightMode(String mode) async {
  try {
    await uiModeChannel.invokeMethod<void>('setNightMode', mode);
  } on MissingPluginException {
    // An activity without the channel keeps the system's launch screen.
  } on PlatformException catch (e) {
    debugPrint('Night mode unavailable: $e');
  }
}
