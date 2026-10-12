/// The `retry` of a provider whose failure a page shows with Try again
/// (docs/DESIGN_SYSTEM.md §6.22, Error state): none behind the reader's back.
///
/// Riverpod otherwise tries a failed provider again up to ten times, with a
/// delay that grows to 6.4 seconds, and stays loading meanwhile: the page
/// would spin for most of a minute before it said why, and a refresh would
/// wait as long to say it had failed. Here a failure is said at once, and
/// tried again when the reader asks.
Duration? noRetry(int retryCount, Object error) => null;
