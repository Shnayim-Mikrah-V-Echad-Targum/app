import 'dart:async';

import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/services/reminder_planner.dart' show ReminderZmanim;
import 'package:shnayim_mikrah/services/updates/update_core.dart';
import 'package:shnayim_mikrah/services/updates/update_service.dart';

/// A city's Shabbat times by day, as the quiet hours read them.
typedef ReminderZmanimFor = ReminderZmanim Function(LocalDate date);

/// The files a release of [version] carries for Windows: its installer, the
/// script that installs it, and their checksums.
List<String> releaseAssets(String version) => [
      'ShnayimMikrah-$version-windows-x64.msi',
      'ShnayimMikrah-$version-windows-x64.zip',
      'ShnayimMikrah-$version-android-webapp.apk',
      'install.ps1',
      'SHA256SUMS.txt',
    ];

/// Where GitHub serves [name] of the release [tag] from, before its
/// redirect.
Uri assetUrl(String tag, String name) =>
    Uri.parse('https://github.com/$kUpdateRepository/releases/download/$tag/$name');

/// A release as GitHub's releases API lists it, with [assets] (all of
/// Windows' unless given) and the API's [digests] of some of them.
Map<String, Object?> releaseJson(
  String tag, {
  bool prerelease = false,
  bool draft = false,
  List<String>? assets,
  Map<String, String> digests = const {},
}) =>
    {
      'tag_name': tag,
      'name': 'Shnayim Mikrah $tag',
      'draft': draft,
      'prerelease': prerelease,
      'html_url': 'https://github.com/$kUpdateRepository/releases/tag/$tag',
      'body': 'Notes',
      'assets': [
        for (final name in assets ?? releaseAssets(tag.substring(1)))
          {
            'name': name,
            'size': 1000,
            'browser_download_url': '${assetUrl(tag, name)}',
            if (digests[name] case final digest?) 'digest': 'sha256:$digest',
          },
      ],
    };

/// GitHub's answer that [location] has the file.
UpdateResponse redirect(String location) => UpdateResponse(302, headers: {'location': location});

/// GitHub, as the tests have it: [responses] by address, 404 for any other,
/// and each request kept, with its headers.
class FakeUpdateHttp implements UpdateHttp {
  FakeUpdateHttp(Map<Uri, UpdateResponse> responses) : responses = {...responses};

  final Map<Uri, UpdateResponse> responses;
  final requested = <Uri>[];
  final headers = <Map<String, String>>[];

  /// Holds each answer until completed, where set.
  Completer<void>? hold;

  @override
  Future<UpdateResponse> get(Uri uri, {required Map<String, String> headers, required int maxBytes}) async {
    requested.add(uri);
    this.headers.add(headers);
    await hold?.future;
    return responses[uri] ?? const UpdateResponse(404);
  }
}

/// An installer that starts nothing, and keeps what it was asked to start.
class FakeInstaller implements UpdateInstaller {
  final started = <(String, List<int>)>[];

  /// Thrown where set, as a script that can't be saved or started.
  UpdateException? fails;

  @override
  Future<void> start({required String tag, required List<int> script}) async {
    if (fails case final error?) throw error;
    started.add((tag, script));
  }
}
