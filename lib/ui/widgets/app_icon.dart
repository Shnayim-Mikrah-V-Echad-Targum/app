import 'package:flutter/material.dart';

/// An [Icon] drawn as this app's languages write it. Material mirrors the
/// help icon in right-to-left text, as Arabic writes its question mark,
/// but Hebrew writes "?" as English does, so that icon keeps its direction.
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size, this.color});

  final IconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: size, color: color, textDirection: icon == Icons.help_outline ? TextDirection.ltr : null);
}
