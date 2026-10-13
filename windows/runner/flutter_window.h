#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Lets the app set the title bar's theme, and the window's title in the
  // app's language ("shnayim/window" in lib/app/window_title_bar.dart).
  void RegisterWindowChannel();

  // Shows the window, the first time it is called: when Flutter has drawn
  // its first frame, or when kFirstFrameTimeoutMs have passed without one.
  // Win32Window::Show restores the window's maximized state only once, so
  // a second call would restore a maximized window to its normal size.
  void ShowOnce();

  // Whether ShowOnce has shown the window.
  bool shown_ = false;

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
