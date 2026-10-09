import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/parsha_repository.dart';
import 'features/community/data/backend.dart';
import 'services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();

  final prefs = await SharedPreferences.getInstance();
  final parshiyot = await ParshaRepository.load();
  final backend = await Backend.initialize();
  final notifications = await NotificationService.create();

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      parshaRepositoryProvider.overrideWithValue(parshiyot),
      backendProvider.overrideWithValue(backend),
      notificationServiceProvider.overrideWithValue(notifications),
    ],
    child: const ShnayimMikraApp(),
  ));

  // Flutter web builds its accessibility tree only on request; turn it on so
  // screen reader users never have to find the hidden "enable" button.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
}

void _registerFontLicenses() {
  const fonts = {
    'Noto Serif Hebrew': 'NotoSerifHebrew-OFL.txt',
    'Noto Sans Hebrew': 'NotoSansHebrew-OFL.txt',
    'Noto Sans': 'NotoSans-OFL.txt',
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
