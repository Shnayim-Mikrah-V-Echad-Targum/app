import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/verse_ref.dart';
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
import '../features/notes/notes_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/parsha/browse_screen.dart';
import '../features/parsha/parsha_tab.dart';
import '../features/parsha/week_overview_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/reader/haftarah_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/reader/sefer_complete_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/screens/accessibility_settings_screen.dart';
import '../features/settings/screens/city_picker_screen.dart';
import '../features/settings/screens/data_settings_screen.dart';
import '../features/settings/screens/display_settings_screen.dart';
import '../features/settings/screens/reading_settings_screen.dart';
import '../features/settings/screens/reminder_settings_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/today/today_screen.dart';
import '../ui/theme/motion.dart';
import '../ui/widgets/fallbacks.dart';
import 'app_page.dart';
import 'providers.dart';
import 'routes.dart';
import 'shell.dart';

/// Every page uses the app's (Material) theme transitions, which become
/// instant when Reduce Motion is on, and takes a back swipe only while it is
/// the page on show (see [AppPage]).
Page<void> _page(GoRouterState state, Widget child) =>
    AppPage<void>(key: state.pageKey, name: state.uri.path, child: child);

GoRoute _route(String path, Widget Function(GoRouterState s) build, {List<RouteBase> routes = const []}) =>
    GoRoute(path: path, pageBuilder: (context, state) => _page(state, build(state)), routes: routes);

GoRoute _week(String path) => _route(path, (s) => WeekOverviewScreen(weekId: s.pathParameters['id']!));
GoRoute _haftarah(String path) => _route(path, (s) => HaftarahScreen(weekId: s.pathParameters['id']!));

/// The guide, the sources and a policy: within the tabs that open them, so
/// that the navigation bar or rail stays, and on their own, over the tabs,
/// for onboarding, links and the pages shown over the tabs. A policy that
/// doesn't exist is no page.
GoRoute _guide(String path) => _route(path, (_) => const GuideScreen());
GoRoute _sources(String path) => _route(path, (_) => const SourcesScreen());
GoRoute _legal(String path) => _route(path, (s) => switch (LegalDoc.fromSlug(s.pathParameters['doc']!)) {
      final doc? => LegalScreen(doc: doc),
      null => const NotFoundPage(),
    });

/// A tab's copy of the guide, the sources or a policy
/// ('/settings/about/legal/privacy'), as the page of its own over the tabs
/// ('/legal/privacy'); null for any other page.
String? _pageOverTabs(String path) => switch (path) {
      '/today/guide' || '/settings/guide' => '/guide',
      '/settings/about/sources' => '/sources',
      _ => RegExp(r'^/(community|settings/about|settings/accessibility)(/legal/[^/]+)$').firstMatch(path)?.group(2),
    };

/// A week and its haftarah within each of the [weekTabs], so the navigation
/// bar stays.
List<RouteBase> _weekPages() => [_week('week/:id'), _haftarah('haftarah/:id')];

/// The account page, in Community and in Settings: each tab keeps its own.
/// ?then=back goes back once signed in; ?from=data says Your data is beneath.
AccountScreen _account(GoRouterState s) => AccountScreen(
      returnWhenSignedIn: s.uri.queryParameters['then'] == 'back',
      openedFromData: s.uri.queryParameters['from'] == 'data',
    );

