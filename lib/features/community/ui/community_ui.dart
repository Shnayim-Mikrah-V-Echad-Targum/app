import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/calendar/parsha_schedule.dart';
import '../../../core/text/hebrew_text.dart';
import '../../../data/models/parsha.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/lang.dart';
import '../../about/legal_screen.dart';
import '../../parsha/week_context.dart';
import '../../progress/domain/progress_models.dart';
import '../data/backend.dart';
import '../data/community_providers.dart';
import '../data/models.dart';

/// A localized message for a community error. Check [alreadyDone] first: that
/// is no error to show.
String communityError(AppLocalizations l, Object e) {
  if (e is! CommunityException) return l.errNetwork;
  return switch (e.code) {
    'rate_limited' || 'slow_mode' => l.errRateLimited,
    'thread_locked' => l.errThreadLocked,
    'terms_not_accepted' => l.errTerms,
    'banned' => l.errBanned,
    'silenced_until' => l.errSilenced,
    'content_rejected' => l.errContent,
    'duplicate_post' => l.errDuplicate,
    'too_many_links' => l.errLinks,
    'daily_limit_new_user' || 'daily_thread_limit_new_user' => l.errDailyLimit,
    'name_taken' => l.errNameTaken,
    'already_reported' => l.errAlreadyReported,
    'invalid_name' => l.errInvalidName,
    'invalid_code' || 'otp_expired' => l.errInvalidCode,
    'invalid_email' || 'email_address_invalid' => l.errInvalidEmail,
    'not_signed_in' => l.errNotSignedIn,
    'forbidden' || 'category_restricted' || 'kind_not_allowed' => l.errForbidden,
    'shabbat_closed' => l.errShabbat,
    'too_short' => l.errTooShort,
    'title_too_short' => l.errTitleTooShort,
    _ => l.errorGeneric,
  };
}

/// Whether [e] only says that the change had been made already, as when a
/// second tap crosses the first: the action succeeded.
bool alreadyDone(Object e) => e is CommunityException && e.code == 'duplicate';

/// "5 minutes ago", or a date for older times.
String relativeTime(BuildContext context, DateTime time) {
  final l = context.l10n;
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return l.timeJustNow;
  if (diff.inMinutes < 60) return l.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l.timeHoursAgo(diff.inHours);
  return MaterialLocalizations.of(context).formatMediumDate(time.toLocal());
}

/// Absolute date and time, for screen readers and tooltips.
String absoluteTime(BuildContext context, DateTime time) {
  final m = MaterialLocalizations.of(context);
  final t = time.toLocal();
  return '${m.formatFullDate(t)}, ${m.formatTimeOfDay(TimeOfDay.fromDateTime(t))}';
}

/// Text direction from the first strong character, so Hebrew and English
/// posts each display correctly.
TextDirection autoDirection(String text) {
  for (final rune in text.runes) {
    if (rune >= 0x0590 && rune <= 0x08FF) return TextDirection.rtl;
    if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A)) return TextDirection.ltr;
  }
  return TextDirection.ltr;
}

/// Sends the user to sign in if needed. Returns whether they are signed in.
Future<bool> ensureSignedIn(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(forumRepositoryProvider);
  if (repo.currentUser != null) return true;
  await context.push('/community/account?then=back');
  return repo.currentUser != null;
}

/// Before a first post: the community guidelines. Returns whether accepted.
/// Fails as the backend does (offline, say), for the caller to report.
Future<bool> ensureGuidelines(BuildContext context, WidgetRef ref) async {
  // The page may close while this waits, and its ref with it.
  final container = ProviderScope.containerOf(context, listen: false);
  final repo = ref.read(forumRepositoryProvider);
  final profile = await container.read(myProfileProvider.future);
  if (profile == null) return false;
  if (profile.acceptedTerms) return true;
  if (!context.mounted) return false;
  final l = context.l10n;
  var checked = false;
  final ok = await showAppDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l.guidelinesTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.guidelinesPrompt),
            TextButton(
              // In front of this dialog, which it returns to.
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(builder: (_) => const LegalScreen(doc: LegalDoc.guidelines)),
              ),
              child: Text(l.readGuidelines),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: checked,
              onChanged: (v) => setState(() => checked = v ?? false),
              title: Text(l.guidelinesAccept),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
          FilledButton(onPressed: checked ? () => Navigator.pop(context, true) : null, child: Text(l.actionContinue)),
        ],
      ),
    ),
  );
  if (ok != true) return false;
  await repo.acceptGuidelines();
  container.invalidate(myProfileProvider);
  return true;
}

