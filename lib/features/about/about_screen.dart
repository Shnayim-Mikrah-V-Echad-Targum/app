import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/app_icon.dart';
import '../../ui/widgets/common.dart';

final _version = PackageInfo.fromPlatform().then((i) => '${i.version} (${i.buildNumber})').catchError((_) => '');

/// An email to the maintainers, or null when the build names no address.
Uri? supportEmailUri(AppLocalizations l) => AppConfig.supportEmail.isEmpty
    ? null
    : Uri(scheme: 'mailto', path: AppConfig.supportEmail, query: 'subject=${Uri.encodeComponent(l.appTitle)}');

/// The public issue tracker, where feedback reaches the maintainers in any
/// build.
final issueTrackerUri = Uri.parse('${AppConfig.sourceUrl}/issues');

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    Widget link(IconData icon, String title, VoidCallback onTap) =>
        ListTile(leading: AppIcon(icon), title: Text(title), trailing: const Icon(Icons.chevron_right), onTap: onTap);
    return PageScaffold(
      titleText: l.aboutTitle,
      body: PageBody(
        padding: PageBody.tilePadding(context),
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('שניים מקרא ואחד תרגום',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontFamily: 'NotoSerifHebrew', fontSize: 28, color: theme.colorScheme.primary)),
                // The name as read in English; in Hebrew it would repeat the title.
                if (!context.isHebrewUi) ...[
                  const Gap(8),
                  Text(l.appTitleFull, style: theme.textTheme.titleMedium),
                ],
                FutureBuilder<String>(
                  future: _version,
                  builder: (context, snap) => Text(
                    snap.data == null || snap.data!.isEmpty ? '' : l.versionLabel(snap.data!),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          link(Icons.help_outline, l.guideTitle, () => context.push('/guide')),
          link(Icons.library_books_outlined, l.sourcesTitle, () => context.push('/sources')),
          link(Icons.accessibility, l.accessibilityStatement, () => context.push('/legal/accessibility')),
          link(Icons.privacy_tip_outlined, l.privacyTitle, () => context.push('/legal/privacy')),
          link(Icons.gavel_outlined, l.termsTitle, () => context.push('/legal/terms')),
          link(Icons.groups_outlined, l.guidelinesTitle, () => context.push('/legal/guidelines')),
          link(Icons.description_outlined, l.licensesTitle, () => showLicensePage(context: context, applicationName: l.appTitleFull)),
          if (supportEmailUri(l) case final email?) link(Icons.mail_outline, l.contactTitle, () => launchUrl(email)),
          link(Icons.feedback_outlined, l.sendFeedback, () => launchUrl(issueTrackerUri)),
        ],
      ),
    );
  }
}
