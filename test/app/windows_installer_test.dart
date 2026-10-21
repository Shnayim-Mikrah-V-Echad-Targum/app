import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Windows installer of the pre-releases: the per-user MSI built by
/// tool/windows/build_msi.ps1 from tool/windows/msi/ShnayimMikrah.wxs, and
/// tool/windows/install.ps1, which the README's one-liner and the app's
/// updater run. Neither can run here; their facts are pinned instead.
void main() {
  final wxs = File('tool/windows/msi/ShnayimMikrah.wxs').readAsStringSync();
  final build = File('tool/windows/build_msi.ps1').readAsStringSync();
  final install = File('tool/windows/install.ps1').readAsStringSync();
  final notifications = File('lib/services/notifications.dart').readAsStringSync();

  const oneLiner = 'Set-ExecutionPolicy Bypass -Scope Process -Force; irm '
      'https://raw.githubusercontent.com/Shnayim-Mikrah-V-Echad-Targum/app/main/tool/windows/install.ps1 | iex';

  group('the MSI', () {
    test('keeps one UpgradeCode for every release, and installs per user', () {
      expect(wxs, contains('UpgradeCode="{4E6B2C1A-9D3F-4A57-8B21-6F0D3C9E7A15}"'));
      expect(wxs, contains('Scope="perUser"'));
      expect(wxs, contains('<MajorUpgrade'));
      expect(wxs, contains('DowngradeErrorMessage='));
    });

    test('installs into the user’s own Programs folder', () {
      expect(wxs, contains('<StandardDirectory Id="LocalAppDataFolder">'));
      expect(wxs, contains('<Directory Id="LocalProgramsFolder" Name="Programs">'));
      expect(wxs, contains('<Directory Id="InstallFolder" Name="Shnayim Mikrah" />'));
    });

    test('gives its shortcuts the notifications’ app id and toast activator', () {
      final aumid = RegExp(r"appUserModelId: '([^']+)'").firstMatch(notifications)![1]!;
      final guid = RegExp(r"guid: '([0-9a-f-]+)'").firstMatch(notifications)![1]!;
      expect(aumid, 'ShnayimMikrah.App');
      expect(RegExp('System.AppUserModel.ID" Value="$aumid"').allMatches(wxs), hasLength(2));
      expect(RegExp('System.AppUserModel.ToastActivatorCLSID" Value="\\{$guid\\}"').allMatches(wxs), hasLength(2));
      expect(wxs, contains('Software\\Classes\\CLSID\\{$guid}\\LocalServer32'));
    });

    test('is built by build_msi.ps1 into the release’s asset name', () {
      expect(build, contains(r'"ShnayimMikrah-$Version-windows-x64.msi"'));
      expect(build, contains(r"$WixVersion = '5.0.2'"));
      // The Visual C++ runtime goes in with the app.
      for (final dll in ['msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll']) {
        expect(build, contains("'$dll'"));
      }
    });
  });

  group('install.ps1', () {
    test('runs through iex: no parameters, its options in the environment', () {
      expect(RegExp(r'^\s*param\s*\(', multiLine: true).hasMatch(install), isFalse);
      for (final name in ['SM_TAG', 'SM_MSI', 'SM_SHA256', 'SM_WAIT_PID', 'SM_NO_LAUNCH', 'SM_QUIET']) {
        expect(install, contains('\$env:$name'), reason: name);
      }
    });

    test('asks for TLS 1.2 and talks only to GitHub', () {
      expect(install, contains('[Net.SecurityProtocolType]::Tls12'));
      expect(install, contains("\$ApiHosts = @('api.github.com')"));
      expect(install,
          contains("\$DownloadHosts = @('github.com', 'objects.githubusercontent.com', 'release-assets.githubusercontent.com')"));
      final urls = RegExp(r'https://[A-Za-z0-9.-]+').allMatches(install).map((m) => m[0]!).toSet();
      expect(urls, {'https://raw.githubusercontent.com', 'https://api.github.com', 'https://github.com'});
    });

    test('checks the SHA-256 before it installs anything', () {
      final check = install.indexOf("Stop-Install (\"The download doesn't match SHA256SUMS.txt");
      final digest = install.indexOf(r'Assert-Digest $msiPath $found.Msi $actual');
      final installs = install.indexOf(r'Install-Msi $msiPath');
      expect(check, greaterThan(0));
      expect(digest, greaterThan(check));
      expect(installs, greaterThan(digest));
      expect(install, contains(r'"ShnayimMikrah-$version-windows-x64.msi"'));
      expect(install, contains("'SHA256SUMS.txt'"));
    });

    test('never asks for administrator rights', () {
      expect(install, isNot(contains('RunAs')));
      expect(install, contains('/passive'));
      expect(install, contains(r"Join-Path $env:LOCALAPPDATA 'Programs\Shnayim Mikrah'"));
    });
  });

  test('the README gives the one-liner exactly', () {
    expect(File('README.md').readAsStringSync(), contains(oneLiner));
    expect(install, contains(oneLiner));
  });
}
