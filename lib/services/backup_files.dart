import 'dart:convert';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Saving and opening backup files, each platform's way. Tests replace it
/// through [backupFilesProvider].
class BackupFiles {
  const BackupFiles();

  /// Far more than years of progress take; a larger file isn't a backup.
  static const maxBytes = 8 * 1024 * 1024;

  static const _mimeType = 'application/json';

  /// JSON files. Some Android file providers type a .json file as plain text
  /// or as bytes, which would leave a backup greyed out, so there those
  /// types are offered too; a file that isn't a backup is turned away when
  /// it is read.
  static XTypeGroup get _json => XTypeGroup(
        label: 'JSON',
        extensions: const ['json'],
        uniformTypeIdentifiers: const ['public.json'],
        mimeTypes: [
          _mimeType,
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...['text/plain', 'application/octet-stream'],
        ],
      );

  /// Saves [data] as a file named [name]: on Android and iOS, through the
  /// share sheet (anchored at [origin], which the iPad needs), with
  /// [subject] for apps that take one; in a browser, as a download; and on
  /// a desktop, where the reader chooses.
  ///
  /// Returns whether the file was saved here, for the caller to say so; the
  /// share sheet says for itself what became of it. False if the reader
  /// cancels. Throws if the file can't be saved or shared.
  Future<bool> save(String data, String name, {required String subject, Rect? origin}) async {
    final file = XFile.fromData(utf8.encode(data), mimeType: _mimeType, name: name);
    if (kIsWeb) {
      // The browser downloads it, under the file's name.
      await file.saveTo(name);
      return true;
    }
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      await SharePlus.instance.share(ShareParams(
        files: [file],
        fileNameOverrides: [name],
        subject: subject,
        sharePositionOrigin: origin,
      ));
      return false;
    }
    final location = await getSaveLocation(suggestedName: name, acceptedTypeGroups: [_json]);
    if (location == null) return false;
    await file.saveTo(location.path);
    return true;
  }

  /// Lets the reader choose a backup file, and returns its text, or null if
  /// they cancel. Throws if it can't be read, or is too large to be one.
  Future<String?> open() async {
    final file = await openFile(acceptedTypeGroups: [_json]);
    if (file == null) return null;
    if (await file.length() > maxBytes) throw const FormatException('Too large for a backup');
    return file.readAsString();
  }
}

final backupFilesProvider = Provider<BackupFiles>((ref) => const BackupFiles());
