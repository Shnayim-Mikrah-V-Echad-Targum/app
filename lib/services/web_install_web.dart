// The browser's offer to install the web app (see web_install.dart), as
// web/index.html keeps it in window.smInstall.
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// window.smInstall: the offer kept from beforeinstallprompt, whether the
/// app was installed from it (appinstalled), and whether it runs installed.
extension type _SmInstall._(JSObject _) implements JSObject {
  external bool available();
  external bool installed();
  external bool standalone();
  external JSPromise<JSString> prompt();
}

@JS('smInstall')
external _SmInstall? get _install;

/// The event index.html dispatches as the offer comes or goes.
const _changeEvent = 'sm-install-change';

bool promptAvailable() {
  try {
    return _install?.available() ?? false;
  } catch (_) {
    return false;
  }
}

bool installedNow() {
  try {
    return _install?.installed() ?? false;
  } catch (_) {
    return false;
  }
}

/// Whether the app runs as an installed app (display-mode standalone, or a
/// home-screen app on an iPhone), by index.html's reckoning, or by the
/// display mode alone where an older page, from before it had one, is open.
bool runningStandalone() {
  try {
    final install = _install;
    if (install != null) return install.standalone();
  } catch (_) {
    // As below.
  }
  return web.window.matchMedia('(display-mode: standalone)').matches;
}

Future<String> prompt() async {
  final install = _install;
  if (install == null) return 'unavailable';
  try {
    return (await install.prompt().toDart).toDart;
  } catch (_) {
    return 'unavailable';
  }
}

void Function() listen(void Function() onChange) {
  final listener = ((web.Event _) => onChange()).toJS;
  web.window.addEventListener(_changeEvent, listener);
  return () => web.window.removeEventListener(_changeEvent, listener);
}
