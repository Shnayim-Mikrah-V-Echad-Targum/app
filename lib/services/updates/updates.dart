import 'dart:async';
import 'dart:convert';
import 'dart:ui' show AppExitType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/city_providers.dart' show deviceClockProvider;
import '../../app/config.dart';
import '../../app/pending_saves.dart';
import '../../app/providers.dart';
import '../../core/calendar/tz_database.dart' show timeZonesLoaded;
import '../recent_errors.dart';
import '../reminder_planner.dart' show reminderZmanim;
import 'update_core.dart';
import 'update_io.dart' if (dart.library.js_interop) 'update_stub.dart' as platform;
import 'update_service.dart';

export 'update_core.dart' show Release, SemVer, UpdateChannel, kReleasesPage, releasePageOf;

/// The channel the build looks for updates on (UPDATE_CHANNEL): none unless
/// it names one.
final updateChannelProvider = Provider<UpdateChannel>((ref) => UpdateChannel.parse(AppConfig.updateChannel));

/// What sends the updates' requests: dart:io's, which the tests replace.
final updateHttpProvider = Provider<UpdateHttp>((ref) => platform.createUpdateHttp());

/// What hands a release to its install.ps1: Windows', which the tests
/// replace.
final updateInstallerProvider = Provider<UpdateInstaller>((ref) => platform.createUpdateInstaller());

/// What closes the app once the installer has started, so that it can
/// replace it: Flutter's exit, which asks nothing (the saves are written
/// first), and should the window still be open a few seconds on, the
/// process's own. The tests replace it.
final updateAppExitProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    unawaited(ServicesBinding.instance.exitApplication(AppExitType.required));
    await Future<void>.delayed(const Duration(seconds: 5));
    platform.forceExit();
  },
);

/// The version running, as the platform gives it ("0.0.1"), or null where
/// it can't be read.
final runningVersionProvider = FutureProvider<SemVer?>((ref) async {
  try {
    return SemVer.tryParse((await PackageInfo.fromPlatform()).version);
  } catch (_) {
    return null;
  }
});

/// The updates of the Windows app on the build's channel, or null wherever
/// there are none: off Windows (the web and the phones update in their own
/// ways), and in every build without UPDATE_CHANNEL, which is how CI, pull
/// requests, the stores' builds and the tests are built. Null, nothing is
/// ever requested.
final updateServiceProvider = Provider<UpdateService?>((ref) {
  final channel = ref.watch(updateChannelProvider);
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows || channel == UpdateChannel.none) return null;
  return UpdateService(
    http: ref.watch(updateHttpProvider),
    installer: ref.watch(updateInstallerProvider),
    channel: channel,
    now: TodayController.now,
  );
});

/// What last went wrong, for the message About shows.
enum UpdateProblem {
  /// Check now couldn't reach the releases.
  check,

  /// Install couldn't prepare the release; nothing was changed.
  install,
}

/// How Check now ended.
enum UpdateCheckResult { found, latest, failed, quiet }

/// The updater's state (docs/DESIGN_SYSTEM.md §9 About, Updates).
@immutable
class UpdateState {
  const UpdateState({
    this.supported = false,
    this.checking = false,
    this.installing = false,
    this.available,
    this.lastCheck,
    this.problem,
    this.quiet = false,
  });

  /// Whether this build looks for updates at all ([updateServiceProvider]).
  final bool supported;
  final bool checking;

  /// Whether Install is preparing the release, until the app closes.
  final bool installing;

  /// A newer release, ready to install.
  final Release? available;

  /// When the releases were last read.
  final DateTime? lastCheck;
  final UpdateProblem? problem;

  /// Whether it is Shabbat or Yom Tov, or their eve after the reminders'
  /// cutoff ([updatesQuietAt]): nothing is looked for or offered.
  final bool quiet;

  /// The release offered: [available], but never while [quiet].
  Release? get offered => quiet ? null : available;

