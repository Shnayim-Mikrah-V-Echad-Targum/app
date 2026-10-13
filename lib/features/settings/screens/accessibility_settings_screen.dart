import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device_accessibility.dart';
import '../../../app/providers.dart';
import '../../../core/text/hebrew_text.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/paper_group.dart';
import '../../about/about_screen.dart';
import '../../reader/listen_along.dart';
import '../../reader/reader_screen.dart';
import '../app_settings.dart';
import '../widgets/settings_widgets.dart';

/// Settings → Accessibility (docs/DESIGN_SYSTEM.md §9): quick setups as cards
/// that show which are in force, each undoable, then motion and touch, what
/// screen readers and speech say, and the accessibility statement.
class AccessibilitySettingsScreen extends ConsumerWidget {
  const AccessibilitySettingsScreen({super.key});

  /// Applies [preset], saying so with a way to undo it: back to the display
  /// settings as they were, but for any changed since.
  static void _apply(BuildContext context, WidgetRef ref, DisplayPreset preset, String message) {
    final l = context.l10n;
    final notifier = ref.read(settingsProvider.notifier);
    final before = ref.read(settingsProvider);
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    notifier.update((s) => applyPreset(s, preset, darkPreferred: dark));
    final after = ref.read(settingsProvider);
    showStatus(
      context,
      message,
      action: SnackBarAction(
        label: l.actionUndo,
        onPressed: () => notifier.update((s) => undoDisplayChange(s, before: before, after: after)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    void update(AppSettings Function(AppSettings) f) => ref.read(settingsProvider.notifier).update(f);
    // The device's Reduce motion is in force whatever the app's says: the
    // switch shows it on, and leaves it to the device's settings.
    final deviceReduced = DeviceAccessibility.disableAnimationsOf(context);
    final presets = [
      (DisplayPreset.largePrint, l.presetLargePrint, l.presetLargePrintDesc, Icons.format_size),
      (DisplayPreset.dyslexia, l.presetDyslexia, l.presetDyslexiaDesc, Icons.spellcheck),
      (DisplayPreset.highContrast, l.presetHighContrast, l.presetHighContrastDesc, Icons.contrast),
      (DisplayPreset.lowVision, l.presetLowVision, l.presetLowVisionDesc, Icons.visibility_outlined),
    ];
    final cards = [
      for (final (preset, title, description, icon) in presets)
        _PresetCard(
          icon: icon,
          title: title,
          description: description,
          active: presetActive(s, preset),
          onTap: () => _apply(context, ref, preset, l.presetApplied(title)),
        ),
    ];

    return SettingsPage(
      title: l.settingsAccessibility,
      paper: true,
      children: [
        GroupHeader(l.presetsTitle),
        for (var row = 0; row < cards.length; row += 2) ...[
          if (row > 0) const Gap(Space.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[row]),
                const SizedBox(width: Space.md),
                Expanded(child: cards[row + 1]),
              ],
            ),
          ),
        ],
        const Gap(Space.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _FlushStart(
            child: TextButton.icon(
              icon: const Icon(Icons.restart_alt),
              label: Text(l.presetReset),
              onPressed: () => _apply(context, ref, DisplayPreset.reset, l.displayResetDone),
            ),
          ),
        ),
        const Gap(Space.xs),
        PaperGroup(
          children: [
            PaperRow(
              icon: Icons.text_fields_outlined,
              title: l.settingsDisplay,
              subtitle: l.settingsDisplayDesc,
              onTap: () => context.push('/settings/display'),
            ),
          ],
        ),
        GroupHeader(l.a11yGroupMotion),
        PaperGroup(
          children: [
            SwitchRow(
              icon: Icons.motion_photos_off_outlined,
              title: l.reduceMotion,
              subtitle: deviceReduced ? l.settingOnInDevice : l.reduceMotionDesc,
              value: s.reduceMotion || deviceReduced,
              onChanged: deviceReduced ? null : (v) => update((s) => s.copyWith(reduceMotion: v)),
            ),
            SwitchRow(
              icon: Icons.vibration_outlined,
              title: l.haptics,
              value: s.haptics,
              onChanged: (v) => update((s) => s.copyWith(haptics: v)),
            ),
            // Only where the reader takes single keys: elsewhere its shortcuts
            // all need Ctrl or ⌘ (WCAG 2.1.4).
            if (ReaderScreen.singleKeyPlatform)
              SwitchRow(
                icon: Icons.keyboard_outlined,
                title: l.singleKeyShortcuts,
                subtitle: l.singleKeyShortcutsDesc,
                value: s.singleKeyShortcuts,
                onChanged: (v) => update((s) => s.copyWith(singleKeyShortcuts: v)),
              ),
          ],
        ),
        ChoiceGroup<ScreenReaderText>(
          title: l.screenReaderText,
          value: s.screenReaderText,
          choices: [
            Choice(ScreenReaderText.simplified, l.srSimplified),
            Choice(ScreenReaderText.consonants, l.srConsonants),
            Choice(ScreenReaderText.allMarks, l.srAllMarks),
          ],
          onChanged: (v) => update((s) => s.copyWith(screenReaderText: v)),
        ),
        ChoiceGroup<DivineNameSpeech>(
          title: l.divineNameLabel,
          value: s.divineName,
          choices: [
            // Written with a hyphen, which a screen reader would spell out.
            Choice(DivineNameSpeech.adonai, l.divineAdonai, semanticsLabel: l.divineAdonaiSpoken),
            Choice(DivineNameSpeech.hashem, l.divineHashem),
          ],
          onChanged: (v) => update((s) => s.copyWith(divineName: v)),
        ),
        GroupHeader(l.a11yGroupSpeech),
        PaperGroup(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xs),
              child: LabeledSlider(
                title: l.speechRate,
                value: s.speechRate,
                min: 0.1,
                max: 1.0,
                step: 0.05,
                format: (v) => speechRateLabel(l, v),
                onChanged: (v) => update((s) => s.copyWith(speechRate: v)),
              ),
            ),
          ],
        ),
        GroupHeader(l.a11yGroupMore),
        PaperGroup(
          children: [
            PaperRow(
              icon: Icons.accessibility_new_outlined,
              title: l.accessibilityStatement,
              onTap: () => context.push('/settings/accessibility/legal/accessibility'),
            ),
            PaperRow(
              icon: Icons.feedback_outlined,
              title: l.sendFeedback,
              onTap: () => sendFeedback(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}

/// A text button at the start of the line, its icon on the column's edge.
class _FlushStart extends StatelessWidget {
  const _FlushStart({required this.child});

  final Widget child;

  /// A text button's padding before its icon.
  static const _inset = 12.0;

  @override
  Widget build(BuildContext context) => Transform.translate(
        offset: Offset(Directionality.of(context) == TextDirection.rtl ? _inset : -_inset, 0),
        child: child,
      );
}

/// A quick setup, as a card 88 high at least (§9 Accessibility): its icon in
/// primary, its name and one line on what it does. One in force is washed in
/// primaryContainer and checked, and reads as selected.
class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool active;
  final VoidCallback onTap;

  static const _radius = BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sefer = SeferColors.of(context);
    final text = theme.textTheme;
    final ink = active ? scheme.onPrimaryContainer : scheme.onSurface;
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: active,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: _radius,
            border: Border.all(
              color: active ? scheme.primary : sefer.hairline,
              width: active ? sefer.hairlineWidth + 1 : sefer.hairlineWidth,
            ),
          ),
          child: Material(
            color: active ? scheme.primaryContainer : sefer.paper,
            borderRadius: _radius,
            child: SeferInkWell(
              onTap: onTap,
              borderRadius: _radius,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 88),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 24, color: scheme.primary),
                          const Spacer(),
                          if (active) Icon(Icons.check_circle, size: 20, color: scheme.primary),
                        ],
                      ),
                      // 88 high in all, with the icon's own room below it.
                      const Gap(2),
                      Text(title, style: text.titleSmall?.copyWith(color: ink)),
                      Text(
                        description,
                        style: text.bodySmall?.copyWith(color: active ? ink : scheme.onSurfaceVariant),
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
