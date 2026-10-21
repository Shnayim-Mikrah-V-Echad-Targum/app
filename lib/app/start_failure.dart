import 'dart:math' as math;

import 'package:flutter/material.dart' show ButtonStyleButton, ColorScheme, Icons, TextTheme;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../features/settings/app_settings.dart' show UiFont;
import '../l10n/app_localizations.dart';
import '../services/recent_errors.dart';
import '../ui/theme/focus.dart';
import '../ui/theme/palette.dart';
import '../ui/theme/typography.dart';
import '../ui/widgets/ornaments.dart';
import 'config.dart';
import 'page_reload_stub.dart' if (dart.library.js_interop) 'page_reload_web.dart' as page;
import 'system_bars.dart';

/// What the app shows in its place when something it can't open without
/// fails as it starts, once the preferences have had their chance to recover
/// (lib/main.dart): on the web, say, a first visit's data lost to a dropped
/// connection. Without it nothing would be drawn at all: Windows shows the
/// window only with its first frame, and the web leaves its loading screen
/// up, "Still loading…" for good.
///
/// Laid out as an error state (docs/DESIGN_SYSTEM.md §6.22): the divider,
/// "Shnayim Mikrah couldn’t open." in the margin's voice, what may help, and
/// Copy details for support (after Try again, on the web, which loads the
/// page again), with the first line of each error beneath, for a screenshot.
///
/// The app's theme and translations were never set up, so, as
/// AppErrorPanel (lib/ui/widgets/fallbacks.dart), it looks up neither: its words come straight from the
/// translations, in the device's language (the first of its languages the
/// app has, else English), and its colours from the palettes, light or dark
/// as the device is set, and in high contrast where the device asks.
class StartFailureApp extends StatefulWidget {
  const StartFailureApp({super.key, this.onRetry = page.reloadPage, this.errors});

  /// What Try again does, offered only with it: on the web, loads the page
  /// again.
  final VoidCallback? onRetry;

  /// What went wrong, for support; [recentErrors] unless given.
  final RecentErrors? errors;

  /// Whether the page is in Hebrew for the device's [locales]: as Flutter
  /// resolves the app's language, the first of them that the app has
  /// decides (Locale reads an old "iw" as "he").
  static bool hebrewFor(List<Locale> locales) {
    for (final locale in locales) {
      switch (locale.languageCode) {
        case 'he':
          return true;
        case 'en':
          return false;
      }
    }
    return false;
  }

  @override
  State<StartFailureApp> createState() => _StartFailureAppState();
}

class _StartFailureAppState extends State<StartFailureApp> with WidgetsBindingObserver {
  /// The app's version and build, for the details, once the platform says.
  String _version = '';

  /// Whether the details have been copied, which the button then says.
  bool _copied = false;

  RecentErrors get _errors => widget.errors ?? recentErrors;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // In hand before the button is pressed, so that the copy is made within
    // the tap, as a browser may require.
    PackageInfo.fromPlatform().then<void>(
      (info) => _version = '${info.version} (${info.buildNumber})',
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The device's language changed: the page follows.
  @override
  void didChangeLocales(List<Locale>? locales) => setState(() {});

  Future<void> _copy(String copied, TextDirection direction) async {
    try {
      await Clipboard.setData(ClipboardData(text: _errors.report(version: _version)));
    } catch (_) {
      // Not copied, so the button doesn't say it was; the errors' first
      // lines are still on the page, for a screenshot.
      return;
    }
    if (!mounted) return;
    setState(() => _copied = true);
    // Where the platform takes announcements; elsewhere (Android) the
    // button is a live region once copied.
    if (MediaQuery.supportsAnnounceOf(context)) {
      SemanticsService.sendAnnouncement(View.of(context), copied, direction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hebrew = StartFailureApp.hebrewFor(View.of(context).platformDispatcher.locales);
    final l = lookupAppLocalizations(Locale(hebrew ? 'he' : 'en'));
    final direction = hebrew ? TextDirection.rtl : TextDirection.ltr;
    final highContrast = MediaQuery.highContrastOf(context);
    final (scheme, sefer) = switch ((MediaQuery.platformBrightnessOf(context), highContrast)) {
      (Brightness.light, false) => (Palettes.light, Palettes.seferLight),
      (Brightness.dark, false) => (Palettes.dark, Palettes.seferDark),
      (Brightness.light, true) => (Palettes.hcLight, Palettes.seferHcLight),
      (Brightness.dark, true) => (Palettes.hcDark, Palettes.seferHcDark),
    };
    TextTheme textTheme({required bool hebrew}) => AppTypography.textTheme(
          scheme: scheme,
          uiFont: UiFont.standard,
          hebrewUi: hebrew,
          highContrast: highContrast,
        );
    final text = textTheme(hebrew: hebrew);
    final marginalia =
        AppTypography.sefer(scheme: scheme, uiFont: UiFont.standard, hebrewUi: hebrew, highContrast: highContrast)
            .marginalia;
    // High contrast draws the ornaments in onSurface.
    Color ornament(Color normal) => highContrast ? scheme.onSurface : normal;
    final retry = widget.onRetry;
    final address = AppConfig.supportEmail;
    final _ButtonInks inks = (scheme: scheme, sefer: sefer, highContrast: highContrast);

    final page = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SeferDivider(
          inks: (rule: ornament(sefer.hairline), ruleWidth: sefer.hairlineWidth, lozenge: ornament(sefer.goldLeaf)),
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(l.startFailedTitle, textAlign: TextAlign.center, style: marginalia),
        ),
        const SizedBox(height: 8),
        Text(
          '${retry == null ? l.startFailedReopen : l.startFailedReload} '
          '${address.isEmpty ? l.startFailedWriteToUs : l.startFailedWriteTo(address)}',
          textAlign: TextAlign.center,
          style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (retry != null)
              _Button(
                icon: Icons.refresh,
                label: l.actionRetry,
                onPressed: retry,
                tonal: true,
                inks: inks,
                style: text.labelLarge!,
              ),
            _Button(
              icon: _copied ? Icons.check : Icons.content_copy_outlined,
              label: _copied ? l.supportDetailsCopied : l.copySupportDetails,
              onPressed: () => _copy(l.supportDetailsCopied, direction),
              // The one way on, where there is no Try again.
              tonal: retry == null,
              live: _copied && !MediaQuery.supportsAnnounceOf(context),
              inks: inks,
              style: text.labelLarge!,
            ),
          ],
        ),
        ListenableBuilder(
          listenable: _errors,
          builder: (context, _) => _errors.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _Details(
                    errors: [for (final error in _errors.errors) error.summary],
                    paper: sefer.paper,
                    border: BorderSide(color: sefer.hairline, width: sefer.hairlineWidth),
                    // In English, as the errors are, whatever the page's
                    // language.
                    style: textTheme(hebrew: false).bodySmall!.copyWith(color: sefer.dimInk),
                  ),
                ),
        ),
      ],
    );

