import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/system_bars.dart';
import 'data/parsha_repository.dart';
import 'features/community/data/backend.dart';
import 'services/app_shortcuts.dart';
import 'services/notifications.dart';
import 'services/optional_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  unawaited(enableEdgeToEdge());

  // Independent of one another, so they all start at once.
  final (prefs, parshiyot, backend, notifications, shortcuts) = await (
    _preferencesWithFonts(),
    ParshaRepository.load(),
    Backend.initialize(),
    NotificationService.create(),
    AppShortcutsService.create(),
  ).wait;

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      parshaRepositoryProvider.overrideWithValue(parshiyot),
      backendProvider.overrideWithValue(backend),
      notificationServiceProvider.overrideWithValue(notifications),
      appShortcutsServiceProvider.overrideWithValue(shortcuts),
    ],
    child: const ShnayimMikraApp(),
  ));

  // Flutter web builds its accessibility tree only on request; turn it on so
  // screen reader users never have to find the hidden "enable" button.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
}

/// The stored preferences, once the opt-in fonts their settings choose have
/// loaded, so that the first frame already shows text in them. A font slow to
/// arrive (over the web) holds the app back only so long; its text is laid
/// out again when it comes.
Future<SharedPreferences> _preferencesWithFonts() async {
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController.readStored(prefs);
  await OptionalFonts.ensureAll(settings.optionalFonts)
      .timeout(const Duration(seconds: 2), onTimeout: () {});
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