/// Opens (creating if needed) the shared discussion of [portion], a single
/// or combined parsha, in the cycle that began in [hebrewYear]. A failure
/// (offline, say) is reported in a snackbar.
Future<void> openWeeklyThread(BuildContext context, WidgetRef ref, PortionInfo portion, int hebrewYear) async {
  final l = context.l10n;
  // Only a fallback: the server builds the title from its own reference data.
  final title = '${portion.key} · ${HebrewText.stripNikud(portion.nameHe)} · $hebrewYear';
  try {
    final id = await ref.read(forumRepositoryProvider).weeklyThread(
          parshaNumber: portion.id.number,
          hebrewYear: hebrewYear,
          title: title,
        );
    if (context.mounted) openTabPage(context, '/community/thread/$id');
  } catch (e) {
    if (context.mounted) showStatus(context, communityError(l, e));
  }
}

/// A control that opens the shared discussion of [portion] in the cycle
/// that began in [hebrewYear] (see [openWeeklyThread]). While it opens,
/// [builder] gets a small progress indicator to show in place of the
/// control's icon, and further presses are ignored. The control stays
/// enabled meanwhile, so that it keeps the keyboard focus.
class WeeklyThreadOpener extends ConsumerStatefulWidget {
  const WeeklyThreadOpener({super.key, required this.portion, required this.hebrewYear, required this.builder});

  final PortionInfo portion;
  final int hebrewYear;
  final Widget Function(BuildContext context, Widget? progress, VoidCallback open) builder;

  @override
  ConsumerState<WeeklyThreadOpener> createState() => _WeeklyThreadOpenerState();
}

class _WeeklyThreadOpenerState extends ConsumerState<WeeklyThreadOpener> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await openWeeklyThread(context, ref, widget.portion, widget.hebrewYear);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _busy
        ? SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: context.l10n.loading),
          )
        : null;
    return widget.builder(context, progress, _open);
  }
}

/// A page whose content can be fetched again by [refresh] without pulling it
/// down, which takes a touch screen: with the Refresh button that [builder]
/// puts in the app bar, and outside the web, where the browser keeps them
/// for reloading, with F5 and Ctrl+R (⌘R on Apple platforms). Either says
/// once the content is up to date, or why it isn't; [refresh] fails as the
/// backend does. Presses while it runs are ignored. The button stays enabled
/// meanwhile, so that it keeps the keyboard focus.
class RefreshablePage extends StatefulWidget {
  const RefreshablePage({super.key, required this.refresh, required this.builder});

  final Future<void> Function() refresh;
  final Widget Function(BuildContext context, Widget refreshButton) builder;

  @override
  State<RefreshablePage> createState() => _RefreshablePageState();
}

class _RefreshablePageState extends State<RefreshablePage> {
  bool _busy = false;

  Future<void> _refresh() async {
    if (_busy) return;
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      await widget.refresh();
      if (mounted) showStatus(context, l.refreshed);
    } catch (e) {
      if (mounted) showStatus(context, communityError(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final button = IconButton(
      tooltip: l.actionRefresh,
      onPressed: _refresh,
      icon: _busy
          ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l.loading))
          : const Icon(Icons.refresh),
    );
    final page = widget.builder(context, button);
    if (kIsWeb) return page;
    final apple = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): _refresh,
        SingleActivator(LogicalKeyboardKey.keyR, control: !apple, meta: apple): _refresh,
      },
      // Takes the focus when the page opens on top, so that the keys work at
      // once, but is no stop of its own for Tab.
      child: Focus(autofocus: ModalRoute.isCurrentOf(context) ?? true, skipTraversal: true, child: page),
    );
  }
}

