import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/pending_saves.dart';
import 'web_update_stub.dart' if (dart.library.js_interop) 'web_update_web.dart' as platform;

/// New versions of the web app, by way of web/flutter_bootstrap.js: once one
/// has installed, it waits for every window of this one to close, and the
/// app may offer to restart into it instead. A restart in one window lets it
/// take over the others, which restart too. Off the web there are none.
class WebUpdates {
  const WebUpdates();

  /// Whether a new version has installed and is waiting.
  bool get waiting => platform.updateWaiting();

  /// Calls [onReady] when a new version has installed; returns what stops
  /// listening.
  void Function() listen(void Function() onReady) => platform.listenForUpdate(onReady);

  /// Calls [onTakeover] when a restart in another window of the app has let
  /// the new version take this one over, whose code is still the old
  /// version's; returns what stops listening.
  void Function() listenForTakeover(void Function() onTakeover) => platform.listenForTakeover(onTakeover);

  /// Reloads the app in the new version, which takes over this one.
  void restart() => platform.restartIntoUpdate();
}

final webUpdatesProvider = Provider<WebUpdates>((ref) => const WebUpdates());

/// Whether a new version of the web app is ready for a restart (see
/// [WebUpdates]), offered at the top of Today and in About.
class WebUpdateReady extends Notifier<bool> {
  @override
  bool build() {
    final updates = ref.watch(webUpdatesProvider);
    ref.onDispose(updates.listen(() => state = true));
    return updates.waiting;
  }

  /// Restarts into the new version, once the settings and progress held
  /// back are saved: the reader's place and reading carry over. If storage
  /// fails, it restarts all the same, as the app closes all the same (see
  /// [PendingSaves]): at most the last half second's changes are lost.
  Future<void> restart() async {
    try {
      await PendingSaves.flushWith(ref.read);
    } catch (e) {
      debugPrint('Could not save before restarting: $e');
    }
    ref.read(webUpdatesProvider).restart();
  }
}

final webUpdateReadyProvider = NotifierProvider<WebUpdateReady, bool>(WebUpdateReady.new);

/// Whether Today's offer of a new version has been put away. It stays away
/// until the app next starts, in the new version unless it was left open;
/// About still offers it.
class WebUpdateDismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

final webUpdateDismissedProvider = NotifierProvider<WebUpdateDismissed, bool>(WebUpdateDismissed.new);
