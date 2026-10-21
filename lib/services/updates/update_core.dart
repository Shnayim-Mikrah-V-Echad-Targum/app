// The Windows app's updates from GitHub Releases, without Flutter or I/O of
// its own: which release to offer, how to read and check what is
// downloaded, which hosts may serve it, when to look again, and when to keep
// quiet. The requests go through an [UpdateHttp], which the tests fake
// (lib/services/updates/update_io.dart has the real one).
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import '../../core/calendar/jewish_holidays.dart';
import '../../core/calendar/local_date.dart';
import '../reminder_planner.dart' show ReminderZmanim, erevCutoffMinutes;

/// The repository whose releases the app updates from.
const kUpdateRepository = 'Shnayim-Mikrah-V-Echad-Targum/app';

/// The releases, newest first, as GitHub lists them to anyone: 60 requests
/// an hour from one address, without signing in.
final kReleasesApi = Uri.parse('https://api.github.com/repos/$kUpdateRepository/releases?per_page=20');

/// The releases' page, for a release whose own page is unknown.
final kReleasesPage = Uri.parse('https://github.com/$kUpdateRepository/releases');

/// The page of the release of [version], with its notes: What's new in the
/// version running.
Uri releasePageOf(SemVer version) => Uri.parse('https://github.com/$kUpdateRepository/releases/tag/v$version');

/// The installer script every release carries, a copy of
/// tool/windows/install.ps1 at its tag.
const kInstallScriptAsset = 'install.ps1';

/// The SHA-256 of each of a release's other files, in sha256sum's format.
const kChecksumsAsset = 'SHA256SUMS.txt';

/// The Windows installer of the release whose version is [version] ("0.0.2").
String msiAssetName(String version) => 'ShnayimMikrah-$version-windows-x64.msi';

/// The hosts the updates may come from, redirects included: GitHub's API,
/// its site, and the two that serve a release's files.
const kUpdateHosts = {
  'api.github.com',
  'github.com',
  'objects.githubusercontent.com',
  'release-assets.githubusercontent.com',
};

/// What the app calls itself to GitHub, which asks every request to say:
/// its name alone, no version or device.
const kUpdateUserAgent = 'ShnayimMikrah';

/// Whether [uri] may be fetched for an update: HTTPS, on its own port, to
/// one of [kUpdateHosts], with no one's name or password in it.
bool isAllowedUpdateUri(Uri uri) =>
    uri.scheme == 'https' && uri.port == 443 && uri.userInfo.isEmpty && kUpdateHosts.contains(uri.host.toLowerCase());

/// The release tags the app reads ('v0.0.2', 'v1.2.0-beta.1'), which name a
/// folder on the disk as well: letters, digits, dots and hyphens alone,
/// nothing that could lead out of it.
bool isSafeTag(String tag) =>
    tag.length <= 64 && RegExp(r'^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[0-9A-Za-z]+(\.[0-9A-Za-z]+)*)?$').hasMatch(tag);

/// The tags install.ps1 installs (its SM_TAG, tool/windows/install.ps1): a
/// release's version alone, 'v0.0.2', which its installer is named for
/// ([msiAssetName]). A tag with a pre-release's suffix ('v1.0.0-rc.1') is
/// read and ordered, but never offered: the script would refuse it.
bool isInstallerTag(String tag) => RegExp(r'^v(0|[1-9]\d{0,8})\.(0|[1-9]\d{0,8})\.(0|[1-9]\d{0,8})$').hasMatch(tag);

// ---------------------------------------------------------------------------
// Channels and versions

/// Which releases the app looks among, as the build says (UPDATE_CHANNEL).
enum UpdateChannel {
  /// No update is ever looked for.
  none,

  /// Published releases that aren't pre-releases.
  stable,

  /// Pre-releases too.
  prerelease;

  /// The channel [value] names; anything else, an empty one included, is
  /// [none].
  static UpdateChannel parse(String value) => switch (value.trim().toLowerCase()) {
        'stable' => stable,
        'prerelease' => prerelease,
        _ => none,
      };
}

