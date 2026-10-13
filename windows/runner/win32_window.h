#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>

// The class of the app's window. Unique to this app, so that a second launch
// can find the window of the first (see main.cpp).
inline constexpr wchar_t kWindowClassName[] = L"SHNAYIM_MIKRAH_WINDOW";

// A property the app's window has from the moment it is asked to close until
// it is gone (FlutterWindow::MessageHandler), so that a second launch waits
// for it to go rather than bring it forward (see main.cpp). Window properties
// can be read from another process.
inline constexpr wchar_t kClosingProperty[] = L"ShnayimMikrah.Closing";

// Brings |window|, which may be another process's, to the front, restoring it
// if it is minimized. Windows lets a process take the foreground only at
// times, such as just after the user launched it or clicked one of its
// notifications; at others, it flashes the window's taskbar button instead.
void BringToFront(HWND window);

// A class abstraction for a high DPI-aware Win32 Window. Intended to be
// inherited from by classes that wish to specialize with custom
// rendering and input handling
class Win32Window {
 public:
  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // Creates a win32 window with |title|, where it was when it was last closed
  // (the place is kept in the registry when the window is destroyed, or as
  // Windows ends the session), fitted to its monitor's work area if part of
  // it would be off screen. The first time, or once that monitor is gone, it
  // is centred on the monitor Windows opens it on (the one the app was
  // launched from): |size| is in logical pixels, scaled for that monitor, and
  // shrunk to fit 90% of its work area if need be. The window is invisible
  // until |Show| is called. Returns true if the window was created
  // successfully.
  bool Create(const std::wstring& title, const Size& size);

  // Show the current window, maximized if it was when it was last closed.
  // Returns true if the window was successfully shown.
  bool Show();

  // Release OS resources associated with window.
  void Destroy();

  // Inserts |content| into the window tree.
  void SetChildContent(HWND content);

  // Returns the backing Window handle to enable clients to set icon and other
  // window properties. Returns nullptr if the window has been destroyed.
  HWND GetHandle();

  // If true, closing this window will quit the application.
  void SetQuitOnClose(bool quit_on_close);

  // Return a RECT representing the bounds of the current client area.
  RECT GetClientArea();

  // Draws the title bar and frame dark or light. They start out following the
  // system's app theme; after that only this call changes them, so the app
  // can match its own theme.
  void SetDarkTitleBar(bool dark);

 protected:
  // Processes and route salient window messages for mouse handling,
  // size change and DPI. Delegates handling of these to member overloads that
  // inheriting classes can handle.
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // Called when CreateAndShow is called, allowing subclass window-related
  // setup. Subclasses should return false if setup fails.
  virtual bool OnCreate();

  // Called when Destroy is called.
  virtual void OnDestroy();

 private:
  friend class WindowClassRegistrar;

  // OS callback called by message pump. Handles the WM_NCCREATE message which
  // is passed when the non-client area is being created and enables automatic
  // non-client DPI scaling so that the non-client area automatically
  // responds to changes in DPI. All other messages are handled by
  // MessageHandler.
  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  // Retrieves a class instance pointer for |window|
  static Win32Window* GetThisFromHandle(HWND const window) noexcept;

  // Update the window frame's theme to match the system theme.
  static void UpdateTheme(HWND const window);

  // Applies |dark| to the frame of |window| and repaints its title bar.
  static void ApplyDarkTitleBar(HWND const window, bool dark);

  bool quit_on_close_ = false;

  // Whether |Show| maximizes the window, as it was when it was last closed.
  bool show_maximized_ = false;

  // window handle for top level window.
  HWND window_handle_ = nullptr;

  // window handle for hosted content.
  HWND child_content_ = nullptr;
};

#endif  // RUNNER_WIN32_WINDOW_H_
