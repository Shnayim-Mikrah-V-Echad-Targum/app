import 'dart:async';

import 'package:flutter/foundation.dart';

/// The errors the app has met since it started, for About to copy for
/// support. They are kept in memory alone and go nowhere by themselves: the
/// app records nothing (docs/DESIGN.md §10), and only the reader, who pastes
/// them into a message, can send them.
final recentErrors = RecentErrors();

/// Keeps each error reported in [recentErrors], and reports it as before:
/// Flutter's own (in a build, a layout, a paint or a gesture), and any that
/// no code caught.
void recordRecentErrors() {
  final flutter = FlutterError.onError;
  FlutterError.onError = (details) {
    flutter?.call(details);
    recentErrors.add(details);
  };
  final platform = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    recentErrors.add(FlutterErrorDetails(exception: error, stack: stack));
    // Left unhandled, so that the platform still logs it as it did.
    return platform?.call(error, stack) ?? false;
  };
}

/// One error, as support reads it: what it was, what the app was doing, and
/// where in the code; and how many times it has come.
class RecordedError {
  RecordedError._(this.summary, this.context, this.stack);

  /// Text alone, so that the error's widgets and their trees aren't held.
  factory RecordedError.of(FlutterErrorDetails details) => RecordedError._(
        details.summary.toDescription(),
        details.context?.toDescription(),
        _firstFrames(details.stack),
      );

  /// The exception's first line.
  final String summary;

  /// What the app was doing, such as "building TodayScreen", where the
  /// framework says.
  final String? context;

  /// The stack trace's first [frames] frames (see [_firstFrames]).
  final List<String> stack;

  int get times => _times;
  int _times = 1;

  static const frames = 8;

  bool _sameAs(RecordedError other) =>
      summary == other.summary && context == other.context && listEquals(stack, other.stack);

  /// The first [frames] lines of [stack]. A release build's trace without
  /// its symbols (`--split-debug-info`) begins with a few lines, its build
  /// ID and where the code was loaded, that `flutter symbolize` needs in
  /// order to read the frames: those are kept besides.
  static List<String> _firstFrames(StackTrace? stack) {
    final lines = [
      for (final line in (stack?.toString() ?? '').split('\n'))
        if (line.trim().isNotEmpty) line.trimRight(),
    ];
    final first = lines.indexWhere((line) => line.trimLeft().startsWith('#'));
    final header = first > 0 && first <= 8 ? first : 0;
    return lines.take(header + frames).toList();
  }
}

/// The last [capacity] distinct errors, the oldest first: one that comes
/// again, as an error in a build can each frame, is counted where it first
/// came rather than pushing the others out.
class RecentErrors extends ChangeNotifier {
  RecentErrors({this.capacity = 20});

  final int capacity;
  final _errors = <RecordedError>[];

  /// How many earlier errors there were, beyond [capacity].
  int _dropped = 0;

  List<RecordedError> get errors => List.unmodifiable(_errors);
  bool get isEmpty => _errors.isEmpty;
  bool get isNotEmpty => _errors.isNotEmpty;

  /// Keeps [details]. Listeners hear only of the first error, and after the
  /// frame it came in: an error in a build mustn't build again then, and
  /// one in a listener's build mustn't come round again and again.
  void add(FlutterErrorDetails details) {
    // Nothing thrown from here, within the handling of another error.
    try {
      final error = RecordedError.of(details);
      for (final kept in _errors) {
        if (kept._sameAs(error)) {
          kept._times++;
          return;
        }
      }
      _errors.add(error);
      if (_errors.length > capacity) {
        _errors.removeAt(0);
        _dropped++;
      }
      if (_errors.length == 1 && _dropped == 0) scheduleMicrotask(notifyListeners);
    } catch (_) {}
  }

  @visibleForTesting
  void clear() {
    final had = isNotEmpty;
    _errors.clear();
    _dropped = 0;
    if (had) notifyListeners();
  }

  /// The errors as text to paste into a message to support, after the app's
  /// [version] (empty where the platform doesn't say) and the platform it
  /// runs on. In English, as the errors themselves are, whatever the
  /// interface's language: it is for the maintainers to read.
  String report({required String version}) {
    final platform = kIsWeb ? 'the web (${defaultTargetPlatform.name})' : defaultTargetPlatform.name;
    final out = StringBuffer('Shnayim Mikra ${version.isEmpty ? '' : '$version '}on $platform');
    if (_dropped > 0) out.write('\n\n$_dropped earlier ${_dropped == 1 ? 'error' : 'errors'} not kept');
    for (final error in _errors) {
      out
        ..write('\n\n')
        ..write(error.summary);
      if (error.times > 1) out.write(' (${error.times} times)');
      if (error.context case final context?) out.write('\n$context');
      for (final line in error.stack) {
        out.write('\n$line');
      }
    }
    return out.toString();
  }
}
