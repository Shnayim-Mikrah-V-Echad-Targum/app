import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'native_source.dart';

/// The Windows MSIX installer: msix_config in pubspec.yaml, and the icons
/// under windows/msix that tool/branding/make_icon.py --post writes and
/// tool/windows/make_msix.sh packages.
void main() {
  final config = (loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap)['msix_config'] as YamlMap;

  test('the package has the app id of the other platforms', () {
    expect(config['identity_name'], 'org.shnayimmikrah.app');
    expect(File('android/app/build.gradle.kts').readAsStringSync(), contains('applicationId = "org.shnayimmikrah.app"'));
    expect(File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(),
        contains('PRODUCT_BUNDLE_IDENTIFIER = org.shnayimmikrah.app;'));
  });

  // As on Android (values-iw) and iOS (he.lproj), Windows names the app in
  // its own language: Start, the taskbar, Settings and notifications.
  test('the package names the app in English and Hebrew', () {
    expect(config['display_name'], 'ms-resource:AppName');
    expect((config['toast_activator'] as YamlMap)['display_name'], 'ms-resource:AppName');
    String name(String language) {
      final resw = File('windows/msix/Strings/$language/Resources.resw').readAsStringSync();
      return RegExp(r'<data name="AppName" xml:space="preserve">\s*<value>([^<]+)</value>').firstMatch(resw)![1]!;
    }

    expect(name('en-us'), 'Shnayim Mikrah');
    expect(name('he-il'), 'שניים מקרא');
    expect(File('android/app/src/main/res/values-iw/strings.xml').readAsStringSync(),
        contains('<string name="app_name">${name('he-il')}</string>'));
    // One folder for each of the package's languages.
    final folders = Directory('windows/msix/Strings').listSync().map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last);
    expect(folders.toSet(), (config['languages'] as String).split(', ').toSet());
    // make_msix.sh puts them in the build and indexes them into one resources.pri.
    final script = File('tool/windows/make_msix.sh').readAsStringSync();
    expect(script, contains('cp -R windows/msix/Strings "\$release/Strings"'));
    expect(script, contains('/cf "\$(win windows/msix/priconfig.xml)"'));
    expect(File('windows/msix/priconfig.xml').readAsStringSync(), isNot(contains('<packaging>')));
  });

  // Without it, a reminder's notification can't reach the running app.
  test("the toast activator is the notification plugin's class", () {
    final clsid = (config['toast_activator'] as YamlMap)['clsid'] as String;
    expect(File('lib/services/notifications.dart').readAsStringSync(), contains("guid: '$clsid',"));
    // And the class the runner says how to start, run from the folder.
    expect(File('windows/runner/main.cpp').readAsStringSync(),
        contains('L"Software\\\\Classes\\\\CLSID\\\\{$clsid}"\n    L"\\\\LocalServer32"'));
  });

  // The notification plugin registers its class only while the app runs:
  // run from the folder, with no installer to say how to start the app for
  // it, a click on a reminder that came once the app had closed would do
  // nothing. The MSIX says so in its manifest (com:ExeServer).
  test('run from the folder, a click on a reminder starts the app', () {
    final main = File('windows/runner/main.cpp').readAsStringSync();
    expect(main, contains('#include <appmodel.h>'));
    final register = cppBody(main, 'void RegisterToastActivatorServer()');
    // Only unpackaged: the MSIX's own registration stays its own.
    expect(register, contains('if (::GetCurrentPackageFullName(&length, nullptr) !=\n      APPMODEL_ERROR_NO_PACKAGE) {\n    return;\n  }'));
    // The executable where it is now, quoted for a path with spaces, as the
    // key's default value, for this user alone.
    expect(register, contains('::GetModuleFileNameW(nullptr, path, MAX_PATH)'));
    expect(register, contains(r'L"\"" + std::wstring(path, path_length) + L"\""'));
    expect(register, contains('::RegCreateKeyExW(HKEY_CURRENT_USER, kToastActivatorServerKey, 0,'));
    expect(register, contains('::RegSetValueExW(key, nullptr, 0, REG_SZ,'));
    expect(register, contains('static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t))'));
    expect(register, contains('::RegCloseKey(key);'));
    // On every start, since the folder can move; by the instance that runs,
    // not by a second launch that is about to exit.
    final winMain = cppBody(main, 'int APIENTRY wWinMain(');
    expect(winMain.indexOf('RegisterToastActivatorServer();'),
        greaterThan(winMain.indexOf('::WaitForSingleObject(instance_mutex, kInstanceWaitMs)')));
    expect(winMain.indexOf('RegisterToastActivatorServer();'), lessThan(winMain.indexOf('window.Create(')));
  });

  test('it packages the release build as it is, without asking anything', () {
    // A build of its own would lack the release dart-defines.
    expect(config['build_windows'], isFalse);
    // Asking to install the test certificate would hang CI.
    expect(config['install_certificate'], isFalse);
    expect(config['capabilities'], 'internetClient');
    expect(config['languages'], 'en-us, he-il');
  });

  // Task Manager shows the executable's description, and Windows the
  // package's, so both are typeset as the app's own text is.
  test('the executable and the package describe the app with a typeset apostrophe', () {
    final rc = File('windows/runner/Runner.rc').readAsStringSync();
    // Under this pragma alone, rc.exe reads the script's ’ as UTF-8.
    expect(rc, contains('#pragma code_page(65001)'));
    expect(rc, contains('VALUE "FileDescription", "Shnayim Mikrah v’Echad Targum" "\\0"'));
    // msix_config sets none, so the package takes the pubspec's.
    expect(config['description'], isNull);
    final description = (loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap)['description'] as String;
    expect(description, startsWith('Shnayim Mikrah v’Echad Targum — '));
    expect(description, isNot(contains("'")));
  });

  // path_provider_windows keeps the app's support directory, and with it
  // shared_preferences' file (settings, progress, notes), at
  // %APPDATA%\<CompanyName>\<ProductName>: changing either after publishing
  // would leave every reader's local data behind.
  test('the data folder keeps the names it was published under', () {
    final rc = File('windows/runner/Runner.rc').readAsStringSync();
    expect(rc, contains('VALUE "CompanyName", "Shnayim Mikrah" "\\0"'));
    expect(rc, contains('VALUE "ProductName", "Shnayim Mikrah" "\\0"'));
  });

  // A PC without the Visual C++ Redistributable (a fresh Windows) refuses to
  // start an executable whose runtime is missing ("MSVCP140.dll was not
  // found"). The MSIX brings its own; the build's folder, run as it is, needs
  // the runtime beside the executable.
  test('the build carries the Visual C++ runtime beside the executable', () {
    final cmake = File('windows/CMakeLists.txt').readAsStringSync();
    expect(cmake, contains('set(CMAKE_INSTALL_SYSTEM_RUNTIME_DESTINATION "\${INSTALL_BUNDLE_LIB_DIR}")'));
    expect(cmake, contains('set(CMAKE_INSTALL_SYSTEM_RUNTIME_COMPONENT Runtime)'));
    // Read when included, so after the settings.
    expect(cmake.indexOf('include(InstallRequiredSystemLibraries)'),
        greaterThan(cmake.indexOf('CMAKE_INSTALL_SYSTEM_RUNTIME_COMPONENT')));
    // And CI checks the folder it uploads has it.
    final ci = File('.github/workflows/ci.yml').readAsStringSync();
    final check = ci.indexOf('for dll in msvcp140.dll vcruntime140.dll vcruntime140_1.dll; do');
    expect(check, greaterThan(ci.indexOf('flutter build windows --release')));
    expect(check, lessThan(ci.indexOf('name: windows\n')));
  });

  // The msix tool swaps its own copy of the runtime into the folder to pack
  // it, and deletes that once it has (its Assets.cleanTemporaryFiles), even
  // should signing then fail. make_msix.sh runs here with stand-ins for the
  // msix tool and MakePri that do the same to the folder.
  group('packaging leaves the Visual C++ runtime in the folder', () {
    test('when it succeeds', () async {
      final sandbox = _MsixSandbox();
      final result = await sandbox.run();
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(sandbox.package.existsSync(), isTrue);
      expect(sandbox.folderDlls(), _MsixSandbox.builtDlls);
    });

    test('when signing fails after the msix tool has deleted it', () async {
      final sandbox = _MsixSandbox();
      final result = await sandbox.run(failSigning: true);
      expect(result.exitCode, isNot(0));
      expect(sandbox.folderDlls(), _MsixSandbox.builtDlls);
    });

    test('when it stops before packing, with the msix tool’s copy in place', () async {
      final sandbox = _MsixSandbox();
      final result = await sandbox.run(noHebrewName: true);
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('resources.pri has no Hebrew name'));
      expect(sandbox.package.existsSync(), isFalse);
      expect(sandbox.folderDlls(), _MsixSandbox.builtDlls);
    });
  }, skip: Platform.isWindows ? 'runs make_msix.sh in a POSIX shell, as CI does' : false);

  testWidgets('the logo is the rounded tile of app_icon.ico', (tester) async {
    expect(config['logo_path'], 'windows/msix/logo.png');
    final logo = await _pixels(tester, 'windows/msix/logo.png');
    // As large as the largest icon the msix tool makes from it.
    expect((logo.width, logo.height), (1240, 1240));
    expect(logo.at(0, 0).alpha, 0, reason: 'a rounded corner');
    expect(logo.at(1239, 1239).alpha, 0, reason: 'a rounded corner');
    expect(logo.at(620, 0).alpha, 255, reason: 'the tile reaches the edges');
    expect(logo.at(0, 620).alpha, 255, reason: 'the tile reaches the edges');
  });

  testWidgets('at 32 px and below the app icon is the three rules alone', (tester) async {
    final names = Directory('windows/msix/Images').listSync().map((f) => f.uri.pathSegments.last).toSet();
    // The msix tool's names for the app icon at those sizes: plated, and
    // unplated for dark and light taskbars.
    expect(names, {
      for (final size in [16, 20, 24, 30, 32])
        for (final form in ['targetsize', 'altform-unplated_targetsize', 'altform-lightunplated_targetsize'])
          'Square44x44Logo.$form-$size.png',
    });
    for (final name in names) {
      final size = int.parse(RegExp(r'-(\d+)\.png$').firstMatch(name)![1]!);
      final icon = await _pixels(tester, 'windows/msix/Images/$name');
      expect((icon.width, icon.height), (size, size), reason: name);
      // Down the middle: cream, cream and gold rules on the gradient, and
      // no wordmark.
      final rules = <_Pixel>[];
      var inRule = false;
      for (var y = 0; y < size; y++) {
        final pixel = icon.at(size ~/ 2, y);
        final ink = pixel.alpha == 255 && pixel.red > 150;
        if (ink && !inRule) rules.add(pixel);
        inRule = ink;
      }
      expect(rules, hasLength(3), reason: name);
      expect([for (final rule in rules) rule.blue > 150], [true, true, false], reason: '$name: the Targum rule is gold');
      expect(icon.at(0, 0).alpha, lessThan(255), reason: '$name: a rounded corner');
    }
  });
}

