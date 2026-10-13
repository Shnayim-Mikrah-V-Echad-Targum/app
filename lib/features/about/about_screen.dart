import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config.dart';
import '../../l10n/app_localizations.dart';
import '../../services/feedback.dart';
import '../../services/recent_errors.dart';
import '../../services/web_update.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/app_mark.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/heading_reveal.dart';
import '../../ui/widgets/lines.dart';
import '../../ui/widgets/ornaments.dart';
import '../../ui/widgets/paper_group.dart';
import '../../ui/widgets/web_update_banner.dart';
import '../community/data/backend.dart';

/// The app's version and build, "1.0.0 (12)", or empty where the platform
/// doesn't say.
final _versionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } catch (_) {
    return '';
  }
});

/// An email to the maintainers about [subject] (the app's name unless
/// given), or null when the build names no address.
Uri? supportEmailUri(AppLocalizations l, {String? subject}) => AppConfig.supportEmail.isEmpty
    ? null
    : Uri(
        scheme: 'mailto',
        path: AppConfig.supportEmail,
        query: 'subject=${Uri.encodeComponent(subject ?? l.appTitle)}',
      );

/// The public issue tracker, where feedback reaches the maintainers in any
/// build.
final issueTrackerUri = Uri.parse('${AppConfig.sourceUrl}/issues');

/// Feedback, by the one way every Send feedback row takes: by email where
/// the build names an address for it and [email] allows (About, whose
/// Contact row emails already, doesn't). Otherwise (or with no mail app to
/// send it) in the feedback forum, where there is a community server for it
/// to reach, and else on the issue tracker: the on-device demo forum reaches
/// no one.
Future<void> sendFeedback(BuildContext context, WidgetRef ref, {bool email = true}) async {
  final address = email ? supportEmailUri(context.l10n) : null;
  final forum = !ref.read(forumRepositoryProvider).isDemo;
  if (address != null && await launchUrl(address).catchError((_) => false)) return;
  if (!context.mounted) return;
  if (forum) {
    await context.push('/community/forum/feedback');
  } else {
    await launchUrl(issueTrackerUri).catchError((_) => false);
  }
}

/// About (docs/DESIGN_SYSTEM.md §9): the app's title page, with its mark, its
/// name and the version, then the texts, the policies and the ways to reach
/// us, each on a sheet of paper. The guide is reached from Today and from
/// Settings.
///
/// The app's name is the page's one heading of level 1; the app bar names the
/// page once the name has scrolled under it, for the eye alone.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> with HeadingReveal<AboutScreen> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final email = supportEmailUri(l);
    return PageScaffold(
      titleText: l.aboutTitle,
      titleRevealed: headingHidden,
      body: watchHeading(PageBody(
        children: [
          _AboutHeader(nameKey: headingKey),
          // On the web, a new version of the app, under the version open:
          // offered here while it waits, though put away on Today.
          if (ref.watch(webUpdateReadyProvider)) ...[
            const Gap(Space.lg),
            const WebUpdateBanner(),
          ],
          GroupHeader(l.aboutGroupLearn),
          PaperGroup(
            children: [
              PaperRow(
                icon: Icons.library_books_outlined,
                title: l.sourcesTitle,
                onTap: () => context.push('/settings/about/sources'),
              ),
            ],
          ),
          GroupHeader(l.aboutGroupPolicies),
          PaperGroup(
            children: [
              PaperRow(
                icon: Icons.privacy_tip_outlined,
                title: l.privacyTitle,
                onTap: () => context.push('/settings/about/legal/privacy'),
              ),
              PaperRow(
                icon: Icons.gavel_outlined,
                title: l.termsTitle,
                onTap: () => context.push('/settings/about/legal/terms'),
              ),
              PaperRow(
                icon: Icons.groups_outlined,
                title: l.guidelinesTitle,
                onTap: () => context.push('/settings/about/legal/guidelines'),
              ),
              PaperRow(
                icon: Icons.accessibility_new_outlined,
                title: l.accessibilityStatement,
                onTap: () => context.push('/settings/about/legal/accessibility'),
              ),
              PaperRow(
                icon: Icons.description_outlined,
                title: l.licensesTitle,
                onTap: () => _showLicenses(context, l.appTitleFull),
              ),
            ],
          ),
          GroupHeader(l.aboutGroupContact),
          ListenableBuilder(
            listenable: recentErrors,
            builder: (context, _) => PaperGroup(
              children: [
                if (email != null)
                  PaperRow(icon: Icons.mail_outline, title: l.contactTitle, onTap: () => launchUrl(email)),
                PaperRow(
                  icon: Icons.feedback_outlined,
                  title: l.sendFeedback,
                  // The row above emails already.
                  onTap: () => sendFeedback(context, ref, email: false),
                ),
                // Only once something has gone wrong.
                if (recentErrors.isNotEmpty)
                  PaperRow(
                    icon: Icons.content_copy_outlined,
                    title: l.copySupportDetails,
                    subtitle: l.copySupportDetailsDesc,
                    chevron: false,
                    onTap: _copySupportDetails,
                  ),
              ],
            ),
          ),
        ],
      )),
    );
  }

  /// Copies what has gone wrong, under the app's version, for a message to
  /// us. The version is in hand already, as the header shows it: the copy
  /// is made at once, within the tap, as a browser may require.
  Future<void> _copySupportDetails() async {
    final String version = ref.read(_versionProvider).value ?? await ref.read(_versionProvider.future);
    await Clipboard.setData(ClipboardData(text: recentErrors.report(version: version)));
    if (mounted) showStatus(context, context.l10n.supportDetailsCopied);
  }
}

