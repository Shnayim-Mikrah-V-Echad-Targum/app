import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/about/about_screen.dart';
import '../features/about/guide_screen.dart';
import '../features/about/legal_screen.dart';
import '../features/about/sources_screen.dart';
import '../features/community/ui/community_screen.dart';
import '../features/community/ui/compose_screen.dart';
import '../features/community/ui/forum_screen.dart';
import '../features/community/ui/account_screen.dart';
import '../features/community/ui/moderation_screen.dart';
import '../features/community/ui/thread_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/parsha/browse_screen.dart';
import '../features/parsha/parsha_tab.dart';
import '../features/parsha/week_overview_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/reader/haftarah_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/settings/screens/accessibility_settings_screen.dart';
import '../features/settings/screens/data_settings_screen.dart';
import '../features/settings/screens/display_settings_screen.dart';
import '../features/settings/screens/reading_settings_screen.dart';
import '../features/settings/screens/reminder_settings_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/today/today_screen.dart';
import '../services/notifications.dart';
import 'providers.dart';
import 'shell.dart';

/// Every page uses the app's (Material) theme transitions, which become
/// instant when Reduce Motion is on.
Page<void> _page(GoRouterState state, Widget child) =>
    MaterialPage<void>(key: state.pageKey, name: state.uri.path, child: child);

GoRoute _route(String path, Widget Function(GoRouterState s) build, {List<RouteBase> routes = const []}) =>
    GoRoute(path: path, pageBuilder: (context, state) => _page(state, build(state)), routes: routes);

final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ValueNotifier<bool>(ref.read(settingsProvider).onboardingComplete);
  ref.listen(settingsProvider.select((s) => s.onboardingComplete), (_, next) => onboarded.value = next);
  ref.onDispose(onboarded.dispose);

  return GoRouter(
    initialLocation: ref.read(notificationServiceProvider).launchRoute ?? '/today',
    refreshListenable: onboarded,
    redirect: (context, state) {
      final atWelcome = state.uri.path == '/welcome';
      if (!onboarded.value && !atWelcome) return '/welcome';
      if (onboarded.value && atWelcome) return '/today';
      return null;
    },
    errorPageBuilder: (context, state) => _page(state, const _NotFound()),
    routes: [
      _route('/welcome', (_) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, shell) => _page(state, AppShell(shell: shell)),
        branches: [
          StatefulShellBranch(routes: [_route('/today', (_) => const TodayScreen())]),
          StatefulShellBranch(routes: [
            _route('/parsha', (_) => const ParshaTab(), routes: [
              _route('browse', (_) => const BrowseScreen()),
            ]),
          ]),
          StatefulShellBranch(routes: [_route('/progress', (_) => const ProgressScreen())]),
          StatefulShellBranch(routes: [
            _route('/community', (_) => const CommunityScreen(), routes: [
              _route('forum/:slug', (s) => ForumScreen(slug: s.pathParameters['slug']!)),
              _route('thread/:id', (s) => ThreadScreen(threadId: s.pathParameters['id']!)),
              _route('new', (s) => ComposeScreen(
                    forumSlug: s.uri.queryParameters['forum'],
                    parshaKey: s.uri.queryParameters['parsha'],
                  )),
              _route('account', (s) => AccountScreen(returnWhenSignedIn: s.uri.queryParameters['then'] == 'back')),
              _route('moderation', (_) => const ModerationScreen()),
            ]),
          ]),
          StatefulShellBranch(routes: [
            _route('/settings', (_) => const SettingsScreen(), routes: [
              _route('reading', (_) => const ReadingSettingsScreen()),
              _route('display', (_) => const DisplaySettingsScreen()),
              _route('accessibility', (_) => const AccessibilitySettingsScreen()),
              _route('reminders', (_) => const ReminderSettingsScreen()),
              _route('data', (_) => const DataSettingsScreen()),
              _route('about', (_) => const AboutScreen(), routes: [
                _route('sources', (_) => const SourcesScreen()),
                _route('legal/:doc', (s) => LegalScreen(doc: LegalDoc.fromSlug(s.pathParameters['doc']!))),
              ]),
            ]),
          ]),
        ],
      ),
      _route('/guide', (_) => const GuideScreen()),
      _route('/week/:id', (s) => WeekOverviewScreen(weekId: s.pathParameters['id']!)),
      _route('/read/:id/:aliyah', (s) => ReaderScreen(
            weekId: s.pathParameters['id']!,
            aliyah: int.tryParse(s.pathParameters['aliyah']!) ?? 0,
            fullText: s.uri.queryParameters['mode'] == 'full',
          )),
      _route('/haftarah/:id', (s) => HaftarahScreen(weekId: s.pathParameters['id']!)),
    ],
  );
});

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: FilledButton(onPressed: () => context.go('/today'), child: const Icon(Icons.home)),
        ),
      );
}
