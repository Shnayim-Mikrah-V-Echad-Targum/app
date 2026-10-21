import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/feedback.dart';
import '../../services/web_install.dart';
import '../../ui/l10n.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/lines.dart';
import '../../ui/widgets/paper_group.dart';

/// Whether the web app runs on a phone or a tablet, whose home screen it is
/// added to, rather than on a computer, where it is installed in a window.
bool get _onPhone => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

/// The rows of the ways to install the app here ([installOptionsProvider]),
/// for About's group and the sheet Settings opens (docs/DESIGN_SYSTEM.md §9
/// About, Install the app): the browser's own dialog, "Add to home screen"
/// or "Install on this computer", which does what it says (no chevron); and
/// the device's own way, each opening a sheet: Safari's Add to Home Screen
/// on an iPhone, the Android app (APK), the Windows app. In a sheet, a row
/// closes it first ([close]), and what it opens opens from [opener], the
/// page beneath.
List<Widget> installOptionRows(
  BuildContext context,
  WidgetRef ref,
  List<InstallOption> options, {
  VoidCallback? close,
  BuildContext? opener,
}) {
  final l = context.l10n;
  VoidCallback opens(Future<void> Function(BuildContext context) show) => () {
        close?.call();
        unawaited(show(opener ?? context));
      };
  return [
    for (final option in options)
      switch (option) {
        InstallOption.prompt => PaperRow(
            icon: _onPhone ? Icons.add_to_home_screen : Icons.install_desktop,
            title: _onPhone ? l.installHomeScreen : l.installDesktop,
            subtitle: _onPhone ? l.installHomeScreenDesc : l.installDesktopDesc,
            subtitleMaxLines: null,
            chevron: false,
            onTap: () {
              // Within the tap, which the browser asks of its dialog.
              unawaited(promptInstall(ref));
              close?.call();
            },
          ),
        InstallOption.homeScreenSteps => PaperRow(
            icon: Icons.ios_share,
            title: l.installIosTitle,
            subtitle: l.installIosDesc,
            subtitleMaxLines: null,
            onTap: opens(showHomeScreenSteps),
          ),
        InstallOption.apk => PaperRow(
            icon: Icons.android,
            title: l.installApkTitle,
            subtitle: l.installApkDesc,
            subtitleMaxLines: null,
            onTap: opens(showApkSheet),
          ),
        InstallOption.windows => PaperRow(
            icon: Icons.desktop_windows_outlined,
            title: l.installWindowsTitle,
            subtitle: l.installWindowsDesc,
            subtitleMaxLines: null,
            onTap: opens(showWindowsAppSheet),
          ),
      },
  ];
}

/// Asks the browser to install the app, as the reader's tap asks: it shows
/// its own dialog, and the app's rows and card go once it is installed.
Future<void> promptInstall(WidgetRef ref) => ref.read(installOptionsProvider.notifier).prompt();

/// About's "Install the app", on the web where the app isn't installed and
/// there is a way to install it here: its heading and its rows.
class InstallSection extends ConsumerWidget {
  const InstallSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(installOptionsProvider);
    if (options.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupHeader(context.l10n.installTitle),
        PaperGroup(children: installOptionRows(context, ref, options)),
      ],
    );
  }
}

/// Settings' "Install the app", on the web where there is a way to install
/// it here: a row that opens the ways in a sheet ([showInstallSheet]).
class InstallAppRow extends StatelessWidget {
  const InstallAppRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PaperRow(
      icon: _onPhone ? Icons.install_mobile : Icons.install_desktop,
      title: l.installTitle,
      subtitle: l.installDesc,
      subtitleMaxLines: null,
      onTap: () => showInstallSheet(context),
    );
  }
}

/// The ways to install the app here, in a sheet over the whole window: its
/// title, then About's rows on one PaperGroup. Choosing one closes it, and
/// what that opens opens in its place.
Future<void> showInstallSheet(BuildContext context) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (sheet) => Consumer(
        builder: (sheet, ref, _) {
          final options = ref.watch(installOptionsProvider);
          final navigator = Navigator.of(sheet);
          return _SheetBody(
            title: sheet.l10n.installTitle,
            children: [
              PaperGroup(
                children: installOptionRows(
                  sheet,
                  ref,
                  options,
                  // At once, before what the row opens comes in its place.
                  close: () => navigator.pop(),
                  opener: context.mounted ? context : null,
                ),
              ),
            ],
          );
        },
      ),
    );

/// Safari's Add to Home Screen, which only the reader can choose, step by
/// step: Share, then "Add to Home Screen", then Add, each with the mark
/// Safari shows for it; then that the app on the home screen keeps a
/// reading of its own, which a backup brings over.
Future<void> showHomeScreenSteps(BuildContext context) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) {
        final l = context.l10n;
        return _SheetBody(
          title: l.installIosTitle,
          children: [
            _Step(number: 1, text: l.installIosStep1, icon: Icons.ios_share),
            _Step(number: 2, text: l.installIosStep2, icon: Icons.add_box_outlined),
            _Step(number: 3, text: l.installIosStep3),
            const Gap(Space.sm),
            NoticeBanner(icon: Icons.backup_outlined, text: l.installIosBackup),
          ],
        );
      },
    );

