#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Held while the app runs, to keep it to one instance per user session:
// shared_preferences_windows rewrites its whole file on every change, so a
// second instance would overwrite progress logged in the first.
constexpr const wchar_t kInstanceMutexName[] = L"Local\\org.shnayimmikra.app";

// How long a second launch waits for an instance that has no window yet,
// because it is starting or closing.
constexpr DWORD kInstanceWaitMs = 5000;

// Brings the window of the instance already running to the front. Returns
// false if it has no window.
bool ActivateRunningInstance() {
  HWND window = ::FindWindowW(kWindowClassName, nullptr);
  if (window == nullptr) {
    return false;
  }
  if (::IsIconic(window)) {
    ::ShowWindow(window, SW_RESTORE);
  }
  ::SetForegroundWindow(window);
  return true;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE instance_mutex = ::CreateMutexW(nullptr, TRUE, kInstanceMutexName);
  if (instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    if (ActivateRunningInstance()) {
      ::CloseHandle(instance_mutex);
      return EXIT_SUCCESS;
    }
    // The other instance has no window: it is starting, or closing (say,
    // the app was closed and opened again at once). Once it has closed,
    // this one takes over; once it has started, its window is brought up.
    const DWORD wait = ::WaitForSingleObject(instance_mutex, kInstanceWaitMs);
    if (wait != WAIT_OBJECT_0 && wait != WAIT_ABANDONED) {
      ActivateRunningInstance();
      ::CloseHandle(instance_mutex);
      return EXIT_SUCCESS;
    }
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Size size(1200, 820);
  if (!window.Create(L"Shnayim Mikra", size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // The window, and the Flutter engine with it, are gone: nothing more is
  // saved, so another launch may start at once.
  if (instance_mutex != nullptr) {
    ::ReleaseMutex(instance_mutex);
    ::CloseHandle(instance_mutex);
  }
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
