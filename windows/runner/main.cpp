#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <appmodel.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Held while the app runs, to keep it to one instance per user session:
// shared_preferences_windows rewrites its whole file on every change, so a
// second instance would overwrite progress logged in the first.
constexpr const wchar_t kInstanceMutexName[] = L"Local\\org.shnayimmikrah.app";

// How long a second launch waits for an instance that has no window yet, or
// one that is closing.
constexpr DWORD kInstanceWaitMs = 5000;

// Where COM looks for how to start the app's toast activator: the class that
// the notification plugin (flutter_local_notifications_windows) registers
// in the running app, and names to Windows as the app's CustomActivator, to
// hear of clicks on its notifications. The class id is
// WindowsInitializationSettings.guid in lib/services/notifications.dart and
// msix_config's toast_activator in pubspec.yaml.
constexpr const wchar_t kToastActivatorServerKey[] =
    L"Software\\Classes\\CLSID\\{7c1d6a3e-5b2f-4d8e-9a61-3f0c2e8b4d57}"
    L"\\LocalServer32";

// The window of the instance already running, or null if it has none. A
// window still hidden, as it waits for its first frame, is found too: it
// shows itself once the frame is drawn, or after a while without one
// (FlutterWindow::ShowOnce), so an instance stuck before its first frame
// can't keep every later launch from showing.
HWND FindRunningWindow() {
  return ::FindWindowW(kWindowClassName, nullptr);
}

// Whether |window| is closing (see kClosingProperty): it may already be
// hidden, and is about to be gone.
bool IsClosing(HWND window) {
  return ::GetPropW(window, kClosingProperty) != nullptr;
}

// Lets a click on a reminder's notification start the app when it isn't
// running, as it is run from its folder rather than installed. The MSIX's
// manifest declares how to start it (com:ExeServer). Run from the folder,
// the plugin registers its class only while the app runs, and with nothing
// to start for it, Windows drops the click once the app has closed, as it
// has when most reminders come. Written on every start, since the folder can
// move. COM starts the app with -Embedding, which it ignores.
void RegisterToastActivatorServer() {
  UINT32 length = 0;
  if (::GetCurrentPackageFullName(&length, nullptr) !=
      APPMODEL_ERROR_NO_PACKAGE) {
    return;
  }
  wchar_t path[MAX_PATH];
  const DWORD path_length = ::GetModuleFileNameW(nullptr, path, MAX_PATH);
  if (path_length == 0 || path_length >= MAX_PATH) {
    return;
  }
  const std::wstring command =
      L"\"" + std::wstring(path, path_length) + L"\"";
  HKEY key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, kToastActivatorServerKey, 0,
                        nullptr, REG_OPTION_NON_VOLATILE, KEY_SET_VALUE,
                        nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return;
  }
  // The key's default value, with its terminating null.
  ::RegSetValueExW(key, nullptr, 0, REG_SZ,
                   reinterpret_cast<const BYTE*>(command.c_str()),
                   static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  ::RegCloseKey(key);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE instance_mutex = ::CreateMutexW(nullptr, TRUE, kInstanceMutexName);
  if (instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND running = FindRunningWindow();
    if (running != nullptr && !IsClosing(running)) {
      BringToFront(running);
      ::CloseHandle(instance_mutex);
      return EXIT_SUCCESS;
    }
    // The other instance has no window yet, as it starts, or one that is
    // closing (say, the app was closed and opened again at once). Once it
    // has closed, this one takes over; once it has started, or should it
    // not close after all, its window is brought up.
    const DWORD wait = ::WaitForSingleObject(instance_mutex, kInstanceWaitMs);
    if (wait != WAIT_OBJECT_0 && wait != WAIT_ABANDONED) {
      if (HWND window = FindRunningWindow()) {
        BringToFront(window);
      }
      ::CloseHandle(instance_mutex);
      return EXIT_SUCCESS;
    }
  }

  // The instance that runs, alone, says how to start the app.
  RegisterToastActivatorServer();

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
  if (!window.Create(L"Shnayim Mikrah", size)) {
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
