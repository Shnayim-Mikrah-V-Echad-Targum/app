import 'dart:convert';

import 'update_core.dart';

/// What starts the installer: saves the release's script and runs it, so
/// that it installs the release once the app has closed. The Windows app's
/// is [WindowsUpdateInstaller] (update_io.dart); the tests fake it.
abstract interface class UpdateInstaller {
  /// Saves [script], the install.ps1 of the release [tag], and starts it.
  /// Returns once it has started; throws an [UpdateException] if it can't.
  Future<void> start({required String tag, required List<int> script});
}

/// The most each file may be: the releases' list, SHA256SUMS.txt and
/// install.ps1. Far more than each is.
const kMaxReleasesBytes = 4 << 20;
const kMaxChecksumsBytes = 64 << 10;
const kMaxScriptBytes = 1 << 20;

/// The Windows app's updates (docs/DESIGN_SYSTEM.md §9 About, Updates):
/// asks GitHub for the releases on [channel], and installs one by handing
/// it to its own install.ps1, checked first against the release's
/// SHA256SUMS.txt and GitHub's own digests. Every request goes through
/// [http] to [kUpdateHosts] alone (see [fetchAllowed]). Nothing is sent but
/// the requests themselves.
class UpdateService {
  UpdateService({required this.http, required this.installer, required this.channel, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final UpdateHttp http;
  final UpdateInstaller installer;
  final UpdateChannel channel;
  final DateTime Function() _now;

  /// The release to offer in place of [current], or null if none is newer
  /// on the channel.
  Future<Release?> check({required SemVer current}) async {
    if (channel == UpdateChannel.none) return null;
    final body = await fetchAllowed(
      http,
      kReleasesApi,
      maxBytes: kMaxReleasesBytes,
      accept: 'application/vnd.github+json',
      now: _now,
    );
    final String text;
    try {
      text = utf8.decode(body);
    } on FormatException {
      throw const UpdateException(UpdateFailure.badResponse, 'The releases are not UTF-8');
    }
    return selectUpdate(parseReleases(text), current: current, channel: channel);
  }

  /// Prepares [release] and hands it to its installer: downloads its
  /// install.ps1 and SHA256SUMS.txt, checks the script against both the
  /// checksums and GitHub's digests where it gives them, and starts it with
  /// [installer]. Throws an [UpdateException] for anything amiss, having
  /// started nothing.
  Future<void> install(Release release) async {
    if (!isInstallerTag(release.tag)) {
      throw UpdateException(UpdateFailure.badResponse, 'Not a release tag install.ps1 takes: ${release.tag}');
    }
    final script = release.asset(kInstallScriptAsset);
    final checksums = release.asset(kChecksumsAsset);
    if (!release.installable || script == null || checksums == null) {
      throw UpdateException(
        UpdateFailure.missingAsset,
        '${release.tag} lacks ${msiAssetName(release.versionName)}, $kInstallScriptAsset or $kChecksumsAsset',
      );
    }
    final sumsBytes = await fetchAllowed(http, checksums.url, maxBytes: kMaxChecksumsBytes, now: _now);
    if (checksums.sha256 case final digest? when sha256Hex(sumsBytes) != digest) {
      throw UpdateException(UpdateFailure.checksumMismatch, '$kChecksumsAsset is not the file GitHub has ($digest)');
    }
    final Map<String, String> sums;
    try {
      sums = parseSha256Sums(utf8.decode(sumsBytes));
    } on FormatException {
      throw const UpdateException(UpdateFailure.badResponse, '$kChecksumsAsset is not UTF-8');
    }
    // The script installs only the release's own installer, which it
    // checks against the same file.
    if (!sums.containsKey(msiAssetName(release.versionName))) {
      throw UpdateException(UpdateFailure.checksumMissing, '$kChecksumsAsset lists no installer for ${release.tag}');
    }
    final scriptBytes = await fetchAllowed(http, script.url, maxBytes: kMaxScriptBytes, now: _now);
    verifyDownload(scriptBytes, name: kInstallScriptAsset, sums: sums, digest: script.sha256);
    await installer.start(tag: release.tag, script: scriptBytes);
  }
}