/// The Android app: that it opens this website as an app, how to install
/// its APK, and the releases page, where it is.
Future<void> showApkSheet(BuildContext context) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) {
        final l = context.l10n;
        return _SheetBody(
          title: l.installApkTitle,
          children: [
            BalancedText(l.installApkBody, style: _body(context), textAlign: TextAlign.start),
            const Gap(Space.lg),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: () => _openReleases(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(l.installReleases),
              ),
            ),
          ],
        );
      },
    );

/// The Windows app: the one line that installs it in PowerShell, to copy,
/// and the releases page, for its installer (an MSI).
Future<void> showWindowsAppSheet(BuildContext context) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) {
        final l = context.l10n;
        return _SheetBody(
          title: l.installWindowsTitle,
          children: [
            BalancedText(l.installWindowsBody, style: _body(context), textAlign: TextAlign.start),
            const Gap(Space.md),
            const CommandBox(command: kWindowsInstallCommand),
            const Gap(Space.lg),
            BalancedText(l.installWindowsMsi, style: _body(context), textAlign: TextAlign.start),
            const Gap(Space.sm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => _openReleases(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(l.installReleases),
              ),
            ),
          ],
        );
      },
    );

TextStyle? _body(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface);
}

Future<void> _openReleases(BuildContext context) async {
  final opened = await launchUrl(kReleasesPage).catchError((_) => false);
  if (!opened && context.mounted) showStatus(context, context.l10n.linkOpenFailed);
}

/// A sheet's title and what follows it, within its padding, scrolling at
/// large text.
class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final padding = sheetPadding(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(title),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ],
        ),
      ),
    );
  }
}

/// One step of Add to Home Screen: its number on a disc of the banners'
/// paper, the step, and the mark Safari shows for it, for the eye alone.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text, this.icon});

  final int number;
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = _body(context)!;
    final line = MediaQuery.textScalerOf(context).scale(style.fontSize!) * (style.height ?? 1.4);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level with the step's first line.
            Padding(
              padding: EdgeInsets.only(top: (line - 28).clamp(0, double.infinity) / 2),
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: scheme.secondaryContainer, shape: BoxShape.circle),
                child: Text(
                  '$number',
                  textScaler: TextScaler.noScaling,
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSecondaryContainer),
                ),
              ),
            ),
            const Gap(Space.md),
            // Its lines even, leaving no word alone on the last.
            Expanded(child: BalancedText(text, style: style, textAlign: TextAlign.start)),
            if (icon case final icon?) ...[
              const Gap(Space.md),
              Padding(
                padding: EdgeInsets.only(top: (line - 24).clamp(0, double.infinity) / 2),
                child: ExcludeSemantics(child: Icon(icon, size: 24, color: scheme.onSurfaceVariant)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A command to paste, [command], as it is typed, left to right in either
/// language, selectable, on a panel of its own, with Copy beneath it, which
/// says Copied once it has.
class CommandBox extends StatefulWidget {
  const CommandBox({super.key, required this.command});

  final String command;

  @override
  State<CommandBox> createState() => _CommandBoxState();
}

class _CommandBoxState extends State<CommandBox> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.command));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sefer = SeferColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(color: sefer.isHighContrast ? scheme.outline : scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                widget.command,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface, height: 1.5),
              ),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Semantics(
            liveRegion: _copied,
            child: TextButton.icon(
              onPressed: _copy,
              icon: Icon(_copied ? Icons.check : Icons.content_copy_outlined, size: 18),
              label: Text(_copied ? l.installCopied : l.actionCopy),
            ),
          ),
        ),
      ],
    );
  }
}

/// Whether Today offers to install the app ([InstallCard]): on the web, on a
/// phone-sized screen of a phone, where the app isn't installed and there is
/// a way to install it, until the card is put away.
bool offersInstallCard(BuildContext context, WidgetRef ref) =>
    _onPhone &&
    MediaQuery.sizeOf(context).width < Breakpoints.medium &&
    ref.watch(installOptionsProvider).isNotEmpty &&
    !ref.watch(installCardDismissedProvider);

/// Today's offer to install the app, on a phone's browser
/// ([offersInstallCard]): a NoticeBanner (§6.20), "Add Shnayim Mikrah to
/// your home screen, and open it like any app.", with Install and a close
/// button. Install asks the browser where it offers to, and otherwise opens
/// the device's own way: Safari's steps, or the Android app. Put away, it
/// never comes back; the ways stay in About and Settings.
class InstallCard extends ConsumerWidget {
  const InstallCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final options = ref.watch(installOptionsProvider);
    return NoticeBanner(
      icon: Icons.install_mobile,
      text: l.installCardText,
      actionBelow: true,
      action: TextButton(
        onPressed: () => switch (options.firstOrNull) {
          InstallOption.prompt => unawaited(promptInstall(ref)),
          InstallOption.homeScreenSteps => unawaited(showHomeScreenSteps(context)),
          InstallOption.apk => unawaited(showApkSheet(context)),
          InstallOption.windows => unawaited(showWindowsAppSheet(context)),
          null => null,
        },
        child: Text(l.installAction),
      ),
      onDismiss: () => ref.read(installCardDismissedProvider.notifier).dismiss(),
      dismissLabel: l.actionDismiss,
    );
  }
}
