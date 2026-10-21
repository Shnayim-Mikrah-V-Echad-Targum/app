import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../services/feedback.dart';
import '../../services/support_details.dart';
import '../../services/updates/updates.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/paper_group.dart';
import '../../ui/widgets/progress_widgets.dart' show ShabbatCandlesIcon;
import '../../ui/widgets/update_banner.dart';
import '../settings/widgets/settings_widgets.dart' show SwitchRow;

/// The version running, as About, Updates shows it: "0.0.1 (preview)" for a
/// pre-release, as every 0.x version is, and "1.2.0" for a release.
/// The number reads left to right in a Hebrew sentence.
String runningVersionLabel(BuildContext context, SemVer version) {
  final number = context.ltrRun('$version');
  final preview = version.major == 0 || version.isPreRelease;
  return preview ? context.l10n.updatesPreviewVersion(number) : number;
}

/// When the releases were last read, "Last checked 3 hours ago", or that
/// they never have been.
String lastCheckedLabel(BuildContext context, DateTime? at) {
  final l = context.l10n;
  if (at == null) return l.updatesNotChecked;
  final ago = TodayController.now().difference(at);
  final when = ago.isNegative || ago.inMinutes < 1
      ? l.timeJustNow
      : ago.inMinutes < 60
          ? l.timeMinutesAgo(ago.inMinutes)
          : ago.inHours < 24
              ? l.timeHoursAgo(ago.inHours)
              : MaterialLocalizations.of(context).formatMediumDate(at);
  return l.updatesLastChecked(when);
}

/// About, Updates (docs/DESIGN_SYSTEM.md §9 About), in the Windows app that
/// looks for new versions ([UpdateState.supported]): the offer of a new
/// version where there is one; on Shabbat and Yom Tov, and their eve after
/// the reminders' cutoff, the note that updates wait; what went wrong last,
/// with Copy details for support; then the version running, Check now with
/// the last check, What's new and the Check automatically switch.
class UpdatesSection extends ConsumerWidget {
  const UpdatesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(updateControllerProvider);
    if (!state.supported) return const SizedBox.shrink();
    final current = ref.watch(runningVersionProvider).value;
    final auto = ref.watch(settingsProvider.select((s) => s.autoUpdateCheck));
    final problem = state.problem;
    final notices = [
      if (state.offered != null) const UpdateBanner(),
      if (state.quiet) NoticeBanner(leading: const ShabbatCandlesIcon(size: 20), text: l.updatesQuiet),
      // A release that couldn't be prepared is told of in the offer's place.
      if (problem == UpdateProblem.check && !state.checking)
        NoticeBanner(
          icon: Icons.error_outline,
          text: l.updateCheckFailed,
          liveRegion: true,
          actionBelow: true,
          action: TextButton(
            onPressed: () => copySupportDetails(context, ref),
            child: Text(l.copySupportDetails),
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupHeader(l.updatesHeading),
        for (final notice in notices) ...[notice, const Gap(Space.md)],
        PaperGroup(
          children: [
            PaperRow(
              icon: Icons.info_outline,
              title: l.updatesThisVersion,
              value: current == null ? null : runningVersionLabel(context, current),
            ),
            PaperRow(
              icon: Icons.refresh,
              title: l.updatesCheckNow,
              subtitle: state.checking ? l.updatesChecking : lastCheckedLabel(context, state.lastCheck),
              liveRegion: true,
              chevron: false,
              progress: state.checking
                  ? Semantics(
                      label: l.updatesChecking,
                      child: const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
              // Not while it is quiet, nor while a check or the install is
              // under way.
              onTap: state.quiet || state.checking || state.installing ? null : () => _checkNow(context, ref),
            ),
            PaperRow(
              icon: Icons.new_releases_outlined,
              title: l.updatesWhatsNew,
              subtitle: l.updatesWhatsNewDesc,
              // The notes of the version offered, or of the one running.
              onTap: () => _open(
                context,
                state.offered?.page ?? (current == null ? kReleasesPage : releasePageOf(current)),
              ),
            ),
            SwitchRow(
              icon: Icons.update,
              title: l.updatesAuto,
              subtitle: l.updatesAutoDesc,
              value: auto,
              onChanged: (v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(autoUpdateCheck: v)),
            ),
          ],
        ),
      ],
    );
  }

  static Future<void> _checkNow(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(updateControllerProvider.notifier).checkNow();
    // A new version shows in its notice, and a failure in its own.
    if (result == UpdateCheckResult.latest && context.mounted) showStatus(context, context.l10n.updatesLatest);
  }

  static Future<void> _open(BuildContext context, Uri page) async {
    final opened = await launchUrl(page).catchError((_) => false);
    if (!opened && context.mounted) showStatus(context, context.l10n.linkOpenFailed);
  }
}
