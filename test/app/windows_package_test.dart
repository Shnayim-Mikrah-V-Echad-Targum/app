import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

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
