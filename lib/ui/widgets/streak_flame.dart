import 'package:flutter/widgets.dart';

/// The fire emoji, beside a streak: Noto Emoji's, as an image
/// (assets/images/README.md), so that it is the same on every device and
/// offline, where a font's emoji would be the system's, or missing. It
/// grows with the text, to twice its size. It is decoration: the streak it
/// stands beside says what it means in words.
class StreakFlame extends StatelessWidget {
  const StreakFlame({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 2).scale(size);
    return Image.asset(
      'assets/images/fire.png',
      width: side,
      height: side,
      excludeFromSemantics: true,
      filterQuality: FilterQuality.medium,
    );
  }
}