/// The decoded PNG at [path].
Future<_Pixels> _pixels(WidgetTester tester, String path) async => (await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
      final image = (await codec.getNextFrame()).image;
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
      final pixels = _Pixels(image.width, image.height, bytes);
      image.dispose();
      return pixels;
    }))!;

typedef _Pixel = ({int red, int green, int blue, int alpha});

/// Straight RGBA pixels.
class _Pixels {
  _Pixels(this.width, this.height, this.bytes);

  final int width;
  final int height;
  final ByteData bytes;

  _Pixel at(int x, int y) {
    final i = (y * width + x) * 4;
    return (red: bytes.getUint8(i), green: bytes.getUint8(i + 1), blue: bytes.getUint8(i + 2), alpha: bytes.getUint8(i + 3));
  }
}

/// A repository with a Windows release build in it, as far as
/// tool/windows/make_msix.sh sees one, and stand-ins for the msix tool (as
/// `dart`) and its MakePri that do to the build's folder what they do on
/// Windows.
class _MsixSandbox {
  _MsixSandbox() : root = Directory.systemTemp.createTempSync('make_msix_') {
    addTearDown(() => root.deleteSync(recursive: true));
    _write('tool/windows/make_msix.sh', File('tool/windows/make_msix.sh').readAsStringSync());
    _write('$_release/shnayim_mikrah.exe', 'exe');
    _write('$_release/flutter_windows.dll', 'flutter');
    builtDlls.forEach((name, contents) => _write('$_release/$name', contents));
    for (final language in ['en-us', 'he-il']) {
      _write('windows/msix/Strings/$language/Resources.resw', '<root/>');
    }
    _write('windows/msix/Images/Square44x44Logo.targetsize-16.png', 'png');
    _write('windows/msix/priconfig.xml', '<resources/>');
    final msix = '${root.path}/pub cache/msix-3.18.0';
    _write('.dart_tool/package_config.json', '{\n  "packages": [\n    {\n      "name": "msix",\n'
        '      "rootUri": "file://${msix.replaceAll(' ', '%20')}",\n      "packageUri": "lib/"\n    }\n  ]\n}\n');
    _executable('pub cache/msix-3.18.0/lib/assets/MSIX-Toolkit/Redist.x64/MakePri.exe', r'''
command=$1
of=
while [ $# -gt 0 ]; do
  if [ "$1" = /of ]; then of=$2; fi
  shift
done
case "$command" in
  new) echo pri > "$of" ;;
  dump)
    if [ -n "${NO_HEBREW_NAME:-}" ]; then
      echo '<Candidate qualifiers="Language-EN-US"/>' > "$of"
    else
      echo '<Candidate qualifiers="Language-HE-IL"/>' > "$of"
    fi
    ;;
esac
''');
    _executable('bin/dart', r'''
release=build/windows/x64/runner/Release
runtime="concrt140.dll msvcp140.dll msvcp140_1.dll msvcp140_2.dll msvcp140_atomic_wait.dll
  msvcp140_codecvt_ids.dll vccorlib140.dll vcruntime140.dll vcruntime140_1.dll vcruntime140_threads.dll"
case "$2" in
  msix:build)
    # cleanTemporaryFiles, then copyVCLibsFiles: the tool's own copy.
    for dll in $runtime; do rm -f "$release/$dll"; done
    for dll in msvcp140.dll vcruntime140.dll vcruntime140_1.dll; do echo "msix's $dll" > "$release/$dll"; done
    mkdir -p "$release/Images"
    echo manifest > "$release/AppxManifest.xml"
    ;;
  msix:pack)
    test -f "$release/resources.pri"
    mkdir -p build/windows/msix
    echo package > build/windows/msix/ShnayimMikrah.msix
    # cleanTemporaryFiles, and only then signing.
    for dll in $runtime; do rm -f "$release/$dll"; done
    rm -rf "$release/Images" "$release/AppxManifest.xml" "$release"/resources*.pri
    if [ -n "${FAIL_SIGNING:-}" ]; then echo 'SignTool Error' >&2; exit 1; fi
    ;;
  *) echo "unexpected: $*" >&2; exit 2 ;;
esac
''');
  }

