#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <string>
#include <variant>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {

// The timer that shows the window if Flutter draws no first frame in time.
// Its id is the runner's own, set on the top-level window, apart from any
// timer of Flutter's or a plugin's.
constexpr UINT_PTR kFirstFrameTimerId = 0x534D;  // "SM"

// How long the window waits, hidden, for Flutter's first frame. Should the
// app fail or hang before it draws one, the window would otherwise stay
// hidden for good, with no taskbar button, while the process lives on and
// holds the single-instance mutex (main.cpp): every later launch would find
// that invisible window, bring it "forward" and quietly exit. Shown blank
// instead, it can at least be seen and closed. The app draws even its
// start-up error page as a frame (lib/app/start_failure.dart), so this is
// only a safety net.
constexpr UINT kFirstFrameTimeoutMs = 10000;

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterWindowChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // The callback, like the timer's message, comes on this thread, the
  // platform thread.
  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    ShowOnce();
  });
  ::SetTimer(GetHandle(), kFirstFrameTimerId, kFirstFrameTimeoutMs, nullptr);

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::ShowOnce() {
  if (HWND window = GetHandle()) {
    ::KillTimer(window, kFirstFrameTimerId);
  }
  if (shown_) {
    return;
  }
  shown_ = true;
  Show();
}

void FlutterWindow::RegisterWindowChannel() {
  // The handler stays registered with the engine, which this window owns.
  flutter::MethodChannel<> channel(
      flutter_controller_->engine()->messenger(), "shnayim/window",
      &flutter::StandardMethodCodec::GetInstance());
  channel.SetMethodCallHandler(
      [this](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() == "setDarkTitleBar") {
          const auto* dark = std::get_if<bool>(call.arguments());
          if (!dark) {
            result->Error("bad-arguments", "Expected a bool.");
            return;
          }
          SetDarkTitleBar(*dark);
          result->Success();
        } else if (call.method_name() == "setTitle") {
          // The app's name in its language, for the title bar, the taskbar
          // and Alt+Tab.
          const auto* title = std::get_if<std::string>(call.arguments());
          if (!title) {
            result->Error("bad-arguments", "Expected a string.");
            return;
          }
          const std::wstring utf16_title = Utf16FromUtf8(*title);
          if (utf16_title.empty() && !title->empty()) {
            result->Error("bad-arguments", "Expected UTF-8.");
            return;
          }
          if (HWND window = GetHandle()) {
            SetWindowTextW(window, utf16_title.c_str());
          }
          result->Success();
        } else if (call.method_name() == "activate") {
          // One of the app's notifications was clicked: Windows lets the app
          // take the foreground, but leaves it to the app to come forward. A
          // window not yet shown comes forward as it is shown, with its first
          // frame (ShowOnce); shown now, it would be blank.
          HWND window = GetHandle();
          if (window != nullptr && shown_) {
            BringToFront(window);
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // No first frame in time: show the window without it (see
  // kFirstFrameTimeoutMs). The runner's own timer, so before Flutter's.
  if (message == WM_TIMER && wparam == kFirstFrameTimerId) {
    ShowOnce();
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
