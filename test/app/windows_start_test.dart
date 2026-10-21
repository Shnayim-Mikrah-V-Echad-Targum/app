import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'native_source.dart';

/// The Windows runner shows its window only with Flutter's first frame. A
/// fault before it, with the window left hidden, would leave a process with
/// no window to close holding the single-instance mutex, and every later
/// launch would find that invisible window and quietly exit (main.cpp). CI
/// compiles the runner but never runs it, so its source is checked here.
void main() {
  final window = File('windows/runner/flutter_window.cpp').readAsStringSync();
  final header = File('windows/runner/flutter_window.h').readAsStringSync();

  /// The body of the C++ function whose definition begins with [signature].
  String body(String signature) => cppBody(window, signature);

  test('the window is shown once, with the first frame or after a while without one', () {
    expect(header, contains('void ShowOnce();'));
    expect(header, contains('bool shown_ = false;'));
    final create = body('bool FlutterWindow::OnCreate()');
    expect(create, contains('SetNextFrameCallback([this]() {\n    ShowOnce();\n  });'));
    expect(create, contains('::SetTimer(GetHandle(), kFirstFrameTimerId, kFirstFrameTimeoutMs, nullptr);'));
    // The safety net is a while, not a moment: a slow first frame still
    // shows nothing blank in the meantime.
    final timeout = int.parse(RegExp(r'constexpr UINT kFirstFrameTimeoutMs = (\d+);').firstMatch(window)![1]!);
    expect(timeout, inInclusiveRange(5000, 20000));
    expect(window, contains('constexpr UINT_PTR kFirstFrameTimerId = '));
  });

  test('a second call shows nothing again, so a maximized window stays maximized', () {
    final showOnce = body('void FlutterWindow::ShowOnce()');
    expect(showOnce, contains('::KillTimer(window, kFirstFrameTimerId);'));
    expect(showOnce.indexOf('if (shown_) {'), lessThan(showOnce.indexOf('Show();')));
    expect(showOnce, contains('shown_ = true;'));
    // Nothing else shows the window: Win32Window::Show restores its
    // maximized state once, and a second call would restore it to normal.
    expect(RegExp(r'(?<![A-Za-z_])Show\(\);').allMatches(window), hasLength(1));
  });

  test("the timer's message is the runner's, handled before Flutter's", () {
    final handler = body('FlutterWindow::MessageHandler(');
    final timer = handler.indexOf('if (message == WM_TIMER && wparam == kFirstFrameTimerId) {\n    ShowOnce();\n    return 0;\n  }');
    expect(timer, isNot(-1));
    expect(timer, lessThan(handler.indexOf('HandleTopLevelWindowProc')));
  });
}