/// A version as Semantic Versioning 2.0.0 has it, ordered as it orders them:
/// 0.0.2 after 0.0.1, 1.0.0 after 1.0.0-rc.1, 1.0.0-beta.11 after
/// 1.0.0-beta.2. Build metadata ('+12') is read and ignored.
final class SemVer implements Comparable<SemVer> {
  const SemVer(this.major, this.minor, this.patch, [this.preRelease = const []]);

  final int major;
  final int minor;
  final int patch;

  /// The pre-release's identifiers ('rc', '1' of '1.0.0-rc.1'); none for a
  /// release.
  final List<String> preRelease;

  static final _pattern = RegExp(
    r'^v?(0|[1-9]\d{0,8})\.(0|[1-9]\d{0,8})\.(0|[1-9]\d{0,8})'
    r'(?:-((?:0|[1-9]\d{0,8}|\d*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d{0,8}|\d*[A-Za-z-][0-9A-Za-z-]*))*))?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  /// [text] as a version ('0.0.1', 'v0.0.2', '1.0.0-rc.1', '0.0.1+1'), or
  /// null if it isn't one.
  static SemVer? tryParse(String text) {
    final m = _pattern.firstMatch(text.trim());
    if (m == null) return null;
    return SemVer(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), m[4]?.split('.') ?? const []);
  }

  bool get isPreRelease => preRelease.isNotEmpty;

  @override
  int compareTo(SemVer other) {
    for (final (a, b) in [(major, other.major), (minor, other.minor), (patch, other.patch)]) {
      if (a != b) return a.compareTo(b);
    }
    // A release comes after its pre-releases.
    if (preRelease.isEmpty || other.preRelease.isEmpty) {
      return (preRelease.isEmpty ? 1 : 0) - (other.preRelease.isEmpty ? 1 : 0);
    }
    for (var i = 0; i < preRelease.length && i < other.preRelease.length; i++) {
      final a = preRelease[i], b = other.preRelease[i];
      final x = int.tryParse(a), y = int.tryParse(b);
      final order = switch ((x, y)) {
        (final x?, final y?) => x.compareTo(y),
        // Numbers come before words.
        (_?, null) => -1,
        (null, _?) => 1,
        (null, null) => a.compareTo(b),
      };
      if (order != 0) return order;
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }

  bool operator >(SemVer other) => compareTo(other) > 0;
  bool operator <(SemVer other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) => other is SemVer && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, Object.hashAll(preRelease));

  @override
  String toString() => '$major.$minor.$patch${preRelease.isEmpty ? '' : '-${preRelease.join('.')}'}';
}

// ---------------------------------------------------------------------------
// Releases

/// One of a release's files.
final class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url, this.sha256});

  final String name;

  /// Where it downloads from (browser_download_url), which redirects to the
  /// host that serves it.
  final Uri url;

  /// Its SHA-256 in lowercase hex, where GitHub gives it (its digest,
  /// "sha256:…"); null where it doesn't.
  final String? sha256;

  static ReleaseAsset? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final url = Uri.tryParse(json['browser_download_url'] is String ? json['browser_download_url'] as String : '');
    if (name is! String || name.isEmpty || url == null || !url.hasScheme) return null;
    final digest = json['digest'];
    final sha256 =
        digest is String ? RegExp(r'^sha256:([0-9a-fA-F]{64})$').firstMatch(digest)?.group(1)?.toLowerCase() : null;
    return ReleaseAsset(name: name, url: url, sha256: sha256);
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'browser_download_url': '$url',
        if (sha256 != null) 'digest': 'sha256:$sha256',
      };
}

/// A release, as GitHub's releases API lists it.
final class Release {
  const Release({
    required this.tag,
    required this.version,
    this.draft = false,
    this.prerelease = false,
    required this.page,
    this.assets = const [],
  });

  /// Its tag, 'v0.0.2'.
  final String tag;
  final SemVer version;
  final bool draft;