/// The parsha discussed by a weekly thread, keyed by (the year its cycle
/// began, its parsha's number), as the reader's schedule reads it that year:
/// a combined pair when the two are read together, whose thread is the first
/// one's. Kept, as finding the week walks the year's schedule.
final weeklyThreadPortionProvider = Provider.family<PortionInfo, (int, int)>((ref, key) {
  final (year, n) = key;
  final repo = ref.watch(parshaRepositoryProvider);
  final week = findWeekById(ref.watch(scheduleProvider), '$year:$n');
  return week != null && week.portion.number == n ? repo.portion(week.portion) : repo.byNumber(n);
});

/// The parsha a weekly thread discusses (see [weeklyThreadPortionProvider]).
/// Null for any other thread.
PortionInfo? weeklyThreadPortion(WidgetRef ref, ThreadSummary t) {
  final (n, year) = (t.parshaNumber, t.hebrewYear);
  if (t.kind != ThreadKind.weekly || n == null || year == null || n < 1 || n > kParshaCount) return null;
  return ref.watch(weeklyThreadPortionProvider((year, n)));
}

/// A thread's title as shown. A weekly thread's is in the reader's language
/// and spelling, "Parshat Bereshit 5787" or "פרשת בראשית תשפ״ז"; the title
/// stored on the server stays the one searched and moderated.
String threadDisplayTitle(BuildContext context, WidgetRef ref, ThreadSummary t) {
  final portion = weeklyThreadPortion(ref, t);
  if (portion == null) return t.title;
  final year = t.hebrewYear!;
  return context.l10n.weeklyThreadTitle(
    _portionName(context, ref, portion),
    context.isHebrewUi ? HebrewText.gematria(year % 1000) : '$year',
  );
}

/// What an empty thread says: a weekly thread invites a first thought on its
/// parsha.
String emptyThreadMessage(BuildContext context, WidgetRef ref, ThreadSummary t) {
  final portion = weeklyThreadPortion(ref, t);
  return portion == null ? context.l10n.noReplies : context.l10n.noPostsYet(_portionName(context, ref, portion));
}

String _portionName(BuildContext context, WidgetRef ref, PortionInfo portion) =>
    Names(context).portion(portion, ashkenazi: ref.watch(settingsProvider.select((s) => s.ashkenaziNames)));

/// [s] as a first-strong isolate, between U+2068 and U+2069: a name, which
/// may be Hebrew or English, then keeps its own order inside a line in the
/// other language, and the punctuation either side of it stays with the line.
String isolate(String s) => '\u2068$s\u2069';

/// Says on the Community page that the community is the demo, on the device
/// alone (§6.20). It can be dismissed for the rest of the session; the other
/// community pages say it with their [DemoTag].
class DemoBanner extends ConsumerStatefulWidget {
  const DemoBanner({super.key});

  @override
  ConsumerState<DemoBanner> createState() => _DemoBannerState();
}

class _DemoBannerState extends ConsumerState<DemoBanner> {
  final _dismiss = FocusNode();

  @override
  void dispose() {
    _dismiss.dispose();
    super.dispose();
  }

  void _onDismiss() {
    // The button goes with the notice: the keyboard focus moves on to what
    // follows it, rather than back to the top of the page.
    if (_dismiss.hasPrimaryFocus) _dismiss.nextFocus();
    ref.read(demoBannerDismissedProvider.notifier).dismiss();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(forumRepositoryProvider).isDemo || ref.watch(demoBannerDismissedProvider)) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: Rhythm.cardGap),
      child: NoticeBanner(
        icon: Icons.info_outline,
        text: l.demoModeBanner,
        action: IconButton(
          focusNode: _dismiss,
          tooltip: l.dismissNotice,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          icon: const Icon(Icons.close, size: 20),
          onPressed: _onDismiss,
        ),
      ),
    );
  }
}

/// A small "Demo" tag for the app bar of a community page (§6.20), while the
/// community is the demo. It opens a sheet that explains the demo.
class DemoTag extends ConsumerWidget {
  const DemoTag({super.key});

