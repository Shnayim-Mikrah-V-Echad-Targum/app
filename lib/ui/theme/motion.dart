import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Motion tokens (docs/DESIGN_SYSTEM.md §8) and the app's Reduce Motion
/// switch.
///
/// Every animation reads its duration through `Motion.of(context).d(...)`,
/// which is zero while motion is reduced, so a reader who turned motion off
/// (in the app or in the system) never waits on anything. Flutter widgets that
/// take an [AnimationStyle] get [style] instead.
///
/// Rules: nothing loops, idles or animates on a timer; only opacity,
/// transforms and CustomPaint progress animate, never shadows or blur.
///
/// AppTheme.build registers the in-app setting as this extension, and
/// [Motion.of] combines it with [MediaQueryData.disableAnimations].
@immutable
class Motion extends ThemeExtension<Motion> {
  const Motion({this.reduced = false});

  /// Cross-fades of small things: a count, a pass pip, a dialog's entrance.
  static const short = Duration(milliseconds: 150);

  /// Page transitions on the web and desktop, progress tweens, icon swaps.
  static const medium = Duration(milliseconds: 250);

  /// Completion moments: an ornament drawing out, a panel fading in.
  static const long = Duration(milliseconds: 400);

  /// A parsha ring sweeping to its new fraction.
  static const ring = Duration(milliseconds: 600);

  /// The hero's frame rule drawing around the card once, when a parsha is
  /// finished.
  static const frame = Duration(milliseconds: 900);

  /// For things that move within the screen.
  static const standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// For things arriving: fast out of the gate, settling gently.
  static const decelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// For things leaving.
  static const accelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Whether motion is reduced: instant transitions, no ink splashes.
  final bool reduced;

  /// The motion to use under [context]: reduced if the reader turned on
  /// Reduce Motion in the app, or the platform asks for no animations.
  static Motion of(BuildContext context) {
    final reduced = (Theme.of(context).extension<Motion>()?.reduced ?? false) ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return reduced ? const Motion(reduced: true) : const Motion();
  }

  /// [duration], or zero while motion is reduced.
  Duration d(Duration duration) => reduced ? Duration.zero : duration;

  /// For a Flutter widget's own animation (`popUpAnimationStyle`,
  /// `sheetAnimationStyle`): none while motion is reduced, otherwise the
  /// widget's default.
  AnimationStyle? get style => reduced ? AnimationStyle.noAnimation : null;

  @override
  Motion copyWith({bool? reduced}) => Motion(reduced: reduced ?? this.reduced);

  @override
  Motion lerp(Motion? other, double t) => t < 0.5 || other == null ? this : other;

  @override
  bool operator ==(Object other) => other is Motion && other.reduced == reduced;

  @override
  int get hashCode => reduced.hashCode;
}

/// Page transitions (docs/DESIGN_SYSTEM.md §8): each platform's own on
/// Android and Apple devices, a quiet fade on the web and desktop, and none
/// at all while motion is reduced.
abstract final class AppPageTransitions {
  /// [web] is for tests; the app always passes [kIsWeb].
  static PageTransitionsTheme theme({required bool reduced, bool web = kIsWeb}) {
    if (reduced) {
      return PageTransitionsTheme(builders: {
        for (final platform in TargetPlatform.values) platform: const _NoTransitionsBuilder(),
      });
    }
    // On the web, the platform is the browser's host. A browser has its own
    // back gesture, and nothing there slides like a native app.
    const fade = FadeRisePageTransitionsBuilder();
    final android = web ? fade : const FadeForwardsDirectionalPageTransitionsBuilder();
    final apple = web ? fade : const CupertinoPageTransitionsBuilder();
    return PageTransitionsTheme(builders: {
      TargetPlatform.android: android,
      TargetPlatform.fuchsia: android,
      TargetPlatform.iOS: apple,
      TargetPlatform.macOS: apple,
      TargetPlatform.windows: fade,
      TargetPlatform.linux: fade,
    });
  }
}

/// A page transition that does nothing, for Reduce Motion: the next page is
/// simply there.
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      child;
}

/// The web and desktop transition (the spec's "fade-through"): the incoming
/// page fades in over [Motion.medium] while rising 8 px into place. No zoom,
/// and the page beneath stays still.
class FadeRisePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeRisePageTransitionsBuilder();

  static final _curve = CurveTween(curve: Motion.decelerate);

  @override
  Duration get transitionDuration => Motion.medium;

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final progress = animation.drive(_curve);
    return FadeTransition(opacity: progress, child: _Rise(progress: progress, child: child));
  }
}

class _Rise extends AnimatedWidget {
  const _Rise({required Animation<double> progress, required this.child}) : super(listenable: progress);

  static const _distance = 8.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    // A pure translation, so a settled page paints without a layer.
    return Transform.translate(offset: Offset(0, _distance * (1 - t)), child: child);
  }
}

