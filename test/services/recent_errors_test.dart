import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/services/recent_errors.dart';

/// [count] frames of a stack trace, "#0 frame0" and on.
String _frames(int count, {String indent = ''}) => [for (var i = 0; i < count; i++) '$indent#$i frame$i'].join('\n');

FlutterErrorDetails _error(String message, {String? context, String? stack}) => FlutterErrorDetails(
      exception: StateError(message),
      context: context == null ? null : ErrorDescription(context),
      stack: StackTrace.fromString(stack ?? _frames(3)),
    );

/// An exception that can't even say what it is.
class _Unspeakable {
  @override
  String toString() => throw StateError('no words');
}

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('copies, under the version and the platform, each error’s summary, what the app was doing and where',
      () {
    final errors = RecentErrors()
      ..add(_error('no element', context: 'building TodayScreen', stack: _frames(12)))
      ..add(_error('closed'));
    expect(
      errors.report(version: '1.0.0 (12)').split('\n'),
      [
        'Shnayim Mikrah 1.0.0 (12) on android',
        '',
        'Bad state: no element',
        'building TodayScreen',
        for (var i = 0; i < 8; i++) '#$i frame$i',
        '',
        'Bad state: closed',
        for (var i = 0; i < 3; i++) '#$i frame$i',
      ],
    );
    expect(RecentErrors().report(version: '').split('\n').first, 'Shnayim Mikrah on android');
  });

  test('keeps the lines a trace without its symbols begins with, which reading its frames needs', () {
    const header = [
      '*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***',
      'pid: 4321, tid: 4350, name 1.ui',
      'os: android arch: arm64 comp: yes sim: no',
      "build_id: '0f1e2d3c4b5a69788796a5b4c3d2e1f0'",
      'isolate_dso_base: 7a1c2d0000, vm_dso_base: 7a1c2d0000',
      'isolate_instructions: 7a1c3e2000, vm_instructions: 7a1c3d8000',
    ];
    final frames = [for (var i = 0; i < 12; i++) '    #${'$i'.padLeft(2, '0')} abs 0000007a1c4f$i virt 00000000001f$i'];
    final errors = RecentErrors()..add(_error('broken', stack: [...header, ...frames].join('\n')));
    expect(errors.errors.single.stack, [...header, ...frames.take(8)]);
  });

  test('counts an error that comes again where it first came, rather than letting it push others out', () {
    final errors = RecentErrors()
      ..add(_error('first'))
      ..add(_error('second'));
    for (var i = 0; i < 100; i++) {
      errors.add(_error('first'));
    }
    expect([for (final e in errors.errors) (e.summary, e.times)], [('Bad state: first', 101), ('Bad state: second', 1)]);
    expect(errors.report(version: '1.0.0 (12)'), contains('Bad state: first (101 times)\n#0 frame0'));
    // The same words from elsewhere in the code are another error.
    errors.add(_error('first', stack: _frames(3, indent: '  ')));
    expect(errors.errors, hasLength(3));
  });

  test('keeps the last 20 errors, and says how many came before them', () {
    final errors = RecentErrors();
    for (var i = 0; i < 23; i++) {
      errors.add(_error('error $i'));
    }
    expect(errors.errors, hasLength(20));
    expect(errors.errors.first.summary, 'Bad state: error 3');
    expect(errors.errors.last.summary, 'Bad state: error 22');
    expect(errors.report(version: '1.0.0 (12)').split('\n\n')[1], '3 earlier errors not kept');
  });

  test('tells its listeners of the first error alone, once the frame it came in is over', () async {
    final errors = RecentErrors();
    var told = 0;
    errors.addListener(() => told++);
    errors.add(_error('first'));
    expect(told, 0, reason: 'not within the build that failed');
    await Future<void>.delayed(Duration.zero);
    expect(told, 1);
    errors
      ..add(_error('second'))
      ..add(_error('first'));
    await Future<void>.delayed(Duration.zero);
    expect(told, 1);
  });

  test('throws nothing, within the handling of another error, when an error can’t be read', () {
    final errors = RecentErrors();
    expect(() => errors.add(FlutterErrorDetails(exception: _Unspeakable())), returnsNormally);
    expect(errors.isEmpty, isTrue);
  });

  test('keeps the errors Flutter reports and those no code caught, which are reported as before', () {
    final flutter = FlutterError.onError;
    final platform = PlatformDispatcher.instance.onError;
    final presented = <FlutterErrorDetails>[];
    final unhandled = <Object>[];
    try {
      FlutterError.onError = presented.add;
      PlatformDispatcher.instance.onError = (error, stack) {
        unhandled.add(error);
        return false;
      };
      recordRecentErrors();
      final details = _error('in a build');
      FlutterError.reportError(details);
      expect(presented, [details]);
      expect(PlatformDispatcher.instance.onError!(StateError('in a future'), StackTrace.empty), isFalse,
          reason: 'left for the platform to log');
      expect(unhandled, [isA<StateError>()]);
      expect([for (final e in recentErrors.errors) e.summary], ['Bad state: in a build', 'Bad state: in a future']);
    } finally {
      FlutterError.onError = flutter;
      PlatformDispatcher.instance.onError = platform;
      recentErrors.clear();
    }
  });

  // As the web app's zone keeps them, where the engine never calls
  // PlatformDispatcher.onError.
  test('keeps an error no code caught in the app’s zone, and passes it on to the zone around it', () async {
    addTearDown(recentErrors.clear);
    final passedOn = Completer<Object>();
    runZonedGuarded(
      () => runZonedGuarded(() => Future<void>(() => throw StateError('in a tap')), keepUncaughtError),
      (error, _) => passedOn.complete(error),
    );
    expect(await passedOn.future, isA<StateError>());
    expect([for (final e in recentErrors.errors) e.summary], ['Bad state: in a tap']);
  });

  test('leaves out what a release build says of a widget it can’t name', () {
    final errors = RecentErrors()
      ..add(_error('no element', context: 'building Widget'))
      ..add(_error('closed', context: 'building Widget-[<\'today\'>]'));
    expect(errors.errors.first.context, isNull);
    expect(errors.report(version: '').split('\n'), isNot(contains('building Widget')));
    expect(errors.errors.last.context, 'building Widget-[<\'today\'>]', reason: 'its key says which');
  });
}
