import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'native_source.dart';

/// The Windows app runs one instance at a time (windows/runner/main.cpp): a
/// second launch brings the first one's window forward and exits, unless
/// that window is closing, when it waits for the first to go and starts in
/// its place. CI compiles the runner but never runs it, so its source is
/// checked here.
void main() {
  final main = File('windows/runner/main.cpp').readAsStringSync();
  final window = File('windows/runner/flutter_window.cpp').readAsStringSync();
  final header = File('windows/runner/win32_window.h').readAsStringSync();
  final winMain = cppBody(main, 'int APIENTRY wWinMain(');
  final secondLaunch = cppBody(winMain, 'if (instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS)');

  test('a second launch brings the running window forward, unless it is closing', () {
    expect(secondLaunch, contains('if (running != nullptr && !IsClosing(running)) {\n      BringToFront(running);'));
    expect(cppBody(main, 'bool IsClosing(HWND window)'), contains('::GetPropW(window, kClosingProperty) != nullptr'));
    // A window still hidden, waiting for its first frame, counts as running.
    expect(cppBody(main, 'HWND FindRunningWindow()'), contains('::FindWindowW(kWindowClassName, nullptr)'));
  });

  test('a launch while the app closes waits for it to go, and then starts', () {
    final wait = secondLaunch.indexOf('::WaitForSingleObject(instance_mutex, kInstanceWaitMs)');
    expect(wait, greaterThan(secondLaunch.indexOf('!IsClosing(running)')));
    // Should it not go in time, its window is brought forward after all.
    final timedOut = cppBody(secondLaunch.substring(wait), 'if (wait != WAIT_OBJECT_0 && wait != WAIT_ABANDONED)');
    expect(timedOut, contains('if (HWND window = FindRunningWindow()) {\n        BringToFront(window);\n      }'));
    expect(timedOut, contains('return EXIT_SUCCESS;'));
    // The mutex is released only once the window and the engine are gone.
    expect(winMain.indexOf('::ReleaseMutex(instance_mutex);'), greaterThan(winMain.indexOf('while (::GetMessage(&msg, nullptr, 0, 0))')));
    final waitMs = int.parse(RegExp(r'constexpr DWORD kInstanceWaitMs = (\d+);').firstMatch(main)![1]!);
    expect(waitMs, inInclusiveRange(2000, 10000));
  });

  // The engine holds back the first WM_CLOSE while the app saves
  // (lib/app/pending_saves.dart), and shuts down in WM_DESTROY, after the
  // window has been hidden: all the while the window can be found.
  test('the window is marked as closing from the first WM_CLOSE until it is gone', () {
    expect(header, contains('inline constexpr wchar_t kClosingProperty[] = L"ShnayimMikrah.Closing";'));
    final handler = cppBody(window, 'FlutterWindow::MessageHandler(');
    final mark = handler.indexOf('if (message == WM_CLOSE) {\n    ::SetPropW(hwnd, kClosingProperty,');
    expect(mark, isNot(-1));
    // Before Flutter, which keeps the first WM_CLOSE from the code after it.
    expect(mark, lessThan(handler.indexOf('HandleTopLevelWindowProc')));
    // Removed as the window is destroyed, as a window's properties must be.
    expect(handler, contains('} else if (message == WM_NCDESTROY) {\n    ::RemovePropW(hwnd, kClosingProperty);\n  }'));
  });

  // Were it to cancel, the window would stay marked: later launches would
  // wait for it to close before bringing it forward.
  test('the app never cancels closing its window', () {
    final saves = File('lib/app/pending_saves.dart').readAsStringSync();
    expect(saves, contains('return AppExitResponse.exit;'));
    expect(saves, isNot(contains('AppExitResponse.cancel')));
    final lib = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in lib) {
      expect(file.readAsStringSync(), isNot(contains('AppExitResponse.cancel')), reason: file.path);
    }
  });
}
