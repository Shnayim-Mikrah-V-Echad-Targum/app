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
    expect(config['identity_name'], 'org.shnayimmikra.app');
    expect(File('android/app/build.gradle.kts').readAsStringSync(), contains('applicationId = "org.shnayimmikra.app"'));
    expect(File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(),
        contains('PRODUCT_BUNDLE_IDENTIFIER = org.shnayimmikra.app;'));
    expect(config['display_name'], 'Shnayim Mikra');
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