final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ValueNotifier<bool>(ref.read(settingsProvider).onboardingComplete);
  ref.listen(settingsProvider.select((s) => s.onboardingComplete), (_, next) => onboarded.value = next);
  ref.onDispose(onboarded.dispose);

  return GoRouter(
    // A notification that launched the app is opened over Today once it is
    // up (see openFromOutside), so it always has somewhere to go back to.
    initialLocation: '/today',
    refreshListenable: onboarded,
    redirect: (context, state) {
      final path = state.uri.path;
      // The welcome and the steps of onboarding after it.
      final atWelcome = path == '/welcome' || path.startsWith('/welcome/');
      // The guide, sources and policies are open before onboarding too: the
      // stores require the privacy policy to be reachable on a first visit.
      // Their copies within the tabs (the addresses they had in About among
      // them) lead to the pages of their own, as the tabs wait for it.
      final isPublic = path == '/guide' || path == '/sources' || path.startsWith('/legal/');
      if (!onboarded.value && !atWelcome && !isPublic) return _pageOverTabs(path) ?? '/welcome';
      if (onboarded.value && atWelcome) return '/today';
      return null;
    },
    errorPageBuilder: (context, state) => _page(state, const NotFoundPage()),
    routes: [
      _route('/welcome', (_) => const OnboardingScreen(), routes: [
        for (final step in OnboardingStep.values) _route(step.name, (_) => OnboardingStepScreen(step: step)),
        // Signing in to restore a backup, back to the welcome once signed in:
        // without a display name, as nothing is posted.
        _route('account', (_) => const AccountScreen(returnWhenSignedIn: true, needsName: false)),
      ]),
      StatefulShellRoute(
        navigatorContainerBuilder: _tabStack,
        pageBuilder: (context, state, shell) => _page(state, AppShell(shell: shell)),
        branches: [
          StatefulShellBranch(routes: [
            _route('/today', (_) => const TodayScreen(), routes: [..._weekPages(), _guide('guide')]),
          ]),
          StatefulShellBranch(routes: [
            _route('/parsha', (_) => const ParshaTab(), routes: [
              _route('browse', (_) => const BrowseScreen()),
              ..._weekPages(),
            ]),
          ]),
          StatefulShellBranch(routes: [_route('/progress', (_) => const ProgressScreen(), routes: _weekPages())]),
          StatefulShellBranch(routes: [
            _route('/community', (_) => const CommunityScreen(), routes: [
              _route('forum/:slug', (s) => ForumScreen(slug: s.pathParameters['slug']!)),
              _route('thread/:id', (s) => ThreadScreen(threadId: s.pathParameters['id']!)),
              // ?verse=Genesis 3:22 begins a question on that verse.
              _route('new', (s) => ComposeScreen(
                    forumSlug: s.uri.queryParameters['forum'],
                    verse: s.uri.queryParameters['verse'],
                  )),
              _route('account', _account),
              _route('moderation', (_) => const ModerationScreen()),
              // The privacy policy from the account, the guidelines from a
              // new discussion.
              _legal('legal/:doc'),
            ]),
          ]),
          StatefulShellBranch(routes: [
            _route('/settings', (_) => const SettingsScreen(), routes: [
              _route('reading', (_) => const ReadingSettingsScreen(), routes: [
                _route('city', (_) => const CityPickerScreen()),
              ]),
              _route('display', (_) => const DisplaySettingsScreen()),
              _route('accessibility', (_) => const AccessibilitySettingsScreen(), routes: [
                // The accessibility statement.
                _legal('legal/:doc'),
              ]),
              _route('reminders', (_) => const ReminderSettingsScreen(), routes: [
                _route('city', (_) => const CityPickerScreen()),
              ]),
              _route('data', (_) => const DataSettingsScreen()),
              _route('account', _account),
              _route('about', (_) => const AboutScreen(), routes: [_sources('sources'), _legal('legal/:doc')]),
              _guide('guide'),
            ]),
          ]),
        ],
      ),
      // On their own, before onboarding too (see the redirect).
      _guide('/guide'),
      _sources('/sources'),
      _legal('/legal/:doc'),
      // A week and its haftarah on their own, for links and notifications.
      _week('/week/:id'),
      _haftarah('/haftarah/:id'),
      // Search fills the screen, as the reader does; ?q= searches at once.
      _route('/search', (s) => SearchScreen(initialQuery: s.uri.queryParameters['q'] ?? '')),
      // The bookmarks and notes, over the tabs as the reader they open is;
      // ?week= those of one week's parsha.
      _route('/notes', (s) => NotesScreen(weekId: s.uri.queryParameters['week'])),
      // A question on a verse, asked over the reader, which closing it or
      // posting goes back to: /ask?verse=Genesis 3:22.
      _route('/ask', (s) => ComposeScreen(forumSlug: 'questions', verse: s.uri.queryParameters['verse'])),
      // Signing in over the tabs, before such a question is posted; back to
      // it once signed in.
      _route('/account', _account),
      // The list of cities over the reader, offered once reminders are turned
      // on there; choosing one goes back to it.
      _route('/city', (_) => const CityPickerScreen()),
      // A book of the Torah just finished, once (see celebrations.dart):
      // /celebrate/sefer:5787:0.
      _route('/celebrate/:key', (s) => SeferCompleteScreen(celebrationKey: s.pathParameters['key']!)),
      // The reader always fills the screen. ?verse=28:12 opens the full
      // text at that verse.
      _route('/read/:id/:aliyah', (s) => ReaderScreen(
            weekId: s.pathParameters['id']!,
            aliyah: int.tryParse(s.pathParameters['aliyah']!) ?? 0,
            fullText: s.uri.queryParameters['mode'] == 'full',
            fromWeek: s.uri.queryParameters['from'] == 'week',
            targetVerse: VerseRef.tryParse(s.uri.queryParameters['verse']),
          )),
    ],
  );
});

