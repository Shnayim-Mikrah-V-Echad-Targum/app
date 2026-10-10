import 'package:flutter/material.dart';

import '../theme/focus.dart';
import '../theme/sefer_colors.dart';
import 'app_icon.dart';
import 'ornaments.dart';

/// Rows on one sheet of paper (docs/DESIGN_SYSTEM.md §6.3): a card with no
/// padding, its rows separated by hairlines. It replaces runs of separate
/// cards and list tiles.
///
/// A hairline starts where the text of the row above it does: 54 in under a
/// [PaperRow] with an icon, 16 under any other row, or [ruleInset] where
/// given, for rows of another kind with something before their text. It runs
/// to the card's end edge.
class PaperGroup extends StatelessWidget {
  const PaperGroup({super.key, required this.children, this.ruleInset});

  final List<Widget> children;
  final double? ruleInset;

  static const double iconInset = PaperRow._start + PaperRow._iconSlot;
  static const double plainInset = PaperRow._start;
  static const _corner = Radius.circular(12);

  /// The corners a row at [context] rounds its ink and focus ring to: the
  /// card's own at the top of the first row and the bottom of the last. A
  /// [PaperRow] rounds to them, and so can a row of another kind.
  static BorderRadius rowCorners(BuildContext context) => _RowPlace.of(context) ?? const BorderRadius.all(_corner);

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
                        inset: ruleInset ?? (child is PaperRow && child.icon != null ? iconInset : plainInset),
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

/// One row of a [PaperGroup], built on its own: for a list long enough to be
/// built only as it scrolls into view (a forum's threads), whose rows can't
/// all sit in one card. Each draws its share of the card: the paper, the
/// outline at its sides, the outline's rounded top on the [first] row and
/// its rounded foot on the [last], and the hairline under every row but the
/// last, inset as [PaperGroup] insets it. Rows one after another read as one
/// group.
class PaperGroupRow extends StatelessWidget {
  const PaperGroupRow({super.key, required this.first, required this.last, this.ruleInset, required this.child});

  final bool first;
  final bool last;

