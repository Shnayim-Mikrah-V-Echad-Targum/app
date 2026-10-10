import 'package:flutter/material.dart';

/// The app's mark: the icon (שמו״ת over the three rules) with its corners
/// rounded to a quarter of its size, 10 at the rail's 40 (docs/DESIGN_SYSTEM.md
/// §6.10).
///
/// Decorative unless [semanticLabel] is given, in which case it is announced
/// as an image with that label.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 40, this.semanticLabel});

  /// The opaque 1024 px master that the platform icons are made from, and a
  /// 128 px rendering of it for small sizes.
  static const master = 'assets/branding/icon.png';
  static const small = 'assets/branding/mark_128.png';

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // The smallest rendering that covers the pixels drawn, scaled down with
    // mipmaps. (Decoding the master straight to a small size breaks up the
    // letters.) The small one's own corners are tighter than this clip.
    final pixels = size * MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: Image.asset(
        pixels <= 128 ? small : master,
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
      ),
    );
  }
}