  UpdateState copyWith({
    bool? checking,
    bool? installing,
    Object? available = _keep,
    DateTime? lastCheck,
    Object? problem = _keep,
    bool? quiet,
  }) =>
      UpdateState(
        supported: supported,
        checking: checking ?? this.checking,
        installing: installing ?? this.installing,
        available: identical(available, _keep) ? this.available : available as Release?,
        lastCheck: lastCheck ?? this.lastCheck,
        problem: identical(problem, _keep) ? this.problem : problem as UpdateProblem?,
        quiet: quiet ?? this.quiet,
      );

  static const _keep = Object();
}

/// Looks for a new version of the Windows app, and installs it when asked
/// (lib/services/updates/): by itself at most once every 12 hours while
/// Check automatically is on, sooner again after a failure and never before
/// GitHub says to ([UpdateRecord]), and whenever Check now is tapped; never
/// on Shabbat or Yom Tov, nor on their eve after the reminders' cutoff, when
/// nothing is offered either. What it found is kept on the device, so that
/// the offer stands as the app opens again. In a build without updates
/// ([updateServiceProvider] null) it does nothing at all.
class UpdateController extends Notifier<UpdateState> {
  Timer? _timer;

  /// How often the app looks again whether a check is due, and whether it
  /// is time to keep quiet, while it is open.
  static const _tick = Duration(minutes: 5);

  @override
  UpdateState build() {
    final service = ref.watch(updateServiceProvider);
    _timer?.cancel();
    _timer = null;
    if (service == null) return const UpdateState();
    ref.onDispose(() => _timer?.cancel());
    // Turned on, it looks at once if a check is due.
    ref.listen(settingsProvider.select((s) => s.autoUpdateCheck), (_, on) {
      if (on) unawaited(_automaticCheck());
    });
    // The quiet hours move with the city and the days of Yom Tov.
    ref.listen(settingsProvider.select((s) => (s.oneDayYomTov, s.shabbatCity)), (_, _) => _refreshQuiet());
    // Once the running version is known: the offer kept, if it is still
    // newer, and the check, if one is due.
    Future<void>(_start);
    // Tests turn the timers off, as they do the reading day's.
    if (TodayController.autoRollover) _timer = Timer.periodic(_tick, (_) => _tickOver());
    return UpdateState(supported: true, lastCheck: _record().lastSuccess, quiet: _quietNow());
  }

  UpdateRecord _record() {
    final raw = ref.read(sharedPreferencesProvider).getString(UpdateRecord.storageKey);
    if (raw == null) return const UpdateRecord();
    try {
      return UpdateRecord.fromJson(jsonDecode(raw));
    } on FormatException {
      return const UpdateRecord();
    }
  }

  void _save(UpdateRecord record) =>
      unawaited(ref.read(sharedPreferencesProvider).setString(UpdateRecord.storageKey, jsonEncode(record.toJson())));

  /// Whether to keep quiet now ([updatesQuietAt]), by the reader's days of
  /// Yom Tov and, where a city is chosen and its clock known, its times.
  bool _quietNow() {
    final settings = ref.read(settingsProvider);
    final place = settings.shabbatCity;
    final zmanim =
        place != null && timeZonesLoaded ? reminderZmanim(place, deviceOffset: ref.read(deviceClockProvider)) : null;
    return updatesQuietAt(TodayController.now(), israel: settings.oneDayYomTov, zmanim: zmanim);
  }

  /// Whether it is quiet now, told to the page as it changes.
  bool _refreshQuiet() {
    final quiet = _quietNow();
    if (ref.mounted && quiet != state.quiet) state = state.copyWith(quiet: quiet);
    return quiet;
  }

  Future<void> _start() async {
    final current = await ref.read(runningVersionProvider.future);
    if (!ref.mounted || current == null) return;
    final kept = _record().offer;
    final offer = kept == null ? null : selectUpdate([kept], current: current, channel: ref.read(updateChannelProvider));
    if (offer != null && state.available == null) state = state.copyWith(available: offer);
    if (ref.read(settingsProvider).autoUpdateCheck) await _automaticCheck();
  }

