import 'package:flutter/material.dart';

import '../theme/focus.dart';
import '../theme/layout.dart';
import '../theme/sefer_colors.dart';
import 'app_icon.dart';
import 'lang.dart';
import 'lines.dart';
import 'ornaments.dart';

/// Rows on one sheet of paper (docs/DESIGN_SYSTEM.md §6.3): a card with no
/// padding, its rows separated by hairlines. It replaces runs of separate
/// cards and list tiles.
///
/// A hairline starts where the text of the row above it does: 54 in under a
/// [PaperRow] with an icon (or a leading widget), 16 under any other row, or
/// [ruleInset] where given, for rows of another kind with something before
/// their text; but 16 under a paper row, wherever it is in the row above,
/// that has stacked its icon over its text, all of which then starts there.
/// It runs to the card's end edge.
class PaperGroup extends StatelessWidget {
  const PaperGroup({super.key, required this.children, this.ruleInset});

  final List<Widget> children;

  /// Where every hairline starts, for rows of another kind whose text
  /// starts past a leading mark of their own.
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
    Widget place(int i, Widget child) {
      final corners = BorderRadius.vertical(
        top: i == 0 ? _corner : Radius.zero,
        bottom: i == last ? _corner : Radius.zero,
      );
      if (i == last) return _RowPlace(corners: corners, child: child);
      final start = ValueNotifier<double?>(null);
      return _RowPlace(
        corners: corners,
        ruleStart: start,
        child: CustomPaint(
          // Under the row and inside its bottom edge, so the row's focus
          // ring, drawn just outside it, never crosses it.
          painter: _RowRule(
            color: sefer.hairline,
            width: sefer.hairlineWidth,
            inset: ruleInset ?? (child is PaperRow && child._hasLead ? iconInset : plainInset),
            direction: direction,
            start: start,
          ),
          child: child,
        ),
      );
    }

