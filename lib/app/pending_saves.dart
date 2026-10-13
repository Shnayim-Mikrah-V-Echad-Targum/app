import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'providers.dart';

/// Writes the settings and progress that their [DelayedSave]s are holding
/// back whenever the app might be about to stop: when it loses focus, is
/// hidden (the last moment the system reliably gives before it may kill the
/// app), is detached, or is asked to exit (closing the window on desktop),
/// and when the app is disposed.
class PendingSaves {
  PendingSaves(this.container) {
    _lifecycle = AppLifecycleListener(
      onInactive: flush,
      onHide: flush,
      onDetach: flush,
      onExitRequested: () async {
        // Never keeps the app open, even if storage fails.
        await flush().catchError((Object e) => debugPrint('Could not save before exiting: $e'));
        return AppExitResponse.exit;
      },
    );
  }

  /// Where the settings and progress are.
  final ProviderContainer container;
  late final AppLifecycleListener _lifecycle;

  /// Writes whatever is waiting now.
  Future<void> flush() => flushWith(container.read);

  /// Writes whatever the settings and progress are holding back now, reading
  /// them with [read]: a container's, or a provider's own (a restart into a
  /// new version of the web app saves them first).
  static Future<void> flushWith(T Function<T>(ProviderListenable<T> provider) read) async {
    await Future.wait([
      read(settingsProvider.notifier).flush(),
      read(progressProvider.notifier).flush(),
    ]);
  }

  /// Stops following the app's lifecycle, writing whatever is waiting. (A
  /// container disposed first, as a failed test leaves its own, wrote its
  /// saves as it went, and can't be read.)
  void dispose() {
    _lifecycle.dispose();
    unawaited(flush().catchError((Object e) => debugPrint('Could not save: $e')));
  }
}