  static const _release = 'build/windows/x64/runner/Release';

  /// The Visual C++ runtime that windows/CMakeLists.txt installs beside the
  /// executable, by name and contents.
  static const builtDlls = {
    'concrt140.dll': 'built concrt140',
    'msvcp140.dll': 'built msvcp140',
    'msvcp140_1.dll': 'built msvcp140_1',
    'msvcp140_2.dll': 'built msvcp140_2',
    'msvcp140_atomic_wait.dll': 'built msvcp140_atomic_wait',
    'msvcp140_codecvt_ids.dll': 'built msvcp140_codecvt_ids',
    'vccorlib140.dll': 'built vccorlib140',
    'vcruntime140.dll': 'built vcruntime140',
    'vcruntime140_1.dll': 'built vcruntime140_1',
  };

  final Directory root;

  File get package => File('${root.path}/build/windows/msix/ShnayimMikrah.msix');

  /// The runtime's DLLs in the build's folder after packaging, by name and
  /// contents.
  Map<String, String> folderDlls() => {
        for (final file in Directory('${root.path}/$_release').listSync().whereType<File>())
          if (file.path.endsWith('.dll') && !file.path.endsWith('flutter_windows.dll'))
            file.uri.pathSegments.last: file.readAsStringSync(),
      };

  /// Runs make_msix.sh, with the msix tool failing to sign the package if
  /// [failSigning], and MakePri indexing no Hebrew name if [noHebrewName].
  Future<ProcessResult> run({bool failSigning = false, bool noHebrewName = false}) => Process.run(
        'bash',
        ['tool/windows/make_msix.sh'],
        workingDirectory: root.path,
        environment: {
          'PATH': '${root.path}/bin:${Platform.environment['PATH']}',
          if (failSigning) 'FAIL_SIGNING': '1',
          if (noHebrewName) 'NO_HEBREW_NAME': '1',
        },
      );

  void _write(String path, String contents) => File('${root.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(contents);

  void _executable(String path, String script) {
    _write(path, '#!/usr/bin/env bash\nset -eu\n$script');
    Process.runSync('chmod', ['+x', '${root.path}/$path']);
  }
}