/// Android's own transition, [FadeForwardsPageTransitionsBuilder], with its
/// horizontal slides mirrored in a right-to-left layout, as Android mirrors
/// them: in Hebrew the next page arrives from the left. Timing, curves and
/// fades are the framework's.
///
/// A back swipe is Android's predictive back gesture (on by default from
/// Android 16 for apps targeting it): the page follows the finger and reveals
/// the one beneath before the swipe is released. That part is the
/// framework's own [PredictiveBackPageTransitionsBuilder], which also listens
/// for the gesture, so it is always in the tree; each of the two transitions
/// stands still while the other is in charge.
class FadeForwardsDirectionalPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeForwardsDirectionalPageTransitionsBuilder();

  static const _predictiveBack = PredictiveBackPageTransitionsBuilder();

  static const _curve = Curves.easeInOutCubicEmphasized;

  // The new page slides in from the end and fades in; leaving, it slides back
  // and fades out. The page beneath moves a quarter-width the other way.
  static final _enter = Tween(begin: const Offset(0.25, 0), end: Offset.zero).chain(CurveTween(curve: _curve));
  static final _leave = Tween(begin: Offset.zero, end: const Offset(0.25, 0)).chain(CurveTween(curve: _curve));
  static final _coverReturn = Tween(begin: const Offset(-0.25, 0), end: Offset.zero).chain(CurveTween(curve: _curve));
  static final _cover = Tween(begin: Offset.zero, end: const Offset(-0.25, 0)).chain(CurveTween(curve: _curve));
  static final _fadeIn = Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: const Interval(0, 0.75)));
  static final _fadeOut = Tween<double>(begin: 1, end: 0).chain(CurveTween(curve: const Interval(0, 0.25)));

  @override
  Duration get transitionDuration =>
      const Duration(milliseconds: FadeForwardsPageTransitionsBuilder.kTransitionMilliseconds);

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) =>
          _beneath(context, secondaryAnimation, child);

  static Widget _slide(BuildContext context, Animatable<Offset> tween, Animation<double> animation, Widget? child) =>
      SlideTransition(position: tween.animate(animation), textDirection: Directionality.of(context), child: child);

  /// The page beneath, as the page above it arrives or leaves.
  static Widget _beneath(BuildContext context, Animation<double> secondaryAnimation, Widget? child) {
    final transition = DualTransitionBuilder(
      animation: ReverseAnimation(secondaryAnimation),
      forwardBuilder: (context, animation, child) => FadeTransition(
        opacity: _fadeIn.animate(animation),
        child: _slide(context, _coverReturn, animation, child),
      ),
      reverseBuilder: (context, animation, child) => FadeTransition(
        opacity: _fadeOut.animate(animation),
        child: _slide(context, _cover, animation, child),
      ),
      child: child,
    );
    if (!(ModalRoute.opaqueOf(context) ?? true)) return transition;
    // A surface behind the two fading pages, so nothing darker shows through.
    return ColoredBox(
      color: secondaryAnimation.isAnimating ? ColorScheme.of(context).surface : Colors.transparent,
      child: transition,
    );
  }

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // Outside a back gesture the predictive transition sees a settled page
    // (and falls back to a fade-forwards that then does nothing); during one,
    // the directional slides do.
    final directional = _directional(
      context,
      _GestureGate(route, animation, duringGesture: false, rest: 1),
      _GestureGate(route, secondaryAnimation, duringGesture: false, rest: 0),
      child,
    );
    return _predictiveBack.buildTransitions(
      route,
      context,
      _GestureGate(route, animation, duringGesture: true, rest: 1),
      _GestureGate(route, secondaryAnimation, duringGesture: true, rest: 0),
      directional,
    );
  }

  static Widget _directional(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder: (context, animation, child) => FadeTransition(
        opacity: _fadeIn.animate(animation),
        child: _slide(context, _enter, animation, child),
      ),
      reverseBuilder: (context, animation, child) => IgnorePointer(
        ignoring: animation.status == AnimationStatus.forward,
        child: FadeTransition(
          opacity: _fadeOut.animate(animation),
          child: _slide(context, _leave, animation, child),
        ),
      ),
      child: _beneath(context, secondaryAnimation, child),
    );
  }
}

/// A route's animation while a back gesture is in progress on its navigator
/// ([duringGesture]) or while none is, and otherwise held at [rest]: 1 for a
/// page's own animation (on screen, in place), 0 for its secondary one
/// (nothing above it).
class _GestureGate extends Animation<double> with AnimationWithParentMixin<double> {
  _GestureGate(this.route, this.parent, {required this.duringGesture, required this.rest});

  final PageRoute<dynamic> route;
  final bool duringGesture;
  final double rest;

  @override
  final Animation<double> parent;

  // The navigator is gone once the route is disposed.
  bool get _live => (route.navigator?.userGestureInProgress ?? false) == duringGesture;

  @override
  double get value => _live ? parent.value : rest;

  @override
  AnimationStatus get status =>
      _live ? parent.status : (rest == 1 ? AnimationStatus.completed : AnimationStatus.dismissed);
}
