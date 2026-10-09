import 'package:shnayim_mikra/features/settings/app_settings.dart';

/// The screens the accessibility tests visit.
const a11yRoutes = [
  '/today',
  '/parsha',
  '/parsha/browse',
  '/progress',
  '/community',
  '/settings',
  '/settings/reading',
  '/settings/display',
  '/settings/accessibility',
  '/settings/reminders',
  '/settings/about',
  '/guide',
];

/// A reading-week Monday, so Today shows a reading prompt.
final a11yMonday = DateTime(2026, 10, 12, 10);

const a11ySettings = AppSettings(onboardingComplete: true);
