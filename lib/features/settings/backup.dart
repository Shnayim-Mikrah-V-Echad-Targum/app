import 'dart:convert';

import '../../core/calendar/local_date.dart';
import '../progress/domain/progress_merge.dart';
import 'app_settings.dart';

/// What a backup file says it was made by.
const _app = 'shnayim_mikra';

/// The name a backup made at [now] is saved under, such as
/// `shnayim-mikra-backup-2026-10-11.json`.
String backupFileName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'shnayim-mikra-backup-${now.year.toString().padLeft(4, '0')}-${two(now.month)}-${two(now.day)}.json';
}

/// A backup of [progress] and [settings], made at [now], as JSON. Progress
/// this version couldn't read is kept apart, as `unreadableProgress`, so
/// that the rest can always be imported again, and that part restored with
/// it.
String encodeBackup(ProgressState progress, AppSettings settings, {required DateTime now}) =>
    const JsonEncoder.withIndent('  ').convert({
      'app': _app,
      'exportedAt': now.toUtc().toIso8601String(),
      'progress': progress.readable.toJson(),
      'unreadableProgress': ?progress.unknownMissingFrom(progress.readable),
      'settings': settings.toJson(),
    });

/// A backup file, as [parseBackup] reads it, and what it holds, for the
/// reader to see before restoring it.
class Backup {
  const Backup({
    required this.progress,
    this.unknownWeeks = const {},
    this.unknownPauses = const [],
    this.settings,
    this.exportedAt,
  });

  /// The progress, all of which this version can read.
  final ProgressState progress;

  /// Weeks and pauses that the version which made the backup couldn't
  /// read, kept apart in the file and restored untouched.
  final Map<String, Object?> unknownWeeks;
  final List<Object?> unknownPauses;

  /// The settings saved with it, if any.
  final AppSettings? settings;

  /// When it was made, in local time, if the file says.
  final DateTime? exportedAt;

  /// How many weeks it has a reading or the haftarah logged in.
  int get weeksLogged => progress.weeks.values.where((w) => w.completedUnits > 0 || w.haftarah != null).length;

  /// How many pauses it holds, leaving out those cancelled before they began.
  int get pauses => progress.pauses.where((p) => !p.deleted).length;

  /// The day the reader joined, as saved with the settings. A backup
  /// without one counts as joined on the day of its earliest reading, as a
  /// cloud backup does (see [mergeSyncPayload]), so that the history it
  /// restores counts. Null if it has neither.
  LocalDate? get joinDate => settings?.joinDate ?? earliestReadDate(progress);
}

/// Reads a backup file made by [encodeBackup], or returns null if [raw]
/// isn't one. A file with progress this version can't read exactly is
/// rejected whole, rather than half imported. Its settings are read as
/// stored settings are, keeping the default for any that can't be.
Backup? parseBackup(String raw) {
  try {
    final j = jsonDecode(raw.trim());
    if (j is! Map<String, dynamic> || j['app'] != _app) return null;
    final progress = ProgressState.fromJson(j['progress'] as Map<String, dynamic>, strict: true);
    final unreadable = (j['unreadableProgress'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    final settings = j['settings'];
    final exportedAt = j['exportedAt'];
    return Backup(
      progress: progress,
      unknownWeeks: (unreadable['weeks'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
      unknownPauses: (unreadable['pauses'] ?? const []) as List,
      settings: settings is Map<String, dynamic> ? AppSettings.fromJson(settings) : null,
      exportedAt: exportedAt is String ? DateTime.tryParse(exportedAt)?.toLocal() : null,
    );
  } catch (_) {
    return null;
  }
}

/// Whether [progress] holds anything a reader would miss if it were
/// replaced: a reading logged or under way, the haftarah, or a pause.
bool holdsProgress(ProgressState progress) =>
    progress.weeks.values.any((w) => w.isStarted || w.haftarah != null) || progress.pauses.any((p) => !p.deleted);
