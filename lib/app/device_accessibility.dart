import 'package:flutter/widgets.dart';

/// The device's own Reduce motion and Bold text, as the platform gives
/// them. The app's MediaQuery has each on where either the device or the
/// app's own setting turns it on (app.dart), so a page that shows the app's
/// settings reads the device's here: one the device has on is in force
/// whatever the app's says.
class DeviceAccessibility extends InheritedWidget {
  const DeviceAccessibility({
    super.key,
    required this.disableAnimations,
    required this.boldText,
    required super.child,
  });

  /// Whether the device asks for no animations.
  final bool disableAnimations;

  /// Whether the device asks for bold text.
  final bool boldText;

  /// Whether the device asks for no animations, rebuilding [context] when
  /// that changes. With no app above it to add its setting, the MediaQuery
  /// is the device's own.
  static bool disableAnimationsOf(BuildContext context) =>
      _of(context)?.disableAnimations ?? MediaQuery.disableAnimationsOf(context);

  /// Whether the device asks for bold text, as [disableAnimationsOf].
  static bool boldTextOf(BuildContext context) => _of(context)?.boldText ?? MediaQuery.boldTextOf(context);

  static DeviceAccessibility? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DeviceAccessibility>();

  @override
  bool updateShouldNotify(DeviceAccessibility old) =>
      disableAnimations != old.disableAnimations || boldText != old.boldText;
}
