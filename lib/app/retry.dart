import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderBase;

/// The `retry` of a provider whose failure a page shows with Try again
/// (docs/DESIGN_SYSTEM.md §6.22, Error state): none behind the reader's back.
///
/// Riverpod otherwise tries a failed provider again up to ten times, with a
/// delay that grows to 6.4 seconds, and stays loading meanwhile: the page
/// would spin for most of a minute before it said why, and a refresh would
/// wait as long to say it had failed. Here a failure is said at once, and
/// tried again when the reader asks, or as a page that shows it opens
/// ([FetchAgainIfFailed]).
Duration? noRetry(int retryCount, Object error) => null;

/// For a page that shows what a [noRetry] provider holds: a failure from
/// before the page showed it (on another page, or before the reader went
/// back and came again) is fetched again as the page first shows it, and the
/// page shows it loading meanwhile, rather than open on a failure the reader
/// never saw happen, which nothing would try again until they asked.
///
/// A failure while the page is shown stays, for the reader to try again.
mixin FetchAgainIfFailed<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// The providers this page has shown.
  final _seen = <ProviderBase<Object?>>{};

  /// Those being fetched again, by whether their fetch has begun.
  final _fetching = <ProviderBase<Object?>, bool>{};

  /// What [provider] holds, as [WidgetRef.watch] gives it, but loading while
  /// a failure from before this page showed it is fetched again: by [fetch],
  /// or else by invalidating [provider].
  AsyncValue<V> watchFresh<V>(ProviderBase<AsyncValue<V>> provider, {VoidCallback? fetch}) {
    final value = ref.watch(provider);
    if (_seen.add(provider) && value.hasError && !value.isLoading) {
      _fetching[provider] = false;
      // After this frame: fetched again while the tree builds, the provider
      // would tell the other pages that show it while they can't rebuild.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fetching[provider] = true;
        (fetch ?? () => ref.invalidate(provider, asReload: true))();
      });
    }
    final begun = _fetching[provider];
    if (begun == null) return value;
    if (begun && !value.isLoading) {
      _fetching.remove(provider);
      return value;
    }
    return AsyncLoading<V>();
  }
}
