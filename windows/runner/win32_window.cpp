#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include <algorithm>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

/// The same attribute's number on Windows 10 before version 2004 (build
/// 18985), back to version 1809, the package's minimum.
constexpr DWORD kUseImmersiveDarkModeBefore20H1 = 19;

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

// The smallest window, in logical pixels: the app keeps its phone layout's
// width, and room for a screen's heading and a few rows.
constexpr int kMinWidth = 380;
constexpr int kMinHeight = 560;

// The most of its monitor's work area the window opens at.
constexpr double kMaxWorkAreaShare = 0.9;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

// Sizes |window| to |size| logical pixels for its monitor, no larger than
// kMaxWorkAreaShare of the monitor's work area, and centres it there.
// Coordinates are physical pixels.
void CentreInWorkArea(HWND window, const Win32Window::Size& size) {
  HMONITOR monitor = MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(monitor_info);
  if (!GetMonitorInfo(monitor, &monitor_info)) {
    return;
  }
  const double scale_factor = FlutterDesktopGetDpiForMonitor(monitor) / 96.0;
  const RECT& work = monitor_info.rcWork;
  const int work_width = static_cast<int>(work.right - work.left);
  const int work_height = static_cast<int>(work.bottom - work.top);
  // The minimum size wins over the work area, as WM_GETMINMAXINFO would
  // have it win anyway.
  const int width =
      std::max(std::min(Scale(size.width, scale_factor),
                        static_cast<int>(work_width * kMaxWorkAreaShare)),
               Scale(kMinWidth, scale_factor));
  const int height =
      std::max(std::min(Scale(size.height, scale_factor),
                        static_cast<int>(work_height * kMaxWorkAreaShare)),
               Scale(kMinHeight, scale_factor));
  // A window larger than the work area keeps its title bar on screen.
  const int left =
      static_cast<int>(work.left) + std::max(0, (work_width - width) / 2);
  const int top =
      static_cast<int>(work.top) + std::max(0, (work_height - height) / 2);
  SetWindowPos(window, nullptr, left, top, width, height,
               SWP_NOZORDER | SWP_NOACTIVATE);
}

// Whether Windows repaints a title bar as soon as its theme changes, as
// Windows 11 (build 22000) and later do. The manifest declares Windows 10
// support, so the version check sees the real build.
bool RepaintsTitleBarOnThemeChange() {
  OSVERSIONINFOEXW version{};
  version.dwOSVersionInfoSize = sizeof(version);
  version.dwBuildNumber = 22000;
  const DWORDLONG condition =
      VerSetConditionMask(0, VER_BUILDNUMBER, VER_GREATER_EQUAL);
  return VerifyVersionInfoW(&version, VER_BUILDNUMBER, condition) != FALSE;
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title, const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  // Windows picks the position, and with it the monitor; the window is then
  // sized for that monitor and centred on it, before it is shown.
  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW, CW_USEDEFAULT,
      CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, nullptr, nullptr,
      GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  CentreInWorkArea(window, size);
  UpdateTheme(window);

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_GETMINMAXINFO: {
      const double scale_factor = FlutterDesktopGetDpiForHWND(hwnd) / 96.0;
      auto min_max_info = reinterpret_cast<MINMAXINFO*>(lparam);
      min_max_info->ptMinTrackSize.x = Scale(kMinWidth, scale_factor);
      min_max_info->ptMinTrackSize.y = Scale(kMinHeight, scale_factor);
      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetDarkTitleBar(bool dark) {
  if (window_handle_) {
    ApplyDarkTitleBar(window_handle_, dark);
  }
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    ApplyDarkTitleBar(window, light_mode == 0);
  }
}

void Win32Window::ApplyDarkTitleBar(HWND const window, bool dark) {
  BOOL enable_dark_mode = dark;
  if (FAILED(DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                                   &enable_dark_mode,
                                   sizeof(enable_dark_mode)))) {
    DwmSetWindowAttribute(window, kUseImmersiveDarkModeBefore20H1,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }

  // Windows 10 repaints the title bar only when the window is next activated
  // or deactivated, so draw it inactive and back (or the reverse), ending in
  // its real state.
  if (IsWindowVisible(window) && !RepaintsTitleBarOnThemeChange()) {
    const bool active = GetActiveWindow() == window;
    SendMessage(window, WM_NCACTIVATE, !active, 0);
    SendMessage(window, WM_NCACTIVATE, active, 0);
  }
}
