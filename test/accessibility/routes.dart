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
  '/settings/data',
  '/settings/about',
  '/settings/account',
  '/guide',
  '/sources',
  '/legal/privacy',
  // A week within a tab, under its navigation bar.
  '/parsha/week/5787:2',
  // Opened directly, as on a web reload: with a home button.
  '/week/5787:1',
  // Links that lead nowhere.
  '/nope',
  '/community/forum/xyz',
];

/// The welcome and the steps of onboarding, visited before it is done, and
/// signing in from the welcome to restore a backup. On [a11yMonday] the plan
/// step also asks about the week of joining.
const a11yOnboardingRoutes = ['/welcome', '/welcome/location', '/welcome/method', '/welcome/plan', '/welcome/account'];

/// A reading-week Monday, so Today shows a reading prompt.
final a11yMonday = DateTime(2026, 10, 12, 10);

const a11ySettings = AppSettings(onboardingComplete: true);

/// All three reminders on, for the reminders page as a phone shows it, where
/// they can be scheduled (with PhoneNotifications from test/helpers.dart).
const a11yRemindersOn =
    AppSettings(onboardingComplete: true, dailyReminder: true, fridayReminder: true, checkInReminder: true);
