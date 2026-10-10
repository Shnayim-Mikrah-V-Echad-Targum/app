import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/services/app_shortcuts.dart';

/// The native side of the shortcuts on the app's icon
/// (lib/services/app_shortcuts.dart).
void main() {
  test('Android: the shortcuts wear the launcher icon', () {
    expect(AppShortcutsService.icon, 'ic_launcher');
    const res = 'android/app/src/main/res';
    expect(File('$res/mipmap-anydpi-v26/ic_launcher.xml').existsSync(), isTrue);
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(File('$res/mipmap-$density/ic_launcher.png').existsSync(), isTrue, reason: density);
    }
  });

  test('Android: a recreated activity forgets the shortcut that started it', () {
    // quick_actions_android reads the chosen shortcut from an intent extra;
    // MainActivity must remove that same extra.
    final config = File('.dart_tool/package_config.json');
    final packages = (jsonDecode(config.readAsStringSync()) as Map<String, dynamic>)['packages'] as List;
    final plugin = packages.cast<Map<String, dynamic>>().firstWhere((p) => p['name'] == 'quick_actions_android');
    final root = config.absolute.uri.resolve('${plugin['rootUri']}/');
    final source = File.fromUri(root.resolve('android/src/main/java/io/flutter/plugins/quickactions/QuickActions.java'))
        .readAsStringSync();
    final extra = RegExp(r'EXTRA_ACTION\s*=\s*"([^"]+)"').firstMatch(source)![1]!;

    final activity =
        File('android/app/src/main/kotlin/org/shnayimmikra/shnayim_mikra/MainActivity.kt').readAsStringSync();
    expect(activity, contains('const val QUICK_ACTION_EXTRA = "$extra"'));
    expect(activity, contains('intent.removeExtra(QUICK_ACTION_EXTRA)'));
    expect(activity, contains('setIntent(intent)'));
  });

  group('iOS: the shortcuts wear the mark', () {
    const folder = 'ios/Runner/Assets.xcassets/ShortcutMark.imageset';

    test('as a template image in the asset catalog', () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final name = AppShortcutsService.icon;
      expect(folder, endsWith('/$name.imageset'));

      final contents = jsonDecode(File('$folder/Contents.json').readAsStringSync()) as Map<String, dynamic>;
      expect((contents['properties'] as Map)['template-rendering-intent'], 'template');
      expect([
        for (final image in (contents['images'] as List).cast<Map<String, dynamic>>()) (image['scale'], image['filename']),
      ], [
        ('2x', 'ShortcutMark@2x.png'),
        ('3x', 'ShortcutMark@3x.png'),
      ]);
    });

    for (final (scale, size) in [(2, 70), (3, 105)]) {
      test('at ${scale}x: 35 pt, transparent around the mark', () async {
        final codec = await ui.instantiateImageCodec(File('$folder/ShortcutMark@${scale}x.png').readAsBytesSync());
        final image = (await codec.getNextFrame()).image;
        addTearDown(image.dispose);
        expect((image.width, image.height), (size, size));
        final pixels = (await image.toByteData())!;
        int alphaAt(int x, int y) => pixels.getUint8((y * size + x) * 4 + 3);
        // A template is drawn from its alpha alone: the mark, centred, all
        // but as wide as the canvas, with clear space above and below it.
        final inked = [
          for (var y = 0; y < size; y++)
            for (var x = 0; x < size; x++)
              if (alphaAt(x, y) > 128) (x, y),
        ];
        final xs = inked.map((p) => p.$1);
        final ys = inked.map((p) => p.$2);
        final (left, right) = (xs.reduce(math.min), xs.reduce(math.max));
        final (top, bottom) = (ys.reduce(math.min), ys.reduce(math.max));
        expect((right - left + 1) / size, closeTo(0.94, 0.03));
        expect((left - (size - 1 - right)).abs(), lessThanOrEqualTo(1));
        expect((top - (size - 1 - bottom)).abs(), lessThanOrEqualTo(1));
        expect(top, greaterThan(size ~/ 5));
      });
    }
  });
}