  /// Where the hairline under the row starts, as [PaperGroup.ruleInset].
  final double? ruleInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sefer = SeferColors.of(context);
    final card = theme.cardTheme;
    final side = switch (card.shape) {
      RoundedRectangleBorder(:final side) => side,
      _ => BorderSide.none,
    };
    final corners = BorderRadius.vertical(
      top: first ? PaperGroup._corner : Radius.zero,
      bottom: last ? PaperGroup._corner : Radius.zero,
    );
    final child = this.child;
    return _RowPlace(
      corners: corners,
      child: CustomPaint(
        painter: _PaperShare(
          color: card.color ?? sefer.paper,
          side: side,
          corners: corners,
          first: first,
          last: last,
          rule: last
              ? null
              : _RowRule(
                  color: sefer.hairline,
                  width: sefer.hairlineWidth,
                  inset: ruleInset ?? (child is PaperRow && child.icon != null ? PaperGroup.iconInset : PaperGroup.plainInset),
                  direction: Directionality.of(context),
                ),
        ),
        // The row's ink shows on its own paper, as on the card's.
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

/// A [PaperGroupRow]'s share of the card: its paper, and the outline at its
/// sides, closed at the top of the first row and the foot of the last.
class _PaperShare extends CustomPainter {
  const _PaperShare({
    required this.color,
    required this.side,
    required this.corners,
    required this.first,
    required this.last,
    this.rule,
  });

  final Color color;
  final BorderSide side;
  final BorderRadius corners;
  final bool first;
  final bool last;
  final _RowRule? rule;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(corners.toRRect(rect), Paint()..color = color);
    rule?.paint(canvas, size);
    if (side.style == BorderStyle.none || side.width == 0) return;
    // The outline inside the edge, as the card draws it, run on past an end
    // that a row continues and clipped there, so that rows join seamlessly.
    final w = side.width;
    final run = Rect.fromLTRB(0, first ? 0 : -2 * w, size.width, last ? size.height : size.height + 2 * w);
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRRect(
      corners.toRRect(run).deflate(w / 2),
      Paint()
        ..color = side.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PaperShare old) =>
      old.color != color ||
      old.side != side ||
      old.corners != corners ||
      old.first != first ||
      old.last != last ||
      (old.rule == null) != (rule == null) ||
      (rule != null && rule!.shouldRepaint(old.rule!));
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
/// so that the row and its state read as one item. A trailing button with a
/// label (a [TextButton], say) ends the title's line as a value does, and
/// moves under the title when the two don't fit side by side, rather than
/// squeeze the title until its words break (large text).
class PaperRow extends StatelessWidget {
  const PaperRow({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
    this.value,
    this.trailing,
    this.mergeTrailing = false,
    this.onTap,
    this.selected,
    this.focusNode,
    bool? chevron,
  }) : chevron = chevron ?? onTap != null;

  final IconData? icon;

  /// onSurfaceVariant unless given: the grace shield is in its own colour.
  final Color? iconColor;
  final String title;

  /// At most two lines, unless the text is enlarged.
  final String? subtitle;

  /// bodyLarge in onSurface, merged with this where given: a list of places
  /// to go, such as the forums, sets its titles in titleMedium.
  final TextStyle? titleStyle;

  /// bodyMedium in onSurfaceVariant, merged with this where given.
  final TextStyle? subtitleStyle;

  /// The current setting, such as a language, at the end of the row.
  final String? value;
  final Widget? trailing;

  /// Whether [trailing] reads as part of the row (a switch the row toggles)
  /// rather than as a control of its own.
  final bool mergeTrailing;

  final VoidCallback? onTap;

  /// Whether the row is the one chosen of a list, for screen readers; null
  /// for a row that isn't one of a choice.
  final bool? selected;

  final bool chevron;

  /// The focus node of the row's ink well, for a row given the focus when
  /// the control that had it goes; null for its own.
  final FocusNode? focusNode;

  static const double _start = 16;
  static const double _iconSlot = 38;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final muted = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final titleStyle = text.bodyLarge!.copyWith(color: scheme.onSurface).merge(this.titleStyle);
    final subtitleStyle = muted?.merge(this.subtitleStyle);
    // A labelled button goes with the title, as a value does, rather than
    // after it.
    final trailing = this.trailing;
    final besideTitle = value == null && trailing is ButtonStyleButton ? trailing : null;
    final end = <Widget>[
      if (besideTitle == null) ?trailing,
      if (chevron) Icon(Icons.chevron_right, size: 20, color: scheme.outline),
    ];
    final scaler = MediaQuery.textScalerOf(context);
    // Text is never cut short once it is enlarged (WCAG 1.4.4).
    final enlarged = scaler.scale(1) > 1;
    // A value ends the title's line. With a subtitle under them, the icon and
    // the end of the row line up with that line too, rather than with the
    // middle of the row, so the value and chevron stay side by side.
    final onTitleLine = value != null && subtitle != null;
    Widget place(Widget child, AlignmentGeometry alignment) => onTitleLine
        ? ConstrainedBox(
            constraints: BoxConstraints(minHeight: scaler.scale(titleStyle.fontSize ?? 16) * (titleStyle.height ?? 1.5)),
            child: Align(alignment: alignment, widthFactor: 1, heightFactor: 1, child: child),
          )
        : child;
    // The title, and at the end of its line a value or a labelled button,
    // which move under it when the two don't fit side by side.
    Widget titleWith(Widget other) => SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [Text(title, style: titleStyle), other],
          ),
        );
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
                    child: AppIcon(icon!, size: 22, color: iconColor ?? scheme.onSurfaceVariant),
                  ),
                  AlignmentDirectional.centerStart,
                ),
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (value case final value?)
                    titleWith(Text(value, style: muted))
                  else if (besideTitle != null)
                    titleWith(besideTitle)
                  else
                    Text(title, style: titleStyle),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: subtitleStyle,
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
      selected: selected,
      child: onTap == null
          ? content
          : SeferInkWell(
              focusNode: focusNode,
              onTap: onTap,
              borderRadius: PaperGroup.rowCorners(context),
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
