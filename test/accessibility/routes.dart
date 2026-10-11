import 'package:shnayim_mikra/features/settings/app_settings.dart';

/// The screens the accessibility tests visit.
const a11yRoutes = [
  '/today',
  '/parsha',
  '/parsha/browse',
  '/progress',
  '/community',
  '/community/new',
  // A discussion with its posts, and signing in from the community.
  '/community/thread/1',
  '/community/account',
  // A question on a verse, over the tabs, as the reader opens it.
  '/ask?verse=Genesis%203:22',
  // The bookmarks and notes, with none yet.
  '/notes',
  '/settings',
  '/settings/reading',
  '/settings/reading/city',
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
  // A book of the Torah just finished.
  '/celebrate/sefer:5787:0',
  // Links that lead nowhere.
  '/nope',
  '/community/forum/xyz',
];

/// Pages whose texts load behind a spinner, which never settles: the
/// reader, guided at Revi'i and the full text of Rishon, and a haftarah.
/// semantics_invariants_pages_test.dart checks them in every theme, once it
/// has found their verses.
const a11yLoadingRoutes = ['/read/5787:2/3', '/read/5787:2/0?mode=full', '/haftarah/5787:2'];

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