  /// Whether GitHub marks it a pre-release.
  final bool prerelease;

  /// Its page on GitHub, with its notes: What's new.
  final Uri page;
  final List<ReleaseAsset> assets;

  /// The version as its files are named: the tag without its 'v'.
  String get versionName => tag.substring(1);

  /// Whether only the pre-release channel takes it: GitHub marks it so, its
  /// version is a pre-release's, or it is a 0.x release, every one of which
  /// is a pre-release (docs/RELEASE.md).
  bool get isPreview => prerelease || version.isPreRelease || version.major == 0;

  ReleaseAsset? asset(String name) => assets.where((a) => a.name == name).firstOrNull;

  /// Whether it has what installing it needs: a tag install.ps1 takes, the
  /// Windows installer, the script that installs it, and the checksums that
  /// the script is checked against.
  bool get installable =>
      isInstallerTag(tag) &&
      asset(msiAssetName(versionName)) != null &&
      asset(kInstallScriptAsset) != null &&
      asset(kChecksumsAsset) != null;

  /// [json], one release of the API's list, or null where it isn't one the
  /// app can read (no tag, or a tag that is no version).
  static Release? fromJson(Object? json) {
    if (json is! Map) return null;
    final tag = json['tag_name'];
    if (tag is! String || !isSafeTag(tag)) return null;
    final version = SemVer.tryParse(tag);
    if (version == null) return null;
    final html = Uri.tryParse(json['html_url'] is String ? json['html_url'] as String : '');
    return Release(
      tag: tag,
      version: version,
      draft: json['draft'] != false,
      prerelease: json['prerelease'] != false,
      // Only a page on GitHub is opened.
      page: html != null && html.scheme == 'https' && html.host == 'github.com' ? html : kReleasesPage,
      assets: [
        if (json['assets'] case final List assets)
          for (final a in assets) ?ReleaseAsset.fromJson(a),
      ],
    );
  }

  /// As the API has it, so that [fromJson] reads it back.
  Map<String, Object?> toJson() => {
        'tag_name': tag,
        'draft': draft,
        'prerelease': prerelease,
        'html_url': '$page',
        'assets': [for (final a in assets) a.toJson()],
      };
}

/// The releases in [body], the releases API's answer, leaving out any it
/// can't read. Throws an [UpdateException] if [body] is no list of them.
List<Release> parseReleases(String body) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException catch (e) {
    throw UpdateException(UpdateFailure.badResponse, 'The releases are not JSON: ${e.message}');
  }
  if (json is! List) throw const UpdateException(UpdateFailure.badResponse, 'The releases are not a list');
  return [
    for (final r in json) ?Release.fromJson(r),
  ];
}

/// The release to offer in place of [current] on [channel]: the newest
/// published one that can be installed, and newer than [current], never the
/// same or older. Drafts are never offered, nor, but on the pre-release
/// channel, pre-releases ([Release.isPreview]); on [UpdateChannel.none],
/// nothing is.
Release? selectUpdate(Iterable<Release> releases, {required SemVer current, required UpdateChannel channel}) {
  if (channel == UpdateChannel.none) return null;
  Release? best;
  for (final release in releases) {
    if (release.draft || !release.installable) continue;
    if (release.isPreview && channel != UpdateChannel.prerelease) continue;
    if (!(release.version > current)) continue;
    if (best == null || release.version > best.version) best = release;
  }
  return best;
}

// ---------------------------------------------------------------------------
// Checking what is downloaded