  void _tickOver() {
    _refreshQuiet();
    if (ref.read(settingsProvider).autoUpdateCheck) unawaited(_automaticCheck());
  }

  /// Looks, if a check is due and nothing keeps it from it.
  Future<void> _automaticCheck() async {
    if (!ref.mounted || state.checking || state.installing) return;
    if (_refreshQuiet() || !_record().isDue(TodayController.now())) return;
    await _check(manual: false);
  }

  /// Looks for a new version now, as Check now asks; not while it is quiet.
  Future<UpdateCheckResult> checkNow() async {
    if (!state.supported || state.checking || state.installing) return UpdateCheckResult.failed;
    if (_refreshQuiet()) return UpdateCheckResult.quiet;
    return _check(manual: true);
  }

  Future<UpdateCheckResult> _check({required bool manual}) async {
    final service = ref.read(updateServiceProvider);
    if (service == null) return UpdateCheckResult.failed;
    final at = TodayController.now();
    // Until the time GitHub said to ask again, it would only refuse: it
    // isn't asked.
    final wait = _record().retryAt;
    if (wait != null && wait.isAfter(at)) {
      if (manual) {
        _keepError(
          UpdateException(UpdateFailure.rateLimited, 'GitHub asked to wait until ${wait.toUtc()}', retryAt: wait),
          StackTrace.current,
          'checking for updates',
        );
        state = state.copyWith(problem: UpdateProblem.check);
      }
      return UpdateCheckResult.failed;
    }
    state = state.copyWith(checking: true, problem: manual ? null : UpdateState._keep);
    try {
      final current = await ref.read(runningVersionProvider.future);
      if (current == null) throw const UpdateException(UpdateFailure.unknownVersion, 'The running version is unknown');
      final release = await service.check(current: current);
      if (!ref.mounted) return UpdateCheckResult.failed;
      _save(_record().succeeded(at, offer: release));
      state = state.copyWith(checking: false, available: release, lastCheck: at, problem: null);
      return release == null ? UpdateCheckResult.latest : UpdateCheckResult.found;
    } catch (e, stack) {
      if (!ref.mounted) return UpdateCheckResult.failed;
      _save(_record().failed(at, retryAt: e is UpdateException ? e.retryAt : null));
      // A check the reader asked for says so, and keeps what went wrong for
      // support; one the app made by itself fails quietly, and tries again
      // later.
      if (manual) _keepError(e, stack, 'checking for updates');
      state = state.copyWith(checking: false, problem: manual ? UpdateProblem.check : UpdateState._keep);
      return UpdateCheckResult.failed;
    }
  }

  /// Installs the release offered: prepares it (its script downloaded and
  /// checked, then started), saves the settings and progress held back, and
  /// closes the app, which the script replaces and opens again. Returns
  /// false, having changed nothing, where it can't.
  Future<bool> install() async {
    final release = state.offered;
    final service = ref.read(updateServiceProvider);
    if (release == null || service == null || state.installing) return false;
    if (_refreshQuiet()) return false;
    state = state.copyWith(installing: true, problem: null);
    try {
      await service.install(release);
    } catch (e, stack) {
      _keepError(e, stack, 'preparing the update to ${release.tag}');
      if (ref.mounted) state = state.copyWith(installing: false, problem: UpdateProblem.install);
      return false;
    }
    // The script waits for the app to close: it closes whatever happens.
    try {
      await PendingSaves.flushWith(ref.read);
    } catch (e) {
      debugPrint('Could not save before updating: $e');
    }
    await ref.read(updateAppExitProvider)();
    return true;
  }

  void _keepError(Object error, StackTrace stack, String doing) => recentErrors.add(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'updates',
        context: ErrorDescription('while $doing'),
      ));
}

final updateControllerProvider = NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

/// The version whose offer on Today has been put away, for the session:
/// About still offers it, and a newer one is offered again.
class UpdateDismissed extends Notifier<String?> {
  @override
  String? build() => null;

  void dismiss(String tag) => state = tag;
}

final updateDismissedProvider = NotifierProvider<UpdateDismissed, String?>(UpdateDismissed.new);
