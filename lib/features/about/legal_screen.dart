import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/fallbacks.dart';
import '../../ui/widgets/heading_reveal.dart';
import 'about_screen.dart';
import 'legal_texts.dart';

export 'legal_texts.dart' show LegalDoc;

/// In-app policies (docs/DESIGN_SYSTEM.md §9), set as long-form reading: the
/// title and when it was last updated, then each section under its heading.
/// Kept in the app (not only on a website) so they are available offline and
/// in both languages; the texts are in assets/legal/legal.json.
class LegalScreen extends ConsumerStatefulWidget {
  const LegalScreen({super.key, required this.doc});

  final LegalDoc doc;

  @override
  ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen> with HeadingReveal<LegalScreen> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final type = SeferType.of(context);
    final title = switch (widget.doc) {
      LegalDoc.privacy => l.privacyTitle,
      LegalDoc.terms => l.termsTitle,
      LegalDoc.guidelines => l.guidelinesTitle,
      LegalDoc.accessibility => l.accessibilityStatement,
    };
    final texts = ref.watch(legalTextsProvider);
    final updated = texts.value?.updated(widget.doc);
    return PageScaffold(
      leading: homeLeading(context),
      titleText: title,
      titleRevealed: headingHidden,
      contentMaxWidth: ContentWidth.longform,
      body: NotificationListener<ScrollNotification>(
        onNotification: onPageScroll,
        child: PageBody(
          maxWidth: ContentWidth.longform,
          children: [
            const Gap(Space.lg),
            Semantics(
              header: true,
              headingLevel: 1,
              child: Text(title, key: headingKey, style: theme.textTheme.headlineMedium),
            ),
            if (updated != null) ...[
              const Gap(Space.xs),
              Text(
                l.legalLastUpdated(DateFormat.yMMMM(context.localeName).format(updated)),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            ...switch (texts) {
              AsyncData(:final value) => [
                  for (final section in value.sections(
                    widget.doc,
                    hebrew: context.isHebrewUi,
                    hasEmail: AppConfig.supportEmail.isNotEmpty,
                  ))
                    ..._section(context, section),
                ],
              AsyncError() => [const Gap(Space.xxl), Text(l.errorGeneric, style: type.longformBody)],
              _ => const <Widget>[],
            },
          ],
        ),
      ),
    );
  }

  static const _bulletGap = 6.0;

  /// [section] under its heading (the opening paragraphs have none), its
  /// paragraphs 12 apart and its bullets 6.
  List<Widget> _section(BuildContext context, LegalSection section) {
    final type = SeferType.of(context);
    final body = type.longformBody;
    final blocks = section.blocks;
    return [
      if (section.heading.isEmpty)
        const Gap(Space.xxl)
      else
        Padding(
          padding: const EdgeInsets.only(top: Rhythm.sectionGap + Space.xs, bottom: Space.sm),
          child: Semantics(header: true, headingLevel: 2, child: Text(section.heading, style: type.longformHeading)),
        ),
      for (final (i, block) in blocks.indexed) ...[
        // A bullet keeps its own gap below it.
        if (i > 0 && !(block is Bullet && blocks[i - 1] is Bullet))
          Gap(blocks[i - 1] is Bullet ? Space.md - _bulletGap : Space.md),
        switch (block) {
          Para(:final text) => SelectableText(text, style: body),
          Bullet(:final text) => _BulletItem(text, style: body),
          final ContactLine line => _ContactText(line, style: body),
        },
      ],
    ];
  }
}

/// An item of a list: a bullet, and the text beside it, its wrapped lines
/// hanging from the bullet rather than running back under it.
class _BulletItem extends StatelessWidget {
  const _BulletItem(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: _LegalScreenState._bulletGap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The list's shape is for the eye; each item is read as it is.
            ExcludeSemantics(
              child: Text('•', style: style.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            const Gap(Space.sm),
            Expanded(child: SelectableText(text, style: style)),
          ],
        ),
      );
}

/// A sentence with the way to reach us in it: the support address, or the
/// issue tracker by name where the build has none, as a link, and never a
/// raw web address. In Hebrew the address is isolated left to right, so it
/// keeps its order and the sentence's punctuation stays with the Hebrew.
///
/// The link is a span of the sentence, which the keyboard reaches through
/// the sentence: focused, the sentence takes the focus ring, and Enter or
/// Space opens the link.
class _ContactText extends StatefulWidget {
  const _ContactText(this.line, {required this.style});

  final ContactLine line;
  final TextStyle style;

  @override
  State<_ContactText> createState() => _ContactTextState();
}

class _ContactTextState extends State<_ContactText> {
  late final _tap = TapGestureRecognizer()..onTap = _open;
  bool _ring = false;

  void _open() {
    final target = supportEmailUri(context.l10n, subject: widget.line.subject) ?? issueTrackerUri;
    launchUrl(target).catchError((_) => false);
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final sefer = SeferColors.of(context);
    final email = AppConfig.supportEmail;
    final (before, after) = widget.line.parts;
    return FocusableActionDetector(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _open();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (shown) => setState(() => _ring = shown),
      // As wide as the sentence, which the focus ring goes around.
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: _ring
              ? ShapeDecoration(
                  shape: FocusRingBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ring: sefer.focus,
                    gap: sefer.focusGap,
                  ),
                )
              : const BoxDecoration(),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: before),
                TextSpan(
                  text: email.isEmpty ? l.feedbackLinkLabel : context.ltrRun(email),
                  // Read without the isolates around it.
                  semanticsLabel: email.isEmpty ? null : email,
                  style: TextStyle(
                    color: scheme.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: scheme.primary,
                  ),
                  recognizer: _tap,
                ),
                TextSpan(text: after),
              ],
            ),
            style: widget.style,
          ),
        ),
      ),
    );
  }
}
