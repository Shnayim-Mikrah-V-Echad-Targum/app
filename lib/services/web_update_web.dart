// The web's new versions (see web_update.dart), as web/flutter_bootstrap.js
// tells of them.
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The new version's service worker, which the bootstrap sets once it has
/// installed, alongside its 'sm-update-ready' event.
@JS('smUpdateReady')
external JSObject? get _waiting;

/// The bootstrap's restart into the new version.
@JS('smRestart')
external JSFunction? get _restart;

const _readyEvent = 'sm-update-ready';

bool updateWaiting() => _waiting != null;

void Function() listenForUpdate(void Function() onReady) {
  final listener = ((web.Event _) => onReady()).toJS;
  web.window.addEventListener(_readyEvent, listener);
  return () => web.window.removeEventListener(_readyEvent, listener);
}

void restartIntoUpdate() => _restart?.callAsFunction();