/// The app's title page: its mark; its name in Hebrew, the page's heading;
/// in the English UI the name as read in English; the version; and a
/// divider. Framed as a title page where the window is wide enough for one.
class _AboutHeader extends ConsumerWidget {
  const _AboutHeader({required this.nameKey});

  /// For the name, which the page watches scroll out of sight.
  final Key nameKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(_versionProvider).value ?? '';
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final type = SeferType.of(context);
    final framed = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    final header = Column(
      children: [
        const AppMark(size: 72, radius: 16),
        const Gap(Space.lg),
        Semantics(
          key: nameKey,
          header: true,
          headingLevel: 1,
          label: l.appTitleFull,
          excludeSemantics: true,
          // Its lines even, should large text need two.
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: BalancedText(
              'שניים מקרא ואחד תרגום',
              style: type.hebrewDisplay.copyWith(fontSize: 28, height: 40 / 28, letterSpacing: 0),
            ),
          ),
        ),
        // The name as read in English, which the heading already says. The
        // Hebrew UI doesn't repeat it.
        if (!context.isHebrewUi) ...[
          const Gap(Space.xs),
          ExcludeSemantics(
            child: BalancedText(l.appTitleFull, style: type.wordmark.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
        const Gap(Space.sm),
        Text(
          version.isEmpty ? '' : l.versionLabel(context.ltrRun(version)),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const Gap(Space.lg),
        const SeferDivider(),
      ],
    );
    if (!framed) return Padding(padding: const EdgeInsets.only(top: Space.xxl), child: header);
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg),
      child: TitlePageFrame(
        padding: const EdgeInsets.fromLTRB(Space.s32, Space.s32, Space.s32, Space.xxl),
        child: header,
      ),
    );
  }
}

/// Flutter's own licence pages, as showLicensePage opens them. Their app
/// bars are the framework's, which the app can't wrap in a ScrolledUnderRule
/// (§6.2), so these alone keep Material's scrolled-under elevation, its
/// shadow hairline-thin in outlineVariant (high contrast's bar has its rule
/// already): the licence text never slips under the bar unmarked.
void _showLicenses(BuildContext context, String applicationName) {
  final theme = Theme.of(context);
  final appBars = theme.appBarTheme.copyWith(
    scrolledUnderElevation: SeferColors.of(context).isHighContrast ? 0 : 1,
    shadowColor: theme.colorScheme.outlineVariant,
  );
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (context) => Theme(
      data: theme.copyWith(appBarTheme: appBars),
      child: LicensePage(applicationName: applicationName),
    ),
  ));
}