    return SystemBars(
      colors: scheme,
      child: Directionality(
        textDirection: direction,
        // The keys a MaterialApp would give: Tab between the buttons, and
        // Enter or Space to press one. They reach the shortcuts from the
        // focus, which a route would hold: the page's scope, until a button
        // has it.
        child: Shortcuts(
          shortcuts: WidgetsApp.defaultShortcuts,
          child: Actions(
            actions: WidgetsApp.defaultActions,
            child: FocusScope(
              autofocus: true,
              child: DefaultTextStyle(
                style: text.bodyMedium!,
                child: ColoredBox(
                  color: scheme.surface,
                  child: SafeArea(
                    child: LayoutBuilder(
                      // Centred, and scrolling where large text needs it.
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: _padding,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: math.max(0, constraints.maxHeight - _padding.vertical)),
                          child: Center(
                            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: page),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _padding = EdgeInsets.all(24);
}

/// The first line of each error, left to right in either language, on a
/// slip of paper with a hairline round it, as a sheet's.
class _Details extends StatelessWidget {
  const _Details({required this.errors, required this.paper, required this.border, required this.style});

  final List<String> errors;
  final Color paper;
  final BorderSide border;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: paper,
            border: Border.fromBorderSide(border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: Text(errors.join('\n'), style: style, maxLines: 6, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      );
}

/// What a [_Button] is drawn in: its colours from [scheme] and [sefer], as
/// the theme gives its Tonal and Text buttons (docs/DESIGN_SYSTEM.md §6.5),
/// and in [highContrast] a 2 px outline round a Tonal one, whose pale fill
/// alone barely shows, and a Text one's label underlined.
typedef _ButtonInks = ({ColorScheme scheme, SeferColors sefer, bool highContrast});

/// A Tonal or a Text button with an icon, as the theme draws them, here
/// where there is no theme: at least 48 high, with corners of 10; a wash of
/// its ink, 6% hovered and 10% pressed; and, focused from the keyboard, the
/// focus ring outside it (§6.1).
class _Button extends StatefulWidget {
  const _Button({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.tonal,
    required this.inks,
    required this.style,
    this.live = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool tonal;
  final _ButtonInks inks;

  /// labelLarge, in the page's language.
  final TextStyle style;

  /// Whether screen readers hear the label as it changes.
  final bool live;

  @override
  State<_Button> createState() => _ButtonState();
}

class _ButtonState extends State<_Button> {
  bool _hovered = false;
  bool _pressed = false;
  bool _ringed = false;

  void _press() => widget.onPressed();

  @override
  Widget build(BuildContext context) {
    final (:scheme, :sefer, :highContrast) = widget.inks;
    final tonal = widget.tonal;
    final ink = tonal ? scheme.onPrimaryContainer : scheme.primary;
    final wash = _pressed ? 0.10 : (_hovered ? 0.06 : 0.0);
    final base = tonal ? scheme.primaryContainer : const Color(0x00000000);
    final side = tonal && highContrast ? BorderSide(color: scheme.outline, width: 2) : BorderSide.none;
    final radius = BorderRadius.circular(10);
    // Material's padding, which narrows as text grows, but with 8 above and
    // below large text, so that a label on two lines clears the edges.
    final padding = ButtonStyleButton.scaledPadding(
      EdgeInsetsDirectional.fromSTEB(tonal ? 16 : 12, 0, tonal ? 24 : 16, 0),
      EdgeInsetsDirectional.fromSTEB(8, 8, tonal ? 12 : 8, 8),
      const EdgeInsetsDirectional.fromSTEB(4, 8, 6, 8),
      MediaQuery.textScalerOf(context).scale(widget.style.fontSize ?? 15) / 14,
    );
    return Semantics(
      container: true,
      button: true,
      enabled: true,
      liveRegion: widget.live,
      onTap: _press,
      child: FocusableActionDetector(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _press()),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => _press()),
        },
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => _ringed = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: _press,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: Color.alphaBlend(ink.withValues(alpha: wash), base),
              shape: _ringed
                  ? FocusRingBorder(borderRadius: radius, side: side, ring: sefer.focus, gap: sefer.focusGap)
                  : RoundedRectangleBorder(borderRadius: radius, side: side),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: Padding(
                  padding: padding,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: 20, color: ink),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          style: widget.style.copyWith(
                            color: ink,
                            // A link-like button doesn't rely on colour alone.
                            decoration: !tonal && highContrast ? TextDecoration.underline : null,
                            decorationColor: ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