/// The checksums in [text], SHA256SUMS.txt, by file name: each line
/// `<64 hex digits>  <name>` (or ` *<name>`, sha256sum's binary mode). Other
/// lines are left out, and so is a name given twice with two checksums.
Map<String, String> parseSha256Sums(String text) {
  final sums = <String, String>{};
  final conflicting = <String>{};
  final line = RegExp(r'^([0-9a-fA-F]{64}) [ *](?:\./)?(.+)$');
  for (final raw in const LineSplitter().convert(text.startsWith('\uFEFF') ? text.substring(1) : text)) {
    final m = line.firstMatch(raw.trimRight());
    if (m == null) continue;
    final name = m[2]!, sum = m[1]!.toLowerCase();
    if (sums[name] case final other? when other != sum) conflicting.add(name);
    sums[name] = sum;
  }
  for (final name in conflicting) {
    sums.remove(name);
  }
  return sums;
}

/// The SHA-256 of [bytes], in lowercase hex.
String sha256Hex(List<int> bytes) => crypto.sha256.convert(bytes).toString();

/// Checks [bytes], the file [name], against [sums] (SHA256SUMS.txt), which
/// must list it, and against [digest], the API's, where there is one.
/// Throws an [UpdateException] on any difference.
void verifyDownload(List<int> bytes, {required String name, required Map<String, String> sums, String? digest}) {
  final expected = sums[name];
  if (expected == null) throw UpdateException(UpdateFailure.checksumMissing, '$name is not in $kChecksumsAsset');
  final actual = sha256Hex(bytes);
  if (actual != expected) {
    throw UpdateException(UpdateFailure.checksumMismatch, '$name has SHA-256 $actual, but $kChecksumsAsset says $expected');
  }
  if (digest != null && actual != digest) {
    throw UpdateException(UpdateFailure.checksumMismatch, '$name has SHA-256 $actual, but GitHub says $digest');
  }
}

// ---------------------------------------------------------------------------
// Fetching

/// Why an update couldn't be looked for or prepared, for the recent errors
/// that support reads.
enum UpdateFailure {
  /// No connection, or one that broke or took too long.
  network,

  /// An answer other than the file: a 404, a 500.
  httpStatus,

  /// GitHub's limit on requests without signing in.
  rateLimited,

  /// A redirect, or a request, to a host the updates don't come from.
  disallowedHost,

  /// More redirects than any download takes.
  tooManyRedirects,

  /// A file larger than any it should be.
  tooLarge,

  /// An answer that can't be read.
  badResponse,

  /// A file missing from SHA256SUMS.txt.
  checksumMissing,

  /// A file whose SHA-256 isn't the one it should have.
  checksumMismatch,

  /// The release lacks a file installing it needs.
  missingAsset,

  /// The running version can't be read, so nothing can be said newer.
  unknownVersion,

  /// The script couldn't be saved or started.
  install,
}

/// What went wrong with an update, in English, for support.
class UpdateException implements Exception {
  const UpdateException(this.failure, this.message, {this.retryAt});

  final UpdateFailure failure;
  final String message;

  /// When GitHub says to ask again, after [UpdateFailure.rateLimited].
  final DateTime? retryAt;

  @override
  String toString() => 'UpdateException(${failure.name}): $message';
}

/// One answer to one request, which no redirect was followed for.
final class UpdateResponse {
  const UpdateResponse(this.status, {this.headers = const {}, this.body = const []});

  final int status;

  /// Its headers, by lowercase name.
  final Map<String, String> headers;
  final List<int> body;
}

/// What sends the updates' requests: one GET for one address, following no
/// redirect, so that [fetchAllowed] can check each hop's host.
abstract interface class UpdateHttp {
  /// [uri] with [headers]. Throws an [UpdateException] for a body larger
  /// than [maxBytes], or for a connection that fails.
  Future<UpdateResponse> get(Uri uri, {required Map<String, String> headers, required int maxBytes});
}

/// The most redirects a download follows: GitHub's take one.
const kMaxUpdateRedirects = 5;

