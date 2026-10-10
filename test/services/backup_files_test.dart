import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shnayim_mikra/services/backup_files.dart';

/// The platform's file dialogs: [toOpen] is the file the reader chooses and
/// [saveTo] where they save (null for either cancels), and each dialog
/// keeps the types it was asked to offer.
class _Dialogs extends FileSelectorPlatform {
  XFile? toOpen;
  FileSaveLocation? saveTo;
  List<XTypeGroup>? openTypes;
  List<XTypeGroup>? saveTypes;
  String? suggestedName;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    openTypes = acceptedTypeGroups;
    return toOpen;
  }

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    saveTypes = acceptedTypeGroups;
    suggestedName = options.suggestedName;
    return saveTo;
  }
}

/// The share sheet, which keeps what it was asked to share.
class _ShareSheet extends SharePlatform {
  final shared = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    shared.add(params);
    return const ShareResult('', ShareResultStatus.dismissed);
  }
}

void main() {
  const files = BackupFiles();
  const name = 'shnayim-mikra-backup-2026-10-12.json';
  const data = '{"app":"shnayim_mikra"}';
  const origin = Rect.fromLTWH(16, 300, 380, 72);
  late _Dialogs dialogs;
  // SharePlus keeps the platform it first finds, so one sheet serves every
  // test.
  final sheet = _ShareSheet();
  SharePlatform.instance = sheet;

  setUp(() {
    dialogs = _Dialogs();
    FileSelectorPlatform.instance = dialogs;
    sheet.shared.clear();
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  void on(TargetPlatform platform) => debugDefaultTargetPlatformOverride = platform;

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('on ${platform.name}, saving shares the file, named, from the control, and leaves the rest to the sheet',
        () async {
      on(platform);
      final saved = await files.save(data, name, subject: 'Shnayim Mikra', origin: origin);
      expect(saved, isFalse, reason: 'the share sheet says for itself what became of it');
      final params = sheet.shared.single;
      expect(params.fileNameOverrides, [name]);
      expect(params.subject, 'Shnayim Mikra');
      expect(params.sharePositionOrigin, origin, reason: 'where the iPad anchors the sheet');
      final file = params.files!.single;
      expect(file.mimeType, 'application/json');
      expect(utf8.decode(await file.readAsBytes()), data);
      expect(dialogs.saveTypes, isNull, reason: 'no save dialog');
    });
  }

  group('on a desktop', () {
    late Directory dir;
    setUp(() {
      on(TargetPlatform.windows);
      dir = Directory.systemTemp.createTempSync('backup_files_test');
      addTearDown(() => dir.deleteSync(recursive: true));
    });

    test('saving asks where, offering the name and JSON, and saves the file there', () async {
      final path = '${dir.path}/$name';
      dialogs.saveTo = FileSaveLocation(path);
      expect(await files.save(data, name, subject: 'Shnayim Mikra'), isTrue, reason: 'saved here, to say so');
      expect(File(path).readAsStringSync(), data);
      expect(dialogs.suggestedName, name);
      final types = dialogs.saveTypes!.single;
      expect(types.extensions, ['json']);
      expect(types.mimeTypes, ['application/json']);
      expect(sheet.shared, isEmpty);
    });

    test('saving saves nothing, and says nothing, when the reader cancels', () async {
      expect(await files.save(data, name, subject: 'Shnayim Mikra'), isFalse);
      expect(dir.listSync(), isEmpty);
    });
  });

  group('opening', () {
    test('returns the text of the file chosen, or null when the reader cancels', () async {
      on(TargetPlatform.windows);
      expect(await files.open(), isNull);
      dialogs.toOpen = XFile.fromData(utf8.encode(data), name: name);
      expect(await files.open(), data);
    });

    test("turns away a file too large to be a backup, before reading it", () async {
      on(TargetPlatform.windows);
      dialogs.toOpen = XFile.fromData(Uint8List(BackupFiles.maxBytes + 1), name: name);
      await expectLater(files.open(), throwsFormatException);
      dialogs.toOpen = XFile.fromData(Uint8List(BackupFiles.maxBytes), name: name);
      expect(await files.open(), hasLength(BackupFiles.maxBytes));
    });

    test('offers JSON files, by extension, MIME type and, on Apple platforms, type identifier', () async {
      on(TargetPlatform.iOS);
      await files.open();
      final types = dialogs.openTypes!.single;
      expect(types.extensions, ['json']);
      expect(types.uniformTypeIdentifiers, ['public.json']);
      expect(types.mimeTypes, ['application/json']);
    });

    test('on Android also offers the types some file providers give a .json file', () async {
      on(TargetPlatform.android);
      await files.open();
      expect(dialogs.openTypes!.single.mimeTypes, ['application/json', 'text/plain', 'application/octet-stream']);
    });
  });
}
