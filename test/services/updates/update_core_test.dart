import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/core/calendar/jewish_holidays.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/services/reminder_planner.dart' show ReminderZmanim;
import 'package:shnayim_mikrah/services/updates/update_core.dart';
import 'package:shnayim_mikrah/services/updates/update_io.dart';
import 'package:shnayim_mikrah/services/updates/update_service.dart';

import 'update_fixtures.dart';

/// The Windows app's updates without Flutter (lib/services/updates/): which
/// release is offered on which channel, how versions are ordered, how what
/// is downloaded is checked, which hosts may serve it, when the app looks
/// again, and when it keeps quiet.
void main() {
  group('the channel', () {
    test('is the one UPDATE_CHANNEL names, and otherwise none', () {
      expect(UpdateChannel.parse('prerelease'), UpdateChannel.prerelease);
      expect(UpdateChannel.parse(' Stable '), UpdateChannel.stable);
      for (final value in ['', 'none', 'beta', 'pre-release', 'all']) {
        expect(UpdateChannel.parse(value), UpdateChannel.none, reason: value);
      }
    });
  });

  group('versions', () {
    SemVer v(String s) => SemVer.tryParse(s)!;

    test('are read with or without the tag’s v, and their build ignored', () {
      expect(v('0.0.1'), const SemVer(0, 0, 1));
      expect(v('v0.0.2'), const SemVer(0, 0, 2));
      expect(v('0.0.1+1'), const SemVer(0, 0, 1));
      expect(v('1.0.0-rc.1+build.5').preRelease, ['rc', '1']);
      expect(v('1.0.0-rc.1').isPreRelease, isTrue);
      expect(v('1.0.0').isPreRelease, isFalse);
      expect('${v('v1.2.3-beta.11')}', '1.2.3-beta.11');
    });

    test('that are no versions are not read', () {
      for (final text in ['', 'v', '1', '1.0', '01.0.0', '1.0.0-', '1.0.0-01', 'v1.0.0.0', 'latest', '1.0.0-rc..1']) {
        expect(SemVer.tryParse(text), isNull, reason: text);
      }
    });

    test('are ordered as Semantic Versioning orders them, pre-releases before their release', () {
      const ordered = [
        '0.0.1',
        '0.0.2',
        '0.1.0',
        '0.10.0',
        '1.0.0-alpha',
        '1.0.0-alpha.1',
        '1.0.0-alpha.beta',
        '1.0.0-beta',
        '1.0.0-beta.2',
        '1.0.0-beta.11',
        '1.0.0-rc.1',
        '1.0.0',
        '1.0.1',
        '2.0.0',
      ];
      for (var i = 0; i < ordered.length; i++) {
        for (var j = 0; j < ordered.length; j++) {
          expect(v(ordered[i]).compareTo(v(ordered[j])).sign, (i - j).sign, reason: '${ordered[i]} vs ${ordered[j]}');
        }
      }
      expect(v('1.0.0+1'), v('1.0.0+2'));
      expect(v('0.0.2') > v('0.0.1'), isTrue);
      expect(v('0.0.1') < v('0.0.1-rc.1'), isFalse);
    });
  });

  group('tags', () {
    test('that name a folder are a version’s alone', () {
      for (final tag in ['v0.0.1', 'v1.2.3', 'v1.0.0-rc.1']) {
        expect(isSafeTag(tag), isTrue, reason: tag);
      }
      for (final tag in ['0.0.1', 'v0.0.1/../x', r'v0.0.1\..', 'v0.0.1 & calc', 'v0.0.1"', 'v1.0.0-rc_1', 'v0.0.1%x%', '']) {
        expect(isSafeTag(tag), isFalse, reason: tag);
      }
    });

    test('that install.ps1 takes are vX.Y.Z, as its own pattern is', () {
      expect(isInstallerTag('v0.0.1'), isTrue);
      expect(isInstallerTag('v10.20.30'), isTrue);
      for (final tag in ['v1.0.0-rc.1', '0.0.1', 'v01.0.0', 'v0.0.1 ', 'V0.0.1']) {
        expect(isInstallerTag(tag), isFalse, reason: tag);
      }
    });
  });

  group('releases', () {
    test('are read from the API, leaving out what isn’t one', () {
      final releases = parseReleases(jsonEncode([
        releaseJson('v0.0.2', prerelease: true, digests: {'install.ps1': 'a' * 64}),
        {'tag_name': 'nightly'},
        {'tag_name': 'v0.0.3/../x'},
        'not a release',
        releaseJson('v1.0.0'),
      ]));
      expect([for (final r in releases) r.tag], ['v0.0.2', 'v1.0.0']);
      final preview = releases.first;
      expect(preview.prerelease, isTrue);
      expect(preview.draft, isFalse);
      expect(preview.page, Uri.parse('https://github.com/$kUpdateRepository/releases/tag/v0.0.2'));
      expect(preview.asset('install.ps1')!.sha256, 'a' * 64);
      expect(preview.asset('SHA256SUMS.txt')!.sha256, isNull);
      expect(preview.installable, isTrue);
    });

    test('that don’t say they are published are taken for drafts and pre-releases', () {
      final release = Release.fromJson({'tag_name': 'v1.0.0', 'html_url': 'https://github.com/x'})!;
      expect(release.draft, isTrue);
      expect(release.prerelease, isTrue);
    });

    test('open only a page on GitHub for What’s new', () {
      final elsewhere = Release.fromJson({...releaseJson('v0.0.2'), 'html_url': 'https://example.org/notes'})!;
      expect(elsewhere.page, kReleasesPage);
      final http = Release.fromJson({...releaseJson('v0.0.2'), 'html_url': 'http://github.com/notes'})!;
      expect(http.page, kReleasesPage);
      expect(releasePageOf(const SemVer(0, 0, 1)), Uri.parse('https://github.com/$kUpdateRepository/releases/tag/v0.0.1'));
    });

    test('read only a SHA-256 digest', () {
      final asset = ReleaseAsset.fromJson({
        'name': 'install.ps1',
        'browser_download_url': 'https://github.com/x/install.ps1',
        'digest': 'sha512:${'b' * 128}',
      })!;
      expect(asset.sha256, isNull);
      expect(
        ReleaseAsset.fromJson({
          'name': 'install.ps1',
          'browser_download_url': 'https://github.com/x/install.ps1',
          'digest': 'sha256:${'AB' * 32}',
        })!.sha256,
        'ab' * 32,
      );
    });

    test('that aren’t JSON, or no list, are a bad response', () {
      expect(() => parseReleases('<html>'), throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', UpdateFailure.badResponse)));
      expect(() => parseReleases('{"message": "Not Found"}'), throwsA(isA<UpdateException>()));
    });

    test('are installable only with the installer, its script and the checksums, under a tag install.ps1 takes', () {
      expect(Release.fromJson(releaseJson('v0.0.2'))!.installable, isTrue);
      for (final missing in ['ShnayimMikrah-0.0.2-windows-x64.msi', 'install.ps1', 'SHA256SUMS.txt']) {
        final assets = [...releaseAssets('0.0.2')]..remove(missing);
        expect(Release.fromJson(releaseJson('v0.0.2', assets: assets))!.installable, isFalse, reason: missing);
      }
      // Another version's installer is not this one's.
      expect(
        Release.fromJson(releaseJson('v0.0.2', assets: ['ShnayimMikrah-0.0.1-windows-x64.msi', 'install.ps1', 'SHA256SUMS.txt']))!
            .installable,
        isFalse,
      );
      expect(Release.fromJson(releaseJson('v1.0.0-rc.1', assets: releaseAssets('1.0.0-rc.1')))!.installable, isFalse);
    });
  });

  group('the release offered', () {
    final releases = parseReleases(jsonEncode([
      releaseJson('v0.0.3', draft: true),
      releaseJson('v0.0.2', prerelease: true),
      releaseJson('v1.1.0', draft: true),
      releaseJson('v1.0.1', prerelease: true),
      releaseJson('v1.0.0'),
      releaseJson('v1.2.0-rc.1', prerelease: true, assets: releaseAssets('1.2.0-rc.1')),
      releaseJson('v0.0.1', prerelease: true),
    ]));
    Release? offered(String current, UpdateChannel channel, [List<Release>? among]) =>
        selectUpdate(among ?? releases, current: SemVer.tryParse(current)!, channel: channel);

    test('is none on the channel none', () {
      expect(offered('0.0.1', UpdateChannel.none), isNull);
    });

    test('on the pre-release channel is the newest published, pre-releases too, never a draft', () {
      expect(offered('0.0.1', UpdateChannel.prerelease)?.tag, 'v1.0.1');
      expect(offered('1.0.1', UpdateChannel.prerelease), isNull);
    });

    test('on the stable channel is never a pre-release, nor a 0.x release', () {
      expect(offered('0.0.1', UpdateChannel.stable)?.tag, 'v1.0.0');
      expect(offered('1.0.0', UpdateChannel.stable), isNull);
      final unmarked = parseReleases(jsonEncode([releaseJson('v0.0.9')]));
      expect(offered('0.0.1', UpdateChannel.stable, unmarked), isNull, reason: 'every 0.x release is a preview');
      expect(offered('0.0.1', UpdateChannel.prerelease, unmarked)?.tag, 'v0.0.9');
    });

    test('is never the version running, nor an older one', () {
      expect(offered('2.0.0', UpdateChannel.prerelease), isNull);
      expect(offered('1.0.1', UpdateChannel.stable), isNull);
      // A pre-release of a version is older than the version.
      final only = parseReleases(jsonEncode([releaseJson('v0.0.2', prerelease: true)]));
      expect(offered('0.0.2-rc.1', UpdateChannel.prerelease, only)?.tag, 'v0.0.2');
      expect(offered('0.0.2', UpdateChannel.prerelease, only), isNull);
      expect(offered('0.0.2+7', UpdateChannel.prerelease, only), isNull);
    });

    test('is the newest whatever order the list is in, and never one that can’t be installed', () {
      expect(offered('0.0.1', UpdateChannel.prerelease, releases.reversed.toList())?.tag, 'v1.0.1');
      final incomplete = parseReleases(jsonEncode([
        releaseJson('v0.0.3', prerelease: true, assets: ['ShnayimMikrah-0.0.3-windows-x64.msi', 'SHA256SUMS.txt']),
        releaseJson('v0.0.2', prerelease: true),
      ]));
      expect(offered('0.0.1', UpdateChannel.prerelease, incomplete)?.tag, 'v0.0.2');
    });
  });

  group('SHA256SUMS.txt', () {
    final a = 'a' * 64, b = 'b' * 64, c = 'c' * 64;

    test('is read as sha256sum writes it', () {
      expect(parseSha256Sums('$a  install.ps1\n$b  ShnayimMikrah-0.0.2-windows-x64.msi\n'), {
        'install.ps1': a,
        'ShnayimMikrah-0.0.2-windows-x64.msi': b,
      });
    });

    test('in binary mode, from another folder, with Windows line ends, a byte-order mark and capitals', () {
      expect(parseSha256Sums('\uFEFF${a.toUpperCase()} *install.ps1\r\n$b  ./SHA256SUMS.sig\r\n'), {
        'install.ps1': a,
        'SHA256SUMS.sig': b,
      });
    });

    test('leaves out what isn’t a checksum, and a name given two', () {
      expect(
        parseSha256Sums('# checksums\n${'a' * 63}  short\n$a install.ps1\n$c\n$a  twice\n$b  twice\n$c  once\n$c  once\n'),
        {'once': c},
      );
    });
  });

  group('a download', () {
    final script = utf8.encode('Write-Host "hello"');
    final sum = sha256Hex(script);

    test('passes when its SHA-256 is the one listed, and GitHub’s where it gives one', () {
      expect(sum, hasLength(64));
      verifyDownload(script, name: 'install.ps1', sums: {'install.ps1': sum});
      verifyDownload(script, name: 'install.ps1', sums: {'install.ps1': sum}, digest: sum);
    });

    Matcher fails(UpdateFailure failure) => throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', failure));

    test('fails when it isn’t listed, or isn’t what either says', () {
      expect(() => verifyDownload(script, name: 'install.ps1', sums: const {}), fails(UpdateFailure.checksumMissing));
      expect(
        () => verifyDownload(script, name: 'install.ps1', sums: {'install.ps1': 'f' * 64}),
        fails(UpdateFailure.checksumMismatch),
      );
      expect(
        () => verifyDownload(script, name: 'install.ps1', sums: {'install.ps1': sum}, digest: 'f' * 64),
        fails(UpdateFailure.checksumMismatch),
      );
    });
  });

  group('hosts', () {
    test('are GitHub’s alone, over HTTPS on its own port, with no one’s name in the address', () {
      for (final url in [
        'https://api.github.com/repos/x/releases',
        'https://github.com/x/releases/download/v0.0.2/install.ps1',
        'https://objects.githubusercontent.com/github-production-release-asset/1',
        'https://release-assets.githubusercontent.com/github-production-release-asset/1',
        'https://GitHub.com/x',
        'https://github.com:443/x',
      ]) {
        expect(isAllowedUpdateUri(Uri.parse(url)), isTrue, reason: url);
      }
      for (final url in [
        'http://github.com/x',
        'https://example.org/install.ps1',
        'https://github.com.example.org/x',
        'https://raw.githubusercontent.com/x/install.ps1',
        'https://github.com:8443/x',
        'https://user:secret@github.com/x',
        'file:///C:/install.ps1',
      ]) {
        expect(isAllowedUpdateUri(Uri.parse(url)), isFalse, reason: url);
      }
    });
  });

  group('fetching', () {
    final now = DateTime.utc(2026, 10, 21, 12);
    final start = Uri.parse('https://github.com/$kUpdateRepository/releases/download/v0.0.2/install.ps1');
    final asset = Uri.parse('https://release-assets.githubusercontent.com/github-production-release-asset/9?sig=1');

    test('follows GitHub’s redirects, each to a host on the list', () async {
      final http = FakeUpdateHttp({
        start: redirect(asset.toString()),
        asset: UpdateResponse(200, body: utf8.encode('script')),
      });
      expect(utf8.decode(await fetchAllowed(http, start, maxBytes: 100, now: () => now)), 'script');
      expect(http.requested, [start, asset]);
      // Saying who asks, and the API's version only to the API.
      expect(http.headers.first['User-Agent'], kUpdateUserAgent);
      expect(http.headers.first.containsKey('X-GitHub-Api-Version'), isFalse);
    });

    test('follows a redirect to a path on the same host', () async {
      final moved = Uri.parse('https://github.com/$kUpdateRepository/releases/download/v0.0.2/moved.ps1');
      final http = FakeUpdateHttp({start: redirect('/$kUpdateRepository/releases/download/v0.0.2/moved.ps1'), moved: const UpdateResponse(200)});
      await fetchAllowed(http, start, maxBytes: 100, now: () => now);
      expect(http.requested, [start, moved]);
    });

    Matcher fails(UpdateFailure failure) => throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', failure));

    test('never follows a redirect off the list, nor to plain HTTP, nor asks there', () async {
      for (final to in ['https://example.org/install.ps1', 'http://objects.githubusercontent.com/x', 'https://github.com.evil.example/x']) {
        final http = FakeUpdateHttp({start: redirect(to)});
        await expectLater(fetchAllowed(http, start, maxBytes: 100, now: () => now), fails(UpdateFailure.disallowedHost));
        expect(http.requested, [start], reason: to);
      }
    });

    test('never asks a host off the list in the first place', () async {
      final http = FakeUpdateHttp(const {});
      await expectLater(
        fetchAllowed(http, Uri.parse('https://example.org/releases'), maxBytes: 100, now: () => now),
        fails(UpdateFailure.disallowedHost),
      );
      expect(http.requested, isEmpty);
    });

    test('gives up after a few redirects, and on one to nowhere', () async {
      final loop = FakeUpdateHttp({start: redirect(start.toString())});
      await expectLater(fetchAllowed(loop, start, maxBytes: 100, now: () => now), fails(UpdateFailure.tooManyRedirects));
      expect(loop.requested, hasLength(kMaxUpdateRedirects + 1));
      final nowhere = FakeUpdateHttp({start: const UpdateResponse(302)});
      await expectLater(fetchAllowed(nowhere, start, maxBytes: 100, now: () => now), fails(UpdateFailure.badResponse));
    });

    test('tells GitHub’s limit apart from another refusal, and when to ask again', () async {
      final reset = now.add(const Duration(minutes: 40));
      final limited = FakeUpdateHttp({
        kReleasesApi: UpdateResponse(403, headers: {
          'x-ratelimit-remaining': '0',
          'x-ratelimit-reset': '${reset.millisecondsSinceEpoch ~/ 1000}',
        }),
      });
      await expectLater(
        fetchAllowed(limited, kReleasesApi, maxBytes: 100, now: () => now),
        throwsA(isA<UpdateException>()
            .having((e) => e.failure, 'failure', UpdateFailure.rateLimited)
            .having((e) => e.retryAt?.millisecondsSinceEpoch, 'retryAt', reset.millisecondsSinceEpoch)),
      );
      expect(limited.headers.single['X-GitHub-Api-Version'], '2022-11-28');
      expect(
        rateLimitedUntil(const UpdateResponse(429, headers: {'retry-after': '120'}), now: now),
        now.add(const Duration(minutes: 2)),
      );
      expect(rateLimitedUntil(const UpdateResponse(429), now: now), now.add(const Duration(hours: 1)));
      expect(rateLimitedUntil(const UpdateResponse(403), now: now), isNull, reason: 'forbidden, not limited');
      final missing = FakeUpdateHttp({kReleasesApi: const UpdateResponse(404)});
      await expectLater(fetchAllowed(missing, kReleasesApi, maxBytes: 100, now: () => now), fails(UpdateFailure.httpStatus));
    });
  });

  group('the service', () {
    final now = DateTime.utc(2026, 10, 21, 12);
    final script = utf8.encode('# install.ps1 of v0.0.2\n');
    final msiSum = 'd' * 64;
    String sums({String? scriptSum, bool msi = true}) =>
        '${scriptSum ?? sha256Hex(script)}  install.ps1\n${msi ? '$msiSum  ShnayimMikrah-0.0.2-windows-x64.msi\n' : ''}';
    Release release({Map<String, String> digests = const {}}) =>
        Release.fromJson(releaseJson('v0.0.2', prerelease: true, digests: digests))!;

    /// GitHub, serving v0.0.2's files by way of a redirect each.
    FakeUpdateHttp github({String? sumsText, List<int>? scriptBytes}) {
      final sumsBytes = utf8.encode(sumsText ?? sums());
      return FakeUpdateHttp({
        kReleasesApi: UpdateResponse(200, body: utf8.encode(jsonEncode([releaseJson('v0.0.2', prerelease: true)]))),
        assetUrl('v0.0.2', 'SHA256SUMS.txt'): redirect('https://release-assets.githubusercontent.com/sums'),
        Uri.parse('https://release-assets.githubusercontent.com/sums'): UpdateResponse(200, body: sumsBytes),
        assetUrl('v0.0.2', 'install.ps1'): redirect('https://release-assets.githubusercontent.com/script'),
        Uri.parse('https://release-assets.githubusercontent.com/script'): UpdateResponse(200, body: scriptBytes ?? script),
      });
    }

    test('asks GitHub for the releases alone, and offers the one to install', () async {
      final http = github();
      final service = UpdateService(http: http, installer: FakeInstaller(), channel: UpdateChannel.prerelease, now: () => now);
      expect((await service.check(current: const SemVer(0, 0, 1)))?.tag, 'v0.0.2');
      expect(http.requested, [kReleasesApi]);
      expect(http.headers.single['Accept'], 'application/vnd.github+json');
      expect(await service.check(current: const SemVer(0, 0, 2)), isNull);
    });

    test('asks nothing on the channel none', () async {
      final http = github();
      final service = UpdateService(http: http, installer: FakeInstaller(), channel: UpdateChannel.none, now: () => now);
      expect(await service.check(current: const SemVer(0, 0, 1)), isNull);
      expect(http.requested, isEmpty);
    });

    test('installs only a script whose SHA-256 is the one listed, and GitHub’s', () async {
      final installer = FakeInstaller();
      final http = github();
      final service = UpdateService(http: http, installer: installer, channel: UpdateChannel.prerelease, now: () => now);
      await service.install(release(digests: {'install.ps1': sha256Hex(script), 'SHA256SUMS.txt': sha256Hex(utf8.encode(sums()))}));
      expect(installer.started, [('v0.0.2', script)]);
      // The checksums first, then the script they check.
      expect(http.requested.map((u) => u.path.split('/').last), ['SHA256SUMS.txt', 'sums', 'install.ps1', 'script']);
    });

    Future<void> refused(FakeUpdateHttp http, Release release, UpdateFailure failure) async {
      final installer = FakeInstaller();
      final service = UpdateService(http: http, installer: installer, channel: UpdateChannel.prerelease, now: () => now);
      await expectLater(service.install(release), throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', failure)));
      expect(installer.started, isEmpty, reason: 'nothing is run');
    }

    test('starts nothing when the script isn’t the one listed', () async {
      await refused(github(scriptBytes: utf8.encode('Remove-Item -Recurse C:\\')), release(), UpdateFailure.checksumMismatch);
      await refused(github(sumsText: sums(scriptSum: 'e' * 64)), release(), UpdateFailure.checksumMismatch);
      await refused(github(sumsText: '$msiSum  ShnayimMikrah-0.0.2-windows-x64.msi\n'), release(), UpdateFailure.checksumMissing);
    });

    test('starts nothing when GitHub’s digests say otherwise', () async {
      await refused(github(), release(digests: {'install.ps1': 'e' * 64}), UpdateFailure.checksumMismatch);
      await refused(github(), release(digests: {'SHA256SUMS.txt': 'e' * 64}), UpdateFailure.checksumMismatch);
    });

    test('starts nothing for a release whose checksums don’t list its installer', () async {
      await refused(github(sumsText: sums(msi: false)), release(), UpdateFailure.checksumMissing);
    });

    test('starts nothing when a download is sent off GitHub', () async {
      final http = github()..responses[assetUrl('v0.0.2', 'install.ps1')] = redirect('https://example.org/install.ps1');
      await refused(http, release(), UpdateFailure.disallowedHost);
      expect(http.requested.where((u) => u.host == 'example.org'), isEmpty);
    });

    test('starts nothing for a release that lacks a file, or whose tag install.ps1 won’t take', () async {
      final noScript = Release.fromJson(releaseJson('v0.0.2', assets: ['ShnayimMikrah-0.0.2-windows-x64.msi', 'SHA256SUMS.txt']))!;
      await refused(github(), noScript, UpdateFailure.missingAsset);
      final candidate = Release.fromJson(releaseJson('v0.0.2-rc.1', assets: releaseAssets('0.0.2-rc.1')))!;
      await refused(github(), candidate, UpdateFailure.badResponse);
    });
  });

  group('when to look', () {
    final at = DateTime(2026, 10, 21, 9);

    test('backs off after failures, from half an hour to 12 hours', () {
      expect(updateRetryDelay(0), kUpdateCheckInterval);
      expect(updateRetryDelay(1), const Duration(minutes: 30));
      expect(updateRetryDelay(2), const Duration(hours: 1));
      expect(updateRetryDelay(3), const Duration(hours: 2));
      expect(updateRetryDelay(5), const Duration(hours: 8));
      expect(updateRetryDelay(6), kUpdateCheckInterval);
      expect(updateRetryDelay(60), kUpdateCheckInterval);
    });

    test('is at most once every 12 hours, and at once when never checked', () {
      expect(const UpdateRecord().isDue(at), isTrue);
      final checked = const UpdateRecord().succeeded(at);
      expect(checked.nextCheck, at.add(const Duration(hours: 12)));
      expect(checked.isDue(at.add(const Duration(hours: 11, minutes: 59))), isFalse);
      expect(checked.isDue(at.add(const Duration(hours: 12))), isTrue);
      // A clock set back looks again.
      expect(checked.isDue(at.subtract(const Duration(hours: 1))), isTrue);
    });

    test('is sooner after a failure, but never before GitHub says, nor more than a day on', () {
      final failed = const UpdateRecord().succeeded(at.subtract(const Duration(days: 1))).failed(at);
      expect(failed.failures, 1);
      expect(failed.lastSuccess, at.subtract(const Duration(days: 1)));
      expect(failed.nextCheck, at.add(const Duration(minutes: 30)));
      final twice = failed.failed(at.add(const Duration(minutes: 30)));
      expect(twice.nextCheck, at.add(const Duration(minutes: 90)));
      final limited = const UpdateRecord().failed(at, retryAt: at.add(const Duration(hours: 3)));
      expect(limited.nextCheck, at.add(const Duration(hours: 3)));
      final far = const UpdateRecord().failed(at, retryAt: at.add(const Duration(days: 9)));
      expect(far.nextCheck, at.add(const Duration(days: 1)));
      // A success starts again.
      expect(twice.succeeded(at.add(const Duration(hours: 2))).failures, 0);
    });

    test('is kept on the device, with the offer, and read back as written', () {
      final offer = Release.fromJson(releaseJson('v0.0.2', prerelease: true, digests: {'install.ps1': 'a' * 64}))!;
      final record = const UpdateRecord().succeeded(at, offer: offer).failed(at.add(const Duration(hours: 13)), retryAt: at.add(const Duration(hours: 14)));
      final back = UpdateRecord.fromJson(jsonDecode(jsonEncode(record.toJson())));
      expect(back.lastAttempt, record.lastAttempt);
      expect(back.lastSuccess, at);
      expect(back.failures, 1);
      expect(back.retryAt, record.retryAt);
      expect(back.offer?.tag, 'v0.0.2');
      expect(back.offer?.prerelease, isTrue);
      expect(back.offer?.installable, isTrue);
      expect(back.offer?.asset('install.ps1')?.sha256, 'a' * 64);
      expect(UpdateRecord.fromJson('garbage').lastAttempt, isNull);
      expect(UpdateRecord.fromJson({'failures': -3, 'lastAttempt': 7}).failures, 0);
    });
  });

  group('the quiet hours', () {
    // Friday 23 October 2026 and its Shabbat; Rosh Hashanah 5789 on
    // Thursday and Friday 21 and 22 September 2028, then Shabbat; Shavuot
    // 5789 on Sunday 20 May 2029, and Monday 21 May outside Israel.
    bool quiet(DateTime now, {bool israel = false, ReminderZmanimFor? zmanim}) =>
        updatesQuietAt(now, israel: israel, zmanim: zmanim);

    test('the days chosen are what they are said to be', () {
      expect(JewishHolidays.isRestDay(LocalDate(2026, 10, 24), israel: false), isTrue);
      expect(JewishHolidays.isRestDay(LocalDate(2026, 10, 23), israel: false), isFalse);
      for (final day in [21, 22, 23]) {
        expect(JewishHolidays.isRestDay(LocalDate(2028, 9, day), israel: false), isTrue, reason: '$day');
      }
      expect(JewishHolidays.isRestDay(LocalDate(2028, 9, 20), israel: false), isFalse);
      expect(JewishHolidays.isRestDay(LocalDate(2029, 5, 21), israel: false), isTrue);
      expect(JewishHolidays.isRestDay(LocalDate(2029, 5, 21), israel: true), isFalse);
    });

    test('are all of Shabbat and Yom Tov', () {
      expect(quiet(DateTime(2026, 10, 24, 0, 30)), isTrue);
      expect(quiet(DateTime(2026, 10, 24, 12)), isTrue);
      expect(quiet(DateTime(2028, 9, 21, 10)), isTrue);
      expect(quiet(DateTime(2028, 9, 22, 23)), isTrue);
      expect(quiet(DateTime(2029, 5, 21, 12)), isTrue);
    });

    test('keep to the reader’s days of Yom Tov', () {
      expect(quiet(DateTime(2029, 5, 21, 12), israel: true), isFalse);
      expect(quiet(DateTime(2029, 5, 20, 12), israel: true), isTrue);
    });

    test('begin on the eve at midday without a city, as the reminders’ cutoff does', () {
      expect(quiet(DateTime(2026, 10, 23, 9)), isFalse);
      expect(quiet(DateTime(2026, 10, 23, 11, 59)), isFalse);
      expect(quiet(DateTime(2026, 10, 23, 12)), isTrue);
      expect(quiet(DateTime(2028, 9, 20, 11)), isFalse);
      expect(quiet(DateTime(2028, 9, 20, 13)), isTrue);
      // Any other weekday is no eve.
      expect(quiet(DateTime(2026, 10, 22, 20)), isFalse);
    });

    test('begin on the eve two hours before candle-lighting in the reader’s city, as the reminders’ cutoff does', () {
      // Candles at 17:45; Shabbat out at 18:50.
      ReminderZmanim city(LocalDate d) => (candles: 17 * 60 + 45, havdalah: 18 * 60 + 50);
      expect(quiet(DateTime(2026, 10, 23, 15, 44), zmanim: city), isFalse);
      expect(quiet(DateTime(2026, 10, 23, 15, 45), zmanim: city), isTrue);
      // Where the city's candle-lighting can't be given, from midday.
      ReminderZmanim unknown(LocalDate d) => (candles: null, havdalah: null);
      expect(quiet(DateTime(2026, 10, 23, 12), zmanim: unknown), isTrue);
    });

    test('end at nightfall in the reader’s city, and without one at 3 a.m. after the day of rest', () {
      ReminderZmanim city(LocalDate d) => (candles: 17 * 60 + 45, havdalah: 18 * 60 + 50);
      expect(quiet(DateTime(2026, 10, 24, 18, 49), zmanim: city), isTrue);
      expect(quiet(DateTime(2026, 10, 24, 18, 50), zmanim: city), isFalse);
      expect(quiet(DateTime(2026, 10, 24, 23)), isTrue);
      expect(quiet(DateTime(2026, 10, 25, 2, 59)), isTrue);
      expect(quiet(DateTime(2026, 10, 25, 3)), isFalse);
      // Nightfall after midnight, as in a northern summer.
      ReminderZmanim late(LocalDate d) => (candles: 21 * 60, havdalah: 24 * 60 + 40);
      expect(quiet(DateTime(2026, 10, 25, 0, 39), zmanim: late), isTrue);
      expect(quiet(DateTime(2026, 10, 25, 0, 40), zmanim: late), isFalse);
      // Yom Tov running on into Shabbat stays quiet through both.
      expect(quiet(DateTime(2028, 9, 22, 20), zmanim: city), isTrue);
      expect(quiet(DateTime(2028, 9, 23, 18, 50), zmanim: city), isFalse);
    });
  });

  group('the handoff to install.ps1', () {
    test('runs Windows PowerShell on the script, with no profile and whatever the execution policy', () {
      expect(WindowsUpdateInstaller.powershellArguments, ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 'install.ps1']);
      final (executable, arguments) = WindowsUpdateInstaller.command(environment: {'SystemRoot': r'C:\Windows'});
      expect(executable, r'C:\Windows\System32\cmd.exe');
      expect(arguments, [
        '/d',
        '/v:off',
        '/c',
        'start',
        'Shnayim Mikrah',
        r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        'install.ps1',
      ]);
    });

    test('passes the release and the app’s process in the environment, never in the command', () {
      expect(WindowsUpdateInstaller.scriptEnvironment('v0.0.2', 4242), {'SM_TAG': 'v0.0.2', 'SM_WAIT_PID': '4242'});
      final (_, arguments) = WindowsUpdateInstaller.command(
        environment: {'SystemRoot': r'C:\Windows', 'LOCALAPPDATA': r'C:\Users\100% & Co\AppData\Local'},
      );
      expect(arguments.join(' '), isNot(contains('v0.0.2')));
      expect(arguments.join(' '), isNot(contains('AppData')));
      expect(WindowsUpdateInstaller.folderFor(r'C:\Users\r\AppData\Local', 'v0.0.2'),
          r'C:\Users\r\AppData\Local\Shnayim Mikrah\updates\v0.0.2');
    });

    test('finds Windows by SystemRoot, and believes no other', () {
      expect(WindowsUpdateInstaller.systemRoot({'SystemRoot': r'D:\WINDOWS\'}), r'D:\WINDOWS');
      expect(WindowsUpdateInstaller.systemRoot({'windir': r'C:\Windows'}), r'C:\Windows');
      expect(WindowsUpdateInstaller.systemRoot({'SystemRoot': r'C:\Windows" & calc & "'}), r'C:\Windows');
      expect(WindowsUpdateInstaller.systemRoot({'SystemRoot': r'\\server\share'}), r'C:\Windows');
      expect(WindowsUpdateInstaller.systemRoot(const {}), r'C:\Windows');
    });
  });
}
