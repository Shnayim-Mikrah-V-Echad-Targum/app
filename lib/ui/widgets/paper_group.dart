import 'package:flutter/material.dart';

import '../theme/focus.dart';
import '../theme/sefer_colors.dart';
import 'ornaments.dart';

/// Rows on one sheet of paper (docs/DESIGN_SYSTEM.md §6.3): a card with no
/// padding, its rows separated by hairlines. It replaces runs of separate
/// cards and list tiles.
///
/// A hairline starts where the text of the row above it does: 54 in under a
/// [PaperRow] with an icon, 16 under any other row. It runs to the card's end
/// edge.
class PaperGroup extends StatelessWidget {
  const PaperGroup({super.key, required this.children});

  final List<Widget> children;

  static const double iconInset = PaperRow._start + PaperRow._iconSlot;
  static const double plainInset = PaperRow._start;
  static const _corner = Radius.circular(12);

  @override
  Widget build(BuildContext context) {
    final sefer = SeferColors.of(context);
    final direction = Directionality.of(context);
    final last = children.length - 1;
    return Card(
      // Not clipped, so a row's focus ring shows whole; each row rounds its
      // own ink to the card's corners instead.
      clipBehavior: Clip.none,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed)
            _RowPlace(
              corners: BorderRadius.vertical(
                top: i == 0 ? _corner : Radius.zero,
                bottom: i == last ? _corner : Radius.zero,
              ),
              child: i == last
                  ? child
                  : CustomPaint(
                      // Under the row and inside its bottom edge, so the row's
                      // focus ring, drawn just outside it, never crosses it.
                      painter: _RowRule(
                        color: sefer.hairline,
                        width: sefer.hairlineWidth,
                        inset: child is PaperRow && child.icon != null ? iconInset : plainInset,
                        direction: direction,
                      ),
                      child: child,
                    ),
            ),
        ],
      ),
    );
  }
}

/// The corners a row of a [PaperGroup] rounds its ink and focus ring to: the
/// card's, at the top of the first row and the bottom of the last.
class _RowPlace extends InheritedWidget {
  const _RowPlace({required this.corners, required super.child});

  final BorderRadius corners;

  static BorderRadius? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_RowPlace>()?.corners;

  @override
  bool updateShouldNotify(_RowPlace old) => old.corners != corners;
}

class _RowRule extends CustomPainter {
  const _RowRule({required this.color, required this.width, required this.inset, required this.direction});

  final Color color;
  final double width;
  final double inset;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final ltr = direction == TextDirection.ltr;
    canvas.drawRect(
      Rect.fromLTRB(ltr ? inset : 0, size.height - width, ltr ? size.width : size.width - inset, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_RowRule old) =>
      old.color != color || old.width != width || old.inset != inset || old.direction != direction;
}

/// One row of a [PaperGroup]: an optional icon, a title and subtitle, and at
/// the end an optional value, a [trailing] widget and a chevron.
///
/// It is 56 high with one line and 72 with a subtitle, and reads to a screen
/// reader as one item: its text, and its tap if it has one. The chevron shows
/// when the row can be tapped, unless [chevron] says otherwise; it points the
/// other way in Hebrew.
///
/// A [trailing] control, such as a menu button or a text button, keeps an item
/// of its own beside the row's, so a screen reader reaches both actions:
/// merged into the row, its action would replace the row's. Set
/// [mergeTrailing] for a switch or checkbox that the row's tap also toggles,
/// so that the row and its state read as one item.
class PaperRow extends StatelessWidget {
  const PaperRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.mergeTrailing = false,
    this.onTap,
    bool? chevron,
  }) : chevron = chevron ?? onTap != null;

  final IconData? icon;
  final String title;

  /// At most two lines, unless the text is enlarged.
  final String? subtitle;

  /// The current setting, such as a language, at the end of the row.
  final String? value;
  final Widget? trailing;

  /// Whether [trailing] reads as part of the row (a switch the row toggles)
  /// rather than as a control of its own.
  final bool mergeTrailing;

  final VoidCallback? onTap;
  final bool chevron;

  static const double _start = 16;
  static const double _iconSlot = 38;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final muted = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final titleStyle = text.bodyLarge!.copyWith(color: scheme.onSurface);
    final end = <Widget>[
      ?trailing,
      if (chevron) Icon(Icons.chevron_right, size: 20, color: scheme.outline),
    ];
    final scaler = MediaQuery.textScalerOf(context);
    // Text is never cut short once it is enlarged (WCAG 1.4.4).
    final enlarged = scaler.scale(1) > 1;
    // A value ends the title's line. With a subtitle under them, the icon and
    // the end of the row line up with that line too, rather than with the
    // middle of the row, so the value and chevron stay side by side.
    final onTitleLine = value != null && subtitle != null;
    final titleLine = scaler.scale(titleStyle.fontSize!) * titleStyle.height!;
    Widget place(Widget child, AlignmentGeometry alignment) => onTitleLine
        ? ConstrainedBox(
            constraints: BoxConstraints(minHeight: titleLine),
            child: Align(alignment: alignment, widthFactor: 1, heightFactor: 1, child: child),
          )
        : child;
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: subtitle == null ? 56 : 72),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(_start, 12, 12, 12),
        child: Row(
          crossAxisAlignment: onTitleLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            if (icon != null)
              SizedBox(
                width: _iconSlot,
                child: place(
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    heightFactor: 1,
                    child: Icon(icon, size: 22, color: scheme.onSurfaceVariant),
                  ),
                  AlignmentDirectional.centerStart,
                ),
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (value == null)
                    Text(title, style: titleStyle)
                  else
                    // The value sits at the end of the title's line, or under
                    // the title when the two don't fit side by side.
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        children: [Text(title, style: titleStyle), Text(value!, style: muted)],
                      ),
                    ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: muted,
                      maxLines: enlarged ? null : 2,
                      overflow: enlarged ? null : TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            for (final (i, widget) in end.indexed)
              Padding(
                // A chevron straight after a value stays close to it.
                padding: EdgeInsetsDirectional.only(start: i == 0 && (value == null || trailing != null) ? 12 : 4),
                child: place(widget, Alignment.center),
              ),
          ],
        ),
      ),
    );
    final row = Semantics(
      // Its own item: the text and the tap gather here, while a trailing
      // control below keeps its own (unless merged, below).
      container: true,
      button: onTap != null,
      child: onTap == null
          ? content
          : SeferInkWell(
              onTap: onTap,
              borderRadius: _RowPlace.of(context) ?? const BorderRadius.all(PaperGroup._corner),
              child: content,
            ),
    );
    return trailing != null && mergeTrailing ? MergeSemantics(child: row) : row;
  }
}

/// The heading over a [PaperGroup]: an eyebrow 28 below the content above,
/// 8 above the group and inset 4, and a level-2 heading for screen readers.
class GroupHeader extends StatelessWidget {
  const GroupHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 28, 0, 8),
        child: Semantics(header: true, headingLevel: 2, child: Eyebrow(text)),
      );
}
