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

/// The bootstrap's event as another window's restart lets the new version
/// take this one over.
const _tookOverEvent = 'sm-update-took-over';

bool updateWaiting() => _waiting != null;

void Function() listenForUpdate(void Function() onReady) => _listen(_readyEvent, onReady);

void Function() listenForTakeover(void Function() onTakeover) => _listen(_tookOverEvent, onTakeover);

void Function() _listen(String event, void Function() callback) {
  final listener = ((web.Event _) => callback()).toJS;
  web.window.addEventListener(event, listener);
  return () => web.window.removeEventListener(event, listener);
}

void restartIntoUpdate() => _restart?.callAsFunction();
