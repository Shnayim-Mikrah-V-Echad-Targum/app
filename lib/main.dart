import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/start_failure.dart';
import 'app/system_bars.dart';
import 'data/parsha_repository.dart';
import 'features/community/data/backend.dart';
import 'services/app_shortcuts.dart';
import 'services/home_widget_sync.dart';
import 'services/notifications.dart';
import 'services/optional_fonts.dart';
import 'services/preferences_recovery.dart';
import 'services/recent_errors.dart';
import 'ui/widgets/fallbacks.dart';

Future<void> main() async {
  // The web engine never hands PlatformDispatcher.onError the errors that no
  // code caught, as the other platforms do (recordRecentErrors), so there the
  // app runs in a zone of its own that keeps them; the binding is set up and
  // the app run within it, so that both are in the same zone.
  if (kIsWeb) return runZonedGuarded(_start, keepUncaughtError);
  await _start();
}

Future<void> _start() async {
  // On the web, pages have addresses of their own (…/community/thread/1),
  // which can be shared; web/index.html moves an older link's #/ there.
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  // What goes wrong is kept, for About to copy for support; and a widget
  // that fails shows a calm panel rather than a grey box.
  recordRecentErrors();
  AppErrorPanel.install();
  _registerFontLicenses();
  unawaited(enableEdgeToEdge());

  // Independent of one another, so they all start at once.
  final (SharedPreferences, ParshaRepository, Backend, NotificationService, AppShortcutsService, HomeWidgetService)
      services;
  try {
    services = await (
      _reported(_preferencesWithFonts(), 'opening the stored preferences'),
      _reported(ParshaRepository.load(), 'loading the parshiyot'),
      _reported(Backend.initialize(), 'starting the community'),
      _reported(NotificationService.create(), 'starting reminders'),
      _reported(AppShortcutsService.create(), 'starting the shortcuts on the app icon'),
      _reported(HomeWidgetService.create(), 'starting the home-screen widget'),
    ).wait;
  } on ParallelWaitError {
    // Something the app can't open without failed, even once the
    // preferences had their chance to recover (openPreferences): on the web,
    // say, a first visit's data lost to a dropped connection. It says so, as
    // a frame of its own: with no frame at all, Windows would keep the
    // window hidden and the web its loading screen. Each error was reported
    // as it came, for the page to copy.
    runApp(const StartFailureApp());
    if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
    return;
  }
  final (prefs, parshiyot, backend, notifications, shortcuts, homeWidget) = services;

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      parshaRepositoryProvider.overrideWithValue(parshiyot),
      backendProvider.overrideWithValue(backend),
      notificationServiceProvider.overrideWithValue(notifications),
      appShortcutsServiceProvider.overrideWithValue(shortcuts),
      homeWidgetServiceProvider.overrideWithValue(homeWidget),
    ],
    child: const ShnayimMikrahApp(),
  ));

  // Flutter web builds its accessibility tree only on request; turn it on so
  // screen reader users never have to find the hidden "enable" button.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
}

/// [future], whose error, should it fail, is reported as it comes, as one
/// met while [doing] what it does, rather than only as one of the start-up's
/// (a ParallelWaitError, which tells of the first alone).
Future<T> _reported<T>(Future<T> future, String doing) => future.catchError((Object error, StackTrace stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'start-up',
        context: ErrorDescription('while $doing'),
      ));
      Error.throwWithStackTrace(error, stack);
    });

/// The stored preferences, whatever has become of them (openPreferences),
/// once the opt-in fonts their settings choose have loaded, so that the first
/// frame already shows text in them. A font slow to arrive (over the web)
/// holds the app back only so long; its text is laid out again when it comes.
/// The fonts are a nicety: nothing about them keeps the app from starting.
Future<SharedPreferences> _preferencesWithFonts() async {
  final prefs = await openPreferences();
  try {
    final settings = SettingsController.readStored(prefs);
    await OptionalFonts.ensureAll(settings.optionalFonts).timeout(const Duration(seconds: 2));
  } on TimeoutException {
    // Still loading: the first frame is drawn in the fallback fonts.
  } catch (e, stack) {
    FlutterError.reportError(FlutterErrorDetails(exception: e, stack: stack, library: 'optional fonts'));
  }
  return prefs;
}

void _registerFontLicenses() {
  const fonts = {
    'Noto Serif Hebrew': 'NotoSerifHebrew-OFL.txt',
    'Noto Sans Hebrew': 'NotoSansHebrew-OFL.txt',
    'Noto Sans': 'NotoSans-OFL.txt',
    'EB Garamond': 'EBGaramond-OFL.txt',
    'Frank Ruhl Libre': 'FrankRuhlLibre-OFL.txt',
    'Noto Rashi Hebrew': 'NotoRashiHebrew-OFL.txt',
    'Atkinson Hyperlegible Next': 'AtkinsonHyperlegibleNext-OFL.txt',
    'Lexend': 'Lexend-OFL.txt',
    'OpenDyslexic': 'OpenDyslexic-OFL.txt',
    'Ezra SIL': 'EzraSIL-OFL.txt',
    'Taamey Frank CLM': 'TaameyFrankCLM-LICENSE.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: name, value: file) in fonts.entries) {
      yield LicenseEntryWithLineBreaks(
        [name],
        await rootBundle.loadString('assets/fonts/licenses/$file'),
      );
    }
    yield LicenseEntryWithLineBreaks(
      ['Taamey Frank CLM'],
      await rootBundle.loadString('assets/fonts/licenses/GPL-2.0.txt'),
    );
  });
}
