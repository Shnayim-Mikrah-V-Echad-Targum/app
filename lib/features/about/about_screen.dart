import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/common.dart';

final _version = PackageInfo.fromPlatform().then((i) => '${i.version} (${i.buildNumber})').catchError((_) => '');

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    Widget link(IconData icon, String title, VoidCallback onTap) =>
        ListTile(leading: Icon(icon), title: Text(title), trailing: const Icon(Icons.chevron_right), onTap: onTap);
    return Scaffold(
      appBar: AppBar(title: Text(l.aboutTitle)),
      body: PageBody(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('שניים מקרא ואחד תרגום',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontFamily: 'NotoSerifHebrew', fontSize: 28, color: theme.colorScheme.primary)),
                const Gap(8),
                Text(l.appTitleFull, style: theme.textTheme.titleMedium),
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
          link(Icons.library_books_outlined, l.sourcesTitle, () => context.go('/settings/about/sources')),
          link(Icons.accessibility, l.accessibilityStatement, () => context.go('/settings/about/legal/accessibility')),
          link(Icons.privacy_tip_outlined, l.privacyTitle, () => context.go('/settings/about/legal/privacy')),
          link(Icons.gavel_outlined, l.termsTitle, () => context.go('/settings/about/legal/terms')),
          link(Icons.groups_outlined, l.guidelinesTitle, () => context.go('/settings/about/legal/guidelines')),
          link(Icons.description_outlined, l.licensesTitle, () => showLicensePage(context: context, applicationName: l.appTitleFull)),
          if (AppConfig.supportEmail.isNotEmpty)
            link(Icons.mail_outline, l.contactTitle,
                () => launchUrl(Uri(scheme: 'mailto', path: AppConfig.supportEmail, query: 'subject=${Uri.encodeComponent(l.appTitle)}'))),
          link(Icons.feedback_outlined, l.sendFeedback, () => launchUrl(Uri.parse('${AppConfig.sourceUrl}/issues'))),
        ],
      ),
    );
  }
}
