import 'package:timezone/data/latest_all.dart' deferred as tzdata;
import 'package:timezone/timezone.dart' as tz;

// The time-zone database, which a city's times need (Zmanim): every zone,
// since the smaller databases leave out some that the list of cities names.
// Its code and data, some 2 MB of Dart, are a deferred library, which the
// web build keeps in a file of its own (main.dart.js_N.part.js) and
// downloads only when a city's times are first needed, so the first visit
// doesn't wait for it. The other platforms build it into the app, and
// loading it costs nothing.

/// Whether the time-zone database is in: loaded and decoded.
bool get timeZonesLoaded => tz.timeZoneDatabase.isInitialized;

/// Loads the time-zone database if it isn't in yet: its code, then the
/// decoding, which blocks for a while, by [schedule] when it is given (to
/// run it when the UI is idle). Decoding resets the local time zone (which
/// the notification service sets) to UTC, so it never runs twice, however
/// many callers wait at once.
Future<void> ensureTimeZones({Future<void> Function(void Function() decode)? schedule}) async {
  if (timeZonesLoaded) return;
  await tzdata.loadLibrary();
  if (timeZonesLoaded) return;
  if (schedule == null) return _decode();
  await schedule(_decode);
}

void _decode() {
  if (!timeZonesLoaded) tzdata.initializeTimeZones();
}