  static const _corners = BorderRadius.all(Radius.circular(6));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(forumRepositoryProvider).isDemo) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final themed = theme.textButtonTheme.style;
    // High contrast outlines it, as it does notices: the pale fill alone
    // barely shows there.
    final side = SeferColors.of(context).isHighContrast ? BorderSide(color: scheme.outline, width: 2) : BorderSide.none;
    return Padding(
      // Its end where an icon button's glyph would end: at the page's edge,
      // and clear of the action after it.
      padding: const EdgeInsetsDirectional.only(start: Space.sm, end: Space.md),
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
          textStyle: theme.textTheme.labelSmall,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          minimumSize: Size.zero,
          // A small tag, but a whole 48 to tap.
          tapTargetSize: MaterialTapTargetSize.padded,
        ).copyWith(
          // The theme's keyboard focus ring (§6.1), around the tag's corners.
          shape: WidgetStateProperty.resolveWith(
            (states) => switch (themed?.shape?.resolve(states)) {
              final FocusRingBorder ring => ring.copyWith(borderRadius: _corners, side: side),
              _ => RoundedRectangleBorder(borderRadius: _corners, side: side),
            },
          ),
        ),
        onPressed: () => showDemoAbout(context),
        child: Text(context.l10n.demoTag),
      ),
    );
  }
}

/// What the demo is: that it runs on this device alone, with example
/// discussions; that what is posted stays on the device until the app
/// restarts; and how to sign in to try it.
Future<void> showDemoAbout(BuildContext context) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final l = context.l10n;
        final theme = Theme.of(context);
        final padding = sheetPadding(context);
        final body = theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: Space.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetTitle(l.demoAboutTitle),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.demoAboutBody, style: body),
                      const Gap(Space.md),
                      Text(l.demoAboutPosts, style: body),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

/// A member's initial on a disc of gold-ink paper (§6.21), standing for them
/// beside their name, or for the account on its button. It is decorative:
/// what shows it names the member too. Without a name yet, a person.
class InitialDisc extends StatelessWidget {
  const InitialDisc(this.name, {super.key, this.size = 32});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = scheme.onSecondaryContainer;
    final initial = name.trim().characters.firstOrNull?.toUpperCase();
    // The serif of titles, at 600 at least (§6.21): EB Garamond, with Frank
    // Ruhl Libre for a Hebrew initial, or the chosen accessibility font.
    final serif = theme.textTheme.titleLarge!;
    final weight = (serif.fontWeight?.value ?? 400) >= 600 ? serif.fontWeight : FontWeight.w600;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: scheme.secondaryContainer, shape: BoxShape.circle),
        child: initial == null
            ? Icon(Icons.person_outline, size: size * 0.6, color: ink)
            : Text(
                initial,
                // Sized to its disc, which keeps its size as text grows.
                textScaler: TextScaler.noScaling,
                style: serif.copyWith(fontSize: size / 2, height: 1, fontWeight: weight, color: ink),
              ),
      ),
    );
  }
}

/// This week's discussion on a card that opens it (§9 Community): the
/// parsha's name in Hebrew, "This week: Parshat Bereshit" and "Open the
/// discussion". While the discussion opens, a small spinner takes the
/// chevron's place.
class ThisWeekCard extends ConsumerWidget {
  const ThisWeekCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final week = ref.watch(currentWeekContextProvider);
    final portion = week.portion;
    final hebrew = SeferType.of(context).hebrewDisplay.copyWith(
          fontSize: 20,
          // Frank Ruhl Libre is set heavier in high contrast.
          fontWeight: SeferColors.of(context).isHighContrast ? FontWeight.w700 : FontWeight.w600,
        );
    return WeeklyThreadOpener(
      portion: portion,
      hebrewYear: cycleYearOf(week.week.portion, week.week.occasion),
      builder: (context, progress, open) => InfoCard(
        onTap: open,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Lang(
                    const Locale('he'),
                    child: Text(
                      portion.nameHe,
                      locale: const Locale('he'),
                      // Read from its letters, as screen readers read verses.
                      semanticsLabel: HebrewText.stripNikud(portion.nameHe),
                      style: hebrew,
                    ),
                  ),
                  const Gap(Space.xs),
                  Text(l.thisWeeksThread(_portionName(context, ref, portion)), style: theme.textTheme.titleMedium),
                  Text(l.openDiscussion, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const Gap(Space.md),
            SizedBox.square(
              dimension: 24,
              child: Center(child: progress ?? Icon(Icons.chevron_right, size: 20, color: scheme.outline)),
            ),
          ],
        ),
      ),
    );
  }
}
