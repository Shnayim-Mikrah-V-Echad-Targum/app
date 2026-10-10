import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

void main() {
  for (final language in [AppLanguage.english, AppLanguage.hebrew]) {
    testWidgets('About names the app in Hebrew, and in the English interface also as read in English (${language.name})',
        (tester) async {
      final c = await pumpApp(tester, settings: AppSettings(onboardingComplete: true, language: language));
      c.read(routerProvider).go('/settings/about');
      await tester.pumpAndSettle();
      expect(find.text('שניים מקרא ואחד תרגום'), findsOneWidget, reason: 'never twice in the Hebrew interface');
      expect(find.text("Shnayim Mikra v'Echad Targum"), language == AppLanguage.english ? findsOneWidget : findsNothing);
    });
  }
}