/// The body of [uri], following its redirects (at most
/// [kMaxUpdateRedirects]), each only to one of [kUpdateHosts] over HTTPS.
/// [now] is the clock a rate limit's "ask again at" is read against.
Future<List<int>> fetchAllowed(
  UpdateHttp http,
  Uri uri, {
  required int maxBytes,
  String accept = '*/*',
  required DateTime Function() now,
}) async {
  var current = uri;
  for (var hop = 0;; hop++) {
    if (!isAllowedUpdateUri(current)) {
      throw UpdateException(UpdateFailure.disallowedHost, 'Refused to fetch ${current.scheme}://${current.host}');
    }
    final response = await http.get(
      current,
      headers: {
        'User-Agent': kUpdateUserAgent,
        'Accept': accept,
        // The version of the API whose answers the app reads.
        if (current.host == 'api.github.com') 'X-GitHub-Api-Version': '2022-11-28',
      },
      maxBytes: maxBytes,
    );
    final status = response.status;
    if (status == 200) return response.body;
    if (const {301, 302, 303, 307, 308}.contains(status)) {
      final location = response.headers['location'];
      if (location == null || location.isEmpty) {
        throw UpdateException(UpdateFailure.badResponse, 'A redirect ($status) from ${current.host} to nowhere');
      }
      if (hop >= kMaxUpdateRedirects) {
        throw const UpdateException(UpdateFailure.tooManyRedirects, 'More than $kMaxUpdateRedirects redirects');
      }
      current = current.resolve(location);
      continue;
    }
    if (rateLimitedUntil(response, now: now()) case final retryAt?) {
      throw UpdateException(UpdateFailure.rateLimited, 'GitHub asks to wait ($status)', retryAt: retryAt);
    }
    throw UpdateException(UpdateFailure.httpStatus, 'HTTP $status from ${current.host}${current.path}');
  }
}

/// When to ask again where [response] is GitHub's refusal of too many
/// requests: a 429, or a 403 with no requests left, at the time it gives
/// (Retry-After, or the limit's reset), or in an hour where it gives none;
/// null for any other answer.
DateTime? rateLimitedUntil(UpdateResponse response, {required DateTime now}) {
  final headers = response.headers;
  final limited =
      response.status == 429 || (response.status == 403 && (headers['x-ratelimit-remaining'] == '0' || headers.containsKey('retry-after')));
  if (!limited) return null;
  if (int.tryParse(headers['retry-after'] ?? '') case final seconds? when seconds >= 0) {
    return now.add(Duration(seconds: seconds));
  }
  if (int.tryParse(headers['x-ratelimit-reset'] ?? '') case final epoch?) {
    final reset = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    if (reset.isAfter(now)) return reset;
  }
  return now.add(const Duration(hours: 1));
}

// ---------------------------------------------------------------------------
// When to look

/// How long after a check the next automatic one waits.
const kUpdateCheckInterval = Duration(hours: 12);

/// After [failures] automatic checks have failed in a row, how long the next
/// waits: half an hour after the first, then twice as long each time, but
/// never longer than [kUpdateCheckInterval].
Duration updateRetryDelay(int failures) {
  if (failures <= 0) return kUpdateCheckInterval;
  final minutes = 30 * (1 << (failures - 1).clamp(0, 10));
  return minutes >= kUpdateCheckInterval.inMinutes ? kUpdateCheckInterval : Duration(minutes: minutes);
}

/// What the app keeps of its checks, on this device alone: when it last
/// tried and last managed, how many failed since, when GitHub said to ask
/// again, and the release last found to offer.
final class UpdateRecord {
  const UpdateRecord({this.lastAttempt, this.lastSuccess, this.failures = 0, this.retryAt, this.offer});

  /// Where it is kept, in the app's preferences.
  static const storageKey = 'updates.v1';

  final DateTime? lastAttempt;
  final DateTime? lastSuccess;
  final int failures;
  final DateTime? retryAt;
  final Release? offer;

  /// After a check at [at] that found [offer], or nothing to offer.
  UpdateRecord succeeded(DateTime at, {Release? offer}) => UpdateRecord(lastAttempt: at, lastSuccess: at, offer: offer);

