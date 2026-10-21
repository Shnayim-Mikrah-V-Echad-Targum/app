import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/ui/theme/palette.dart';

/// tool/android_twa: the Android web app, a Trusted Web Activity that opens
/// https://shnayimmikrah.org/ as an app of its own. The pre-release workflow
/// builds and signs it (test/app/prerelease_workflow_test.dart), and puts
/// its certificate in the site's assetlinks.json.
void main() {
  const project = 'tool/android_twa';
  const res = '$project/app/src/main/res';
  const nativeRes = 'android/app/src/main/res';
  final manifest = File('$project/app/src/main/AndroidManifest.xml').readAsStringSync();
  final gradle = File('$project/app/build.gradle.kts').readAsStringSync();

  /// The value or resource of the meta-data [name] in the manifest.
  String? metaData(String name) => RegExp(
        '<meta-data\\s+android:name="${RegExp.escape(name)}"\\s+android:(?:value|resource)="([^"]*)"',
      ).firstMatch(manifest)?[1];

  /// The string or colour [name] in values[qualifier]/[file].xml.
  String value(String file, String type, String name, {String folder = res, String qualifier = ''}) {
    final xml = File('$folder/values$qualifier/$file.xml').readAsStringSync();
    return RegExp('<$type name="$name"[^>]*>(.*?)</$type>', dotAll: true).firstMatch(xml)![1]!;
  }

  String hex(Color color) => '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  test('is org.shnayimmikrah.web, beside the native app', () {
    expect(gradle, contains('namespace = "org.shnayimmikrah.web"'));
    expect(gradle, contains('applicationId = "org.shnayimmikrah.web"'));
    expect(File('android/app/build.gradle.kts').readAsStringSync(), contains('applicationId = "org.shnayimmikrah.app"'));
  });

  test("opens the site with androidbrowserhelper's LauncherActivity", () {
    expect(gradle, matches(RegExp(r'implementation\("com\.google\.androidbrowserhelper:androidbrowserhelper:2\.\d+\.\d+"\)')));
    final launcher = RegExp(
      r'<activity\s+android:name="com\.google\.androidbrowserhelper\.trusted\.LauncherActivity"(.*?)</activity>',
      dotAll: true,
    ).firstMatch(manifest)![1]!;
    expect(launcher, contains('android:exported="true"'));
    expect(launcher, matches(RegExp(r'<action android:name="android\.intent\.action\.MAIN" />\s*<category android:name="android\.intent\.category\.LAUNCHER" />')));
    expect(metaData('android.support.customtabs.trusted.DEFAULT_URL'), 'https://shnayimmikrah.org/');
    // A Custom Tab where no browser supports Trusted Web Activities.
    expect(metaData('android.support.customtabs.trusted.FALLBACK_STRATEGY'), 'customtabs');
    expect(RegExp('<activity').allMatches(manifest), hasLength(1));
  });

  test("opens the site's links, once Android has checked them", () {
    final filter = RegExp(r'<intent-filter android:autoVerify="true">(.*?)</intent-filter>', dotAll: true).firstMatch(manifest)![1]!;
    expect(filter, contains('<action android:name="android.intent.action.VIEW" />'));
    expect(filter, contains('<category android:name="android.intent.category.DEFAULT" />'));
    expect(filter, contains('<category android:name="android.intent.category.BROWSABLE" />'));
    expect(filter, matches(RegExp(r'<data\s+android:scheme="https"\s+android:host="shnayimmikrah\.org" />')));
  });

  test('trusts the site, as the site trusts it', () {
    expect(metaData('asset_statements'), '@string/asset_statements');
    final statements = jsonDecode(value('strings', 'string', 'asset_statements').replaceAll(r'\"', '"'));
    expect(statements, [
      {
        'relation': ['delegate_permission/common.handle_all_urls'],
        'target': {'namespace': 'web', 'site': 'https://shnayimmikrah.org'},
      },
    ]);
  });

  test("has the app's colours: its surface around the site and behind the splash", () {
    expect(value('colors', 'color', 'surface'), hex(Palettes.light.surface));
    expect(value('colors', 'color', 'surface_dark'), hex(Palettes.dark.surface));
    for (final bar in ['STATUS_BAR_COLOR', 'NAVIGATION_BAR_COLOR']) {
      expect(metaData('android.support.customtabs.trusted.$bar'), '@color/surface', reason: bar);
      expect(metaData('android.support.customtabs.trusted.${bar}_DARK'), '@color/surface_dark', reason: bar);
    }
    expect(metaData('android.support.customtabs.trusted.SPLASH_SCREEN_BACKGROUND_COLOR'), '@color/surface');
    expect(value('colors', 'color', 'ic_launcher_background'),
        value('colors', 'color', 'ic_launcher_background', folder: nativeRes));
  });

  test("has the native app's name, icon and splash", () {
    expect(value('strings', 'string', 'app_name'), 'Shnayim Mikrah');
    expect(value('strings', 'string', 'app_name', qualifier: '-iw'), 'שניים מקרא');
    for (final qualifier in ['', '-iw']) {
      expect(value('strings', 'string', 'app_name', qualifier: qualifier),
          value('strings', 'string', 'app_name', folder: nativeRes, qualifier: qualifier));
    }
    expect(manifest, contains('android:label="@string/app_name"'));
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(metaData('android.support.customtabs.trusted.SPLASH_IMAGE_DRAWABLE'), '@drawable/splash');
    final copies = [
      'mipmap-anydpi-v26/ic_launcher.xml',
      for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) ...[
        'mipmap-$density/ic_launcher.png',
        'drawable-$density/ic_launcher_foreground.png',
        'drawable-$density/ic_launcher_monochrome.png',
        'drawable-$density/splash.png',
      ],
    ];
    for (final copy in copies) {
      expect(File('$res/$copy').readAsBytesSync(), File('$nativeRes/$copy').readAsBytesSync(), reason: copy);
    }
    // The browser shows the splash through the FileProvider.
    expect(metaData('android.support.customtabs.trusted.FILE_PROVIDER_AUTHORITY'), r'${applicationId}.fileprovider');
    expect(manifest, contains(r'android:authorities="${applicationId}.fileprovider"'));
    expect(File('$res/xml/filepaths.xml').readAsStringSync(), contains('<files-path name="twa_splash" path="twa_splash/" />'));
  });

  test("builds with android/'s plugin and SDK, numbered by the workflow", () {
    final agp = RegExp(r'id\("com\.android\.application"\) version "([^"]+)"');
    final native = agp.firstMatch(File('android/settings.gradle.kts').readAsStringSync())![1];
    expect(agp.firstMatch(File('$project/settings.gradle.kts').readAsStringSync())![1], native);
    // Flutter's compileSdk and targetSdk (android/app/build.gradle.kts).
    expect(gradle, contains('compileSdk = 36'));
    expect(gradle, contains('targetSdk = 36'));
    final minSdk = int.parse(RegExp(r'minSdk = (\d+)').firstMatch(gradle)![1]!);
    expect(minSdk, greaterThanOrEqualTo(21));
    expect(gradle, contains('providers.gradleProperty("versionName")'));
    expect(gradle, contains('providers.gradleProperty("versionCode")'));
  });

  test('is signed with a key from the environment, never from the repository', () {
    expect(gradle, contains('providers.environmentVariable("TWA_KEYSTORE")'));
    expect(gradle, isNot(matches(RegExp(r'(?:store|key)Password\s*=\s*"'))));
    final keys = Directory(project)
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.path.substring(project.length + 1))
        // Gradle's own folders, which .gitignore leaves out.
        .where((path) => !path.startsWith('.gradle/') && !path.startsWith('build/') && !path.startsWith('app/build/'))
        .where((path) => RegExp(r'\.(?:jks|keystore|p12|pfx)$|(?:^|/)key\.properties$').hasMatch(path));
    expect(keys, isEmpty);
    final ignored = File('$project/.gitignore').readAsLinesSync();
    expect(ignored, containsAll(['*.jks', '*.keystore', '*.p12']));
  });
}
