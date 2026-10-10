import 'package:flutter/material.dart';

import '../../ui/l10n.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';

/// A short, sourced explanation of the practice and how the app supports it.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sections = [
      (l.guideWhatTitle, l.guideWhatBody),
      (l.guideWhenTitle, l.guideWhenBody),
      (l.guideHowTitle, l.guideHowBody),
      (l.guideTargumTitle, l.guideTargumBody),
      (l.guideSpecialTitle, l.guideSpecialBody),
      (l.guideShabbatTitle, l.guideShabbatBody),
      (l.guideSourcesTitle, l.guideSourcesBody),
    ];
    return Scaffold(
      appBar: AppBar(leading: homeLeading(context), title: Text(l.guideTitle)),
      body: PageBody(
        children: [
          for (final (title, body) in sections) ...[
            SectionHeader(title),
            SelectableText(body, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)),
          ],
          const Gap(24),
          NoticeBanner(icon: Icons.info_outline, text: l.disclaimer),
        ],
      ),
    );
  }
}