/// The tabs' navigators, each kept as it was left and only the chosen one
/// shown, as go_router's indexed stack keeps them; and only the chosen one's
/// heroes take part in a page's transition. On a tablet or desktop each
/// tab's page on show is the Scaffold that shows a status message (§6.19),
/// whose copy of it, a hero, would otherwise be one of several alike. The
/// tab chosen fades in, and the one left goes at once.
Widget _tabStack(BuildContext context, StatefulNavigationShell shell, List<Widget> children) => IndexedStack(
      index: shell.currentIndex,
      children: [
        for (final (i, child) in children.indexed)
          Offstage(
            offstage: i != shell.currentIndex,
            child: _TabFadeIn(
              active: i == shell.currentIndex,
              child: TickerMode(
                enabled: i == shell.currentIndex,
                child: HeroMode(enabled: i == shell.currentIndex, child: child),
              ),
            ),
          ),
      ],
    );

/// A tab that fades in over [Motion.short] each time it is chosen (§8), as
/// its indicator moves to it; shown at once on Apple platforms, whose tabs
/// switch without a transition, and while motion is reduced.
class _TabFadeIn extends StatefulWidget {
  const _TabFadeIn({required this.active, required this.child});

  /// Whether this is the tab on show.
  final bool active;

  final Widget child;

  @override
  State<_TabFadeIn> createState() => _TabFadeInState();
}

class _TabFadeInState extends State<_TabFadeIn> with SingleTickerProviderStateMixin {
  // Settled until a tab is chosen, so the first tab shown simply is there.
  late final _controller = AnimationController(vsync: this, duration: Motion.short, value: 1);
  late final _opacity = _controller.drive(CurveTween(curve: Motion.decelerate));

  @override
  void didUpdateWidget(_TabFadeIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active || oldWidget.active) return;
    final apple = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    if (apple || Motion.of(context).reduced) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Heard by screen readers from its first frame, as its content is there.
  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, alwaysIncludeSemantics: true, child: widget.child);
}

/// The roots of the navigation tabs.
const _tabs = ['/today', '/parsha', '/progress', '/community', '/settings'];

/// Opens [location] from outside the app's own navigation: a tapped
/// notification or a shortcut on the app's icon, or one that launched the
/// app. A tab, or a page within one,
/// opens in its place; any other page opens over Today, so it has a back
/// button that leads to the navigation bar rather than a dead end. A week or
/// a haftarah on its own, as notifications scheduled by earlier versions
/// name them, opens within Today.
void openFromOutside(GoRouter router, String location) {
  if (RegExp(r'^/(week|haftarah)/').hasMatch(location)) location = '/today$location';
  final path = Uri.parse(location).path;
  if (_tabs.any((tab) => path == tab || path.startsWith('$tab/'))) {
    router.go(location);
  } else {
    router.go('/today');
    router.push(location);
  }
}
