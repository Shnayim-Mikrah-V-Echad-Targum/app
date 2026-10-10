import 'package:flutter/widgets.dart';

/// Rebuilds the widgets that ask for it ([watch]) when the system's fonts
/// change, as a font loaded on demand arrives (on the web, or one just
/// chosen). Text that the framework lays out (a Text) does so of itself;
/// this is for text measured while building, such as the navigation bar's
/// labels, whose sizes would otherwise keep a stand-in font's metrics.
class FontsChangeScope extends InheritedNotifier<Listenable> {
  FontsChangeScope({super.key, required super.child}) : super(notifier: PaintingBinding.instance.systemFonts);

  /// Rebuilds [context] when the fonts change, if a scope is above it.
  static void watch(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FontsChangeScope>();
}