  /// After a check at [at] that failed, GitHub saying to ask again at
  /// [retryAt] where it said so. What was found before is still offered.
  UpdateRecord failed(DateTime at, {DateTime? retryAt}) =>
      UpdateRecord(lastAttempt: at, lastSuccess: lastSuccess, failures: failures + 1, retryAt: retryAt, offer: offer);

  /// When the next automatic check is due: [kUpdateCheckInterval] after the
  /// last, or sooner after a failure ([updateRetryDelay]), but not before
  /// GitHub said to ask again, nor more than a day after the last.
  DateTime? get nextCheck {
    final last = lastAttempt;
    if (last == null) return null;
    var due = last.add(updateRetryDelay(failures));
    final wait = retryAt;
    if (wait != null && wait.isAfter(due)) {
      final latest = last.add(const Duration(days: 1));
      due = wait.isAfter(latest) ? latest : wait;
    }
    return due;
  }

  /// Whether an automatic check is due at [now]: never checked, due, or
  /// last checked "in the future", as a clock set back has it.
  bool isDue(DateTime now) {
    final last = lastAttempt;
    if (last == null || last.isAfter(now)) return true;
    return !now.isBefore(nextCheck!);
  }

  Map<String, Object?> toJson() => {
        if (lastAttempt != null) 'lastAttempt': lastAttempt!.toUtc().toIso8601String(),
        if (lastSuccess != null) 'lastSuccess': lastSuccess!.toUtc().toIso8601String(),
        'failures': failures,
        if (retryAt != null) 'retryAt': retryAt!.toUtc().toIso8601String(),
        if (offer != null) 'offer': offer!.toJson(),
      };

  /// [json] as [toJson] wrote it; whatever can't be read is left out.
  static UpdateRecord fromJson(Object? json) {
    if (json is! Map) return const UpdateRecord();
    DateTime? time(String key) => json[key] is String ? DateTime.tryParse(json[key] as String)?.toLocal() : null;
    final failures = json['failures'];
    return UpdateRecord(
      lastAttempt: time('lastAttempt'),
      lastSuccess: time('lastSuccess'),
      failures: failures is int && failures > 0 ? failures : 0,
      retryAt: time('retryAt'),
      offer: Release.fromJson(json['offer']),
    );
  }
}

// ---------------------------------------------------------------------------
// When to keep quiet

/// Without a city's times, a day of rest lasts until 3 a.m. after it, as
/// Today's does (restDayProvider): minutes after the next midnight.
const _restEndsWithoutCity = 3 * 60;

/// Whether updates keep quiet at [now], on the device's clock: neither
/// looked for nor offered on Shabbat or Yom Tov ([JewishHolidays.isRestDay],
/// by the reader's days of Yom Tov, [israel]), nor on their eve from the
/// reminders' cutoff ([erevCutoffMinutes]). [zmanim] gives the city's
/// candle-lighting and nightfall where a city is chosen: the eve's quiet
/// begins from candle-lighting as the reminders' does, and the last day of
/// rest ends at nightfall. Without them, the eve is quiet from midday, and a
/// day of rest until 3 a.m. after it.
bool updatesQuietAt(DateTime now, {required bool israel, ReminderZmanim Function(LocalDate date)? zmanim}) {
  bool rest(LocalDate d) => JewishHolidays.isRestDay(d, israel: israel);
  final today = LocalDate.fromDateTime(now);
  final minutes = now.hour * 60 + now.minute;
  if (rest(today)) {
    if (rest(today.addDays(1))) return true;
    final havdalah = zmanim?.call(today).havdalah;
    if (havdalah == null || minutes < havdalah) return true;
  } else {
    // The night after the last day of rest, before it has ended.
    final yesterday = today.addDays(-1);
    if (rest(yesterday)) {
      final havdalah = zmanim?.call(yesterday).havdalah;
      if (minutes + 24 * 60 < (havdalah ?? 24 * 60 + _restEndsWithoutCity)) return true;
    }
  }
  if (rest(today.addDays(1)) && minutes >= erevCutoffMinutes(candles: zmanim?.call(today).candles)) return true;
  return false;
}