    return Card(
      // Not clipped, so a row's focus ring shows whole; each row rounds its
      // own ink to the card's corners instead.
      clipBehavior: Clip.none,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final (i, child) in children.indexed) place(i, child)],
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
    final start = last ? null : ValueNotifier<double?>(null);
    return _RowPlace(
      corners: corners,
      ruleStart: start,
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
                  inset: ruleInset ?? (child is PaperRow && child._hasLead ? PaperGroup.iconInset : PaperGroup.plainInset),
                  direction: Directionality.of(context),
                  start: start,
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
///
/// A row's focus ring is drawn just outside it, so its foot lies over the
/// next row, which is painted after it. Every row but the last therefore
/// lays its paper [_overlap] past its foot, and every row but the first
/// leaves as much of its own top to the row above, so the next row's paper
/// never covers the ring.
class _PaperShare extends CustomPainter {
  _PaperShare({
    required this.color,
    required this.side,
    required this.corners,
    required this.first,
    required this.last,
    this.rule,
  }) : super(repaint: rule?.start);

  final Color color;
  final BorderSide side;
  final BorderRadius corners;
  final bool first;
  final bool last;
  final _RowRule? rule;

  /// As far as a focus ring reaches outside its row: [SeferInkWell]'s 3, or
  /// a button's ring with its gap.
  static const double _overlap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(0, first ? 0 : _overlap, size.width, last ? size.height : size.height + _overlap);
    canvas.drawRRect(corners.toRRect(rect), Paint()..color = color);
    rule?.paint(canvas, size);
    if (side.style == BorderStyle.none || side.width == 0) return;
    // The outline inside the edge, as the card draws it, run on past an end
    // that a row continues and clipped there, so that rows join seamlessly.
    final w = side.width;
    final run = Rect.fromLTRB(0, first ? 0 : -2 * w, size.width, last ? size.height : rect.bottom + 2 * w);
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
/// card's, at the top of the first row and the bottom of the last. And where
/// the hairline under it starts, should a [PaperRow] in it say ([ruleStart]):
/// null for the group's own inset.
class _RowPlace extends InheritedWidget {
  const _RowPlace({required this.corners, this.ruleStart, required super.child});

  final BorderRadius corners;

  /// None for the last row, which has no hairline under it.
  final ValueNotifier<double?>? ruleStart;

  static BorderRadius? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_RowPlace>()?.corners;

  /// Where a row at [context] says the hairline under it starts. A new one
  /// each time the group builds, so that its rows say again.
  static ValueNotifier<double?>? ruleStartOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RowPlace>()?.ruleStart;

  @override
  bool updateShouldNotify(_RowPlace old) => old.corners != corners || old.ruleStart != ruleStart;
}

class _RowRule extends CustomPainter {
  _RowRule({required this.color, required this.width, required this.inset, required this.direction, this.start})
      : super(repaint: start);

  final Color color;
  final double width;
  final double inset;
  final TextDirection direction;

  /// Where the row above says the hairline starts, if it says, in place of
  /// [inset].
  final ValueNotifier<double?>? start;

  @override
  void paint(Canvas canvas, Size size) {
    final ltr = direction == TextDirection.ltr;
    final inset = start?.value ?? this.inset;
    canvas.drawRect(
      Rect.fromLTRB(ltr ? inset : 0, size.height - width, ltr ? size.width : size.width - inset, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_RowRule old) =>
      old.color != color ||
      old.width != width ||
      old.inset != inset ||
      old.direction != direction ||
      old.start != start;
}

/// One row of a [PaperGroup]: an optional icon (or [leading] widget), a title
/// and subtitle, and at the end an optional value, a [trailing] widget and a
/// chevron.
///
/// It is 56 high with one line and 72 with a subtitle or a detail line, and
/// reads to a screen reader as one item: its text, and its tap if it has
/// one. The chevron shows when the row can be tapped, unless [chevron] says
/// otherwise; it points the other way in Hebrew. With a detail line, the icon
/// and chevron line up with the title's line rather than the row's middle.
///
/// A [trailing] control, such as a menu button or a text button, keeps an item
/// of its own beside the row's, so a screen reader reaches both actions:
/// merged into the row, its action would replace the row's. Set
/// [mergeTrailing] for a switch or checkbox that the row's tap also toggles,
/// so that the row and its state read as one item, in the control's role. A
/// trailing button with a
/// label (a [TextButton], say) ends the title's line as a value does, and
/// moves under the title when the two don't fit side by side, rather than
/// squeeze the title until its words break (large text).
///
/// Where text so large would leave the title and subtitle a word or two a
/// line between the icon and the controls at the end ([squeezes]), the row
/// stacks: the title, the subtitle and the detail line take its full width,
/// the icon and chevron go on the title's line (or on a line of their own
/// above it, where they would crowd the title), and a trailing control goes
/// under the text. Whether it stacks depends only on its width, the text's
/// size and whether it has an icon, never on what is at its end at the
/// moment, so that the rows of a group decide alike and a row keeps its
/// layout as a control at its end comes and goes. A title set smaller to
/// keep a long word whole sets the lines under it no larger as drawn, so
/// that it is never the smaller.
///
/// It decides at layout how to set itself ([LayoutBuilder]), and so doesn't
/// answer intrinsic size queries: in a dialog, whose content is sized to its
/// intrinsic width, give it a width of its own ([SizedBox]), and never set
/// it in a row as tall as its tallest cell ([IntrinsicHeight]).
class PaperRow extends StatelessWidget {
  const PaperRow({
    super.key,
    this.icon,
    this.leading,
    this.iconColor,
    required this.title,
    this.breakTitleAtHyphens = true,
    this.subtitle,
    this.subtitleParts,
    this.subtitleMaxLines = 2,
    this.subtitleLocale,
    this.titleStyle,
    this.subtitleStyle,
    this.detail,
    this.value,
    this.valueLocale,
    this.trailing,
    this.mergeTrailing = false,
    this.progress,
    this.onTap,
    this.selected,
    this.toggled,
    this.liveRegion = false,
    this.destructive = false,
    this.focusNode,
    bool? chevron,
  })  : assert(icon == null || leading == null, 'an icon or a leading widget, not both'),
        assert(subtitle == null || subtitleParts == null, 'a subtitle or its parts, not both'),
        chevron = chevron ?? onTap != null;

  final IconData? icon;

  /// A widget in the icon's place, such as a member's initial disc: in the
  /// icon's slot, and aligned as the icon is, in either layout.
  final Widget? leading;

  /// onSurfaceVariant unless given: the grace shield is in its own colour.
  final Color? iconColor;
  final String title;

  /// Whether the title may end a line after a hyphen in it, as a sentence
  /// may ([WholeWords.breakAtHyphens]): false for a parsha's name, which
  /// stays whole ("Vayakhel-Pekudei").
  final bool breakTitleAtHyphens;

  /// At most [subtitleMaxLines] lines, unless the text is enlarged.
  final String? subtitle;

  /// A subtitle of parts between middle dots, in place of [subtitle]: set
  /// as a [DotLine], as many parts to a line as fit, so that its lines break
  /// between parts rather than inside one, and never cut short. A haftarah's
  /// passages: "Isaiah 54:11–55:5 · Isaiah 66:1" over "Isaiah 66:23 · …",
  /// never "Isaiah" at a line's end and "66:23" under it.
  final List<String>? subtitleParts;

  /// Two by default; null for a subtitle that is never cut short, such as a
  /// long reference (the haftarah's, three lines on a phone for Sephardim on
  /// Re'eh on Rosh Chodesh Elul) or a setting's description.
  final int? subtitleMaxLines;

  /// The language of [subtitle], for screen readers, where it isn't the
  /// interface's (the reader's own note, say).
  final Locale? subtitleLocale;

  /// bodyLarge in onSurface, merged with this where given: a list of places
  /// to go, such as the forums, sets its titles in titleMedium.
  final TextStyle? titleStyle;

  /// bodyMedium in onSurfaceVariant, merged with this where given.
  final TextStyle? subtitleStyle;

  /// A line under the subtitle in bodySmall onSurfaceVariant, such as how
  /// busy a forum is.
  final String? detail;

  /// The current setting, such as a language, at the end of the row.
  final String? value;

  /// The language [value] is written in, where it is not the interface's
  /// (a language's own name), so that a screen reader reads it in its own
  /// voice.
  final Locale? valueLocale;
  final Widget? trailing;

  /// Whether [trailing] reads as part of the row (a switch the row toggles)
  /// rather than as a control of its own.
  final bool mergeTrailing;

  /// A spinner while the row's tap is under way (a discussion opening),
  /// in the chevron's place, 20 square at most: the row keeps its layout as
  /// it comes and goes.
  final Widget? progress;

  final VoidCallback? onTap;

  /// Whether the row is the one chosen of a list, for screen readers; null
  /// for a row that isn't one of a choice.
  final bool? selected;

  /// Whether what the row's tap toggles is on, for screen readers, which
  /// then hear the row as a switch: for a row whose switch can't be merged
  /// into it (it has another control beside it), and is left out of the
  /// semantics and the focus order instead. Null for a row that toggles
  /// nothing.
  final bool? toggled;

  /// Whether a screen reader reads the row out as it changes, as a value
  /// moved by another control does.
  final bool liveRegion;

  /// Sets the title in error ink, for the one row of a page that erases
  /// (§9 Your data). Such a row has no icon.
  final bool destructive;

  final bool chevron;

  /// The focus node of the row's ink well, for a row given the focus when
  /// the control that had it goes; null for its own.
  final FocusNode? focusNode;

  static const double _start = 16;
  static const double _end = 12;
  static const double _iconSlot = 38;

  /// Between the text and each control at the end, and before a stacked
  /// row's chevron.
  static const double _controlGap = 12;
  static const double _chevronSize = 20;

  /// The narrowest a row's text may be beside its icon and the controls at
  /// its end, as the text is scaled: narrower, it holds a word or two a line.
  static const double _narrowestText = 112;

  /// The narrowest a stacked row's title may be beside its icon and a
  /// chevron, as the text is scaled: room for a long word ("Accessibility")
  /// at nearly its size. Narrower, the icon goes on a line of its own.
  static const double _narrowestTitle = 88;

  /// What a row allows at its end in deciding whether to stack: the widest
  /// control a row has there, a switch, whatever it has at the moment, so
  /// that the rows of a group decide alike, and a row keeps its layout as
  /// a control comes and goes (a spinner, a button shown while a setting is
  /// on).
  static const double _endAllowance = _controlGap + 52;

  /// How much [scaler] enlarges text [fontSize] high, a row's title's
  /// (bodyLarge's 16) by default. On Android 14 and later the system's
  /// scale is not linear, growing large text less than small, so widths
  /// are compared by the title's own factor, not scaled as a font size.
  static double _factor(TextScaler scaler, [double fontSize = 16]) => scaler.scale(fontSize) / fontSize;

  /// Whether text [width] wide, beside a row's leading and trailing columns,
  /// is squeezed at [scaler]'s size, for a title [fontSize] high: as only
  /// enlarged text ever is. Such a row stacks its columns instead, as a
  /// [PaperRow] does.
  static bool squeezes(TextScaler scaler, double width, {double fontSize = 16}) {
    final factor = _factor(scaler, fontSize);
    return factor > 1 && width < _narrowestText * factor;
  }

  bool get _hasLead => icon != null || leading != null;

  bool get _hasSubtitle => subtitle != null || subtitleParts != null;

  /// About as wide as a [control] at the end of a row is, to tell whether
  /// the row's text is squeezed beside it: a switch 52, a row of controls
  /// their sum, and any other control (a menu, an icon button) 48.
  static double _controlWidth(Widget control) => switch (control) {
        Switch() => 52,
        Row(:final children) => children.fold(0, (sum, child) => sum + _controlWidth(child)),
        ExcludeFocus(:final child) || ExcludeSemantics(child: final child?) => _controlWidth(child),
        _ => 48,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final titleStyle =
        text.bodyLarge!.copyWith(color: destructive ? scheme.error : scheme.onSurface).merge(this.titleStyle);
    final value = this.value;
    // A labelled button goes with the title, as a value does, rather than
    // after it.
    final trailing = this.trailing;
    final besideTitle = value == null && trailing is ButtonStyleButton ? trailing : null;
    final control = besideTitle == null ? trailing : null;
    final progress = this.progress;
    // The chevron, or a spinner in its place.
    final chevron = this.chevron || progress != null;
    final chevronIcon = progress == null
        ? Icon(Icons.chevron_right, size: _chevronSize, color: scheme.outline)
        : SizedBox.square(dimension: _chevronSize, child: Center(child: progress));
    final scaler = MediaQuery.textScalerOf(context);
    final titleSize = titleStyle.fontSize ?? 16;
    final factor = _factor(scaler, titleSize);
    // Text is never cut short once it is enlarged (WCAG 1.4.4).
    final enlarged = factor > 1;

    // The title, with a value or a labelled button at the end of its line,
    // and the lines under it. Where the title is set smaller, at [fit], to
    // keep a long word whole, they are set no larger than it, so that the
    // title is never the smaller.
    ({Widget heading, List<Widget> under}) texts(double fit) {
      // As drawn, scaled: a scaler that isn't linear (Android's) grows a
      // small size more than a large one.
      final limit = fit * scaler.scale(titleSize);
      TextStyle? atMost(TextStyle? style) {
        final size = style?.fontSize;
        if (size == null || scaler.scale(size) <= limit + 0.01) return style;
        // The size the scaler draws at the limit: it grows every size, if
        // not in proportion, so the size is found by halving.
        var low = 0.0;
        var high = size;
        for (var i = 0; i < 24; i++) {
          final mid = (low + high) / 2;
          if (scaler.scale(mid) > limit) {
            high = mid;
          } else {
            low = mid;
          }
        }
        return style!.copyWith(fontSize: low);
      }

      final muted = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
      final subtitleStyle = atMost(muted?.merge(this.subtitleStyle));
      final valueStyle = atMost(muted);
      final detailStyle = atMost(text.bodySmall?.copyWith(color: scheme.onSurfaceVariant));
      // Each word whole, as very large text beside an icon and a chevron
      // would not keep it.
      final titleText =
          WholeWords(title, style: titleStyle, textAlign: TextAlign.start, breakAtHyphens: breakTitleAtHyphens);
      // So with the lines under it, once the text is enlarged: below that, a
      // subtitle may be cut short at its last line instead.
      Widget enlargedLine(String line, TextStyle? style) =>
          WholeWords(line, style: style, textAlign: TextAlign.start, breakAtHyphens: true);
      // The title, and at the end of its line a value or a labelled button,
      // which move under it when the two don't fit side by side.
      Widget titleWith(Widget other) => SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [titleText, other],
            ),
          );
      return (
        heading: value != null
            ? titleWith(
                valueLocale == null
                    ? Text(value, style: valueStyle)
                    : Lang(valueLocale!, child: Text(value, style: valueStyle)),
              )
            : besideTitle != null
                ? titleWith(besideTitle)
                : titleText,
        under: [
          if (subtitleParts case final parts?)
            DotLine(parts, style: subtitleStyle)
          else if (subtitle case final subtitle?)
            if (subtitleLocale case final locale?)
              Text.rich(
                TextSpan(text: subtitle, locale: locale),
                style: subtitleStyle,
                maxLines: enlarged ? null : subtitleMaxLines,
                overflow: enlarged || subtitleMaxLines == null ? null : TextOverflow.ellipsis,
              )
            else if (enlarged)
              enlargedLine(subtitle, subtitleStyle)
            else
              Text(
                subtitle,
                style: subtitleStyle,
                maxLines: subtitleMaxLines,
                overflow: subtitleMaxLines == null ? null : TextOverflow.ellipsis,
              ),
          if (detail case final detail?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: enlarged ? enlargedLine(detail, detailStyle) : Text(detail, style: detailStyle),
            ),
        ],
      );
    }

    // About as wide as the controls at the end of the row as they are now:
    // a control merged into the row is a switch or a checkbox, no wider
    // than a switch.
    final endWidth = (control == null ? 0 : _controlGap + (mergeTrailing ? 52 : _controlWidth(control))) +
        (chevron ? _controlGap + _chevronSize : 0);

    // The icon, the text and the controls side by side, in [width].
    Widget sideBySide(double width) {
      // A long word set smaller in the title sets the lines under it no
      // larger here too.
      final fit = !enlarged
          ? 1.0
          : WholeWords.scaleIn(
              context,
              title,
              width: width - _start - _end - (_hasLead ? _iconSlot : 0) - endWidth,
              style: titleStyle,
              breakAtHyphens: breakTitleAtHyphens,
            );
      final (:heading, :under) = texts(fit);
      // A value ends the title's line. With a subtitle under them, the icon
      // and the end of the row line up with that line too, rather than with
      // the middle of the row, so the value and chevron stay side by side.
      // So they do over a detail line, value or not: centred on three lines
      // of text, the icon would sit beside none of them.
      final onTitleLine = detail != null || (value != null && _hasSubtitle);
      Widget place(Widget child, AlignmentGeometry alignment) => onTitleLine
          ? ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: scaler.scale(titleStyle.fontSize ?? 16) * (titleStyle.height ?? 1.5)),
              child: Align(alignment: alignment, widthFactor: 1, heightFactor: 1, child: child),
            )
          : child;
      final end = <Widget>[?control, if (chevron) chevronIcon];
      return Row(
        crossAxisAlignment: onTitleLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (_hasLead)
            SizedBox(
              width: _iconSlot,
              child: place(
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  heightFactor: 1,
                  child: leading ?? AppIcon(icon!, size: 22, color: iconColor ?? scheme.onSurfaceVariant),
                ),
                AlignmentDirectional.centerStart,
              ),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, ...under],
            ),
          ),
          for (final (i, widget) in end.indexed)
            Padding(
              // A chevron straight after a value stays close to it.
              padding: EdgeInsetsDirectional.only(start: i == 0 && (value == null || trailing != null) ? 12 : 4),
              child: place(widget, Alignment.center),
            ),
        ],
      );
    }

    // The text the row's full width: the title's line, with the icon and
    // chevron while they leave the title room enough, or else on a line of
    // their own above it; the lines under it; and a control under them.
    // Returns where the text starts, for the hairline under it: null where
    // the group's own inset says.
    (Widget, double? textStart) stacked(double width) {
      // Growing with the text, a little, as a mark beside large words.
      final iconSize = scaler.clamp(maxScaleFactor: 1.5).scale(22);
      final icon = this.icon;
      final lead = leading ??
          (icon == null ? null : AppIcon(icon, size: iconSize, color: iconColor ?? scheme.onSurfaceVariant));
      final leadWidth = leading != null ? _iconSlot : iconSize + 8;
      const chevronWidth = _controlGap + _chevronSize;
      final textWidth = width - _start - _end;
      // Judged with room for a chevron whether or not the row has one, so
      // that the rows of a group decide alike.
      final leadBeside = lead == null || textWidth - leadWidth - chevronWidth >= _narrowestTitle * factor;
      final chevronBeside = chevron && leadBeside;
      final fit = WholeWords.scaleIn(
        context,
        title,
        width: textWidth - (lead == null || !leadBeside ? 0 : leadWidth) - (chevronBeside ? chevronWidth : 0),
        style: titleStyle,
        breakAtHyphens: breakTitleAtHyphens,
      );
      final (:heading, :under) = texts(fit);
      final column = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lead != null && !leadBeside)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Row(children: [lead, const Spacer(), if (chevron) chevronIcon]),
            ),
          Row(
            children: [
              if (lead != null && leadBeside)
                leading != null
                    ? SizedBox(
                        width: _iconSlot,
                        child: Align(alignment: AlignmentDirectional.centerStart, heightFactor: 1, child: lead),
                      )
                    : Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: lead),
              Expanded(child: heading),
              if (chevronBeside)
                Padding(padding: const EdgeInsetsDirectional.only(start: _controlGap), child: chevronIcon),
            ],
          ),
          ...under,
          if (control != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Align(alignment: AlignmentDirectional.centerStart, child: control),
            ),
        ],
      );
      // With the icon above it, all its text starts at the row's start;
      // with an icon grown beside it, where the title does.
      final textStart = lead == null
          ? null
          : !leadBeside
              ? PaperGroup.plainInset
              : _start + leadWidth;
      return (column, textStart);
    }

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final squeezed = squeezes(
          scaler,
          width - _start - _end - (_hasLead ? _iconSlot : 0) - _endAllowance,
          fontSize: titleSize,
        );
        final (body, textStart) = squeezed ? stacked(width) : (sideBySide(width), null);
        // The hairline under the row starts where its text does.
        _RowPlace.ruleStartOf(context)?.value = textStart == PaperGroup.iconInset ? null : textStart;
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: !_hasSubtitle && detail == null ? 56 : 72),
          child: Padding(padding: const EdgeInsetsDirectional.fromSTEB(_start, 12, _end, 12), child: body),
        );
      },
    );
    final merged = trailing != null && mergeTrailing;
    final row = Semantics(
      // Its own item: the text and the tap gather here, while a trailing
      // control below keeps its own (unless merged, below). A merged switch
      // or checkbox gives the row its role.
      container: true,
      button: onTap != null && !merged,
      selected: selected,
      toggled: toggled,
      liveRegion: liveRegion,
      child: onTap == null
          ? content
          : SeferInkWell(
              focusNode: focusNode,
              onTap: onTap,
              borderRadius: PaperGroup.rowCorners(context),
              child: content,
            ),
    );
    return merged ? MergeSemantics(child: row) : row;
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
