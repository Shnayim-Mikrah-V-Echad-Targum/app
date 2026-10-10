import 'dart:ui';

import 'package:shnayim_mikra/services/backup_files.dart';

/// Backup files without the platform: [file] is what the reader chooses
/// (null to cancel), and what is saved is kept in [saved].
class FakeBackupFiles extends BackupFiles {
  FakeBackupFiles({this.file, this.openError, this.savesHere = true, this.saveError});

  final String? file;

  /// Thrown instead of choosing a file, if set.
  final Object? openError;

  /// Whether a save happens here, as on a desktop or in a browser, rather
  /// than through the share sheet.
  final bool savesHere;

  /// Thrown instead of saving, if set.
  final Object? saveError;

  final saved = <({String data, String name, String subject, Rect? origin})>[];

  @override
  Future<bool> save(String data, String name, {required String subject, Rect? origin}) async {
    if (saveError case final e?) throw e;
    saved.add((data: data, name: name, subject: subject, origin: origin));
    return savesHere;
  }

  @override
  Future<String?> open() async {
    if (openError case final e?) throw e;
    return file;
  }
}
