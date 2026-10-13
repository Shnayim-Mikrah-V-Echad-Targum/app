import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// .github/workflows/release.yml, which a tag vX.Y.Z runs. It builds nothing
/// until the production configuration is complete, so that no store build
/// ships the on-device demo community, and it numbers every build itself
/// (docs/RELEASE.md, Every release). tool/ios/test_sign_for_app_store.py
/// checks its iOS signing.
void main() {
  final source = File('.github/workflows/release.yml').readAsStringSync();
  final workflow = loadYaml(source) as YamlMap;
  final jobs = workflow['jobs'] as YamlMap;
  final preflight = jobs['preflight'] as YamlMap;

  Iterable<YamlMap> steps(YamlMap job) => (job['steps'] as YamlList).cast<YamlMap>();
  YamlMap step(YamlMap job, String name) => steps(job).firstWhere((step) => step['name'] == name);

  // The names that a step of the preflight checks are set.
  Set<String> checked(String name) {
    final run = step(preflight, name)['run'] as String;
    final names = RegExp(r'for v in (.*?); do', dotAll: true).firstMatch(run)![1]!;
    return names.replaceAll(r'\', ' ').split(RegExp(r'\s+')).where((name) => name.isNotEmpty).toSet();
  }

  Set<String> referenced(String context) =>
      RegExp('\\b$context\\.(\\w+)').allMatches(source).map((match) => match[1]!).toSet();

  test('runs for version tags alone', () {
    expect(workflow['on'], {
      'push': {
        'tags': ['v*.*.*'],
      },
    });
  });

  test('every build waits for the preflight', () {
    expect(jobs.keys, containsAll(['preflight', 'android', 'ios', 'windows']));
    for (final name in jobs.keys.where((name) => name != 'preflight')) {
      expect((jobs[name] as YamlMap)['needs'], 'preflight', reason: name);
    }
  });

  group('the preflight', () {
    test('checks every secret the release uses', () {
      final secrets = checked('Repository secrets');
      expect(secrets, referenced('secrets'));
      final env = step(preflight, 'Repository secrets')['env'] as YamlMap;
      for (final name in secrets) {
        expect(env[name], '\${{ secrets.$name }}');
      }
    });

    // INSTALL_URL is optional, as on the web: without it the web offers no
    // installed app, and the apps never offer one.
    test('checks every variable but INSTALL_URL', () {
      final variables = checked('Repository variables');
      expect(variables, referenced('vars').difference({'INSTALL_URL'}));
      expect(variables, containsAll(['SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY', 'SUPPORT_EMAIL']));
      final env = step(preflight, 'Repository variables')['env'] as YamlMap;
      for (final name in variables) {
        expect(env[name], '\${{ vars.$name }}');
      }
    });

    // Google Play shows them with each bundle: a release that kept the last
    // one's would be described as "The first release".
    test('checks the release notes were written since the last release', () {
      expect((steps(preflight).first['with'] as YamlMap)['fetch-depth'], 0, reason: 'every tag');
      final run = step(preflight, 'Release notes written since the last release')['run'] as String;
      expect(run, contains(r'''git describe --tags --abbrev=0 --match 'v*.*.*' "$GITHUB_REF_NAME^"'''));
      expect(run, contains(r'git diff --quiet "$previous" "$GITHUB_REF_NAME" -- store/play/whatsnew'));
      expect(run, contains('exit 1'));
    });

    test('checks the tag against the version in pubspec.yaml', () {
      final run = step(preflight, 'The tag is the version in pubspec.yaml')['run'] as String;
      expect(run, contains(r"version=$(sed -n 's/^version: \([0-9.]*\).*/\1/p' pubspec.yaml)"));
      expect(run, contains(r'[ "${GITHUB_REF_NAME#v}" != "$version" ]'));
    });
  });

  test("pubspec.yaml's version is X.Y.Z, and its build number below the release builds' numbers", () {
    final version = RegExp(r'^version: ([0-9.]*)\+(\d+)$', multiLine: true)
        .firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(version, isNotNull);
    expect(version![1], matches(RegExp(r'^\d+\.\d+\.\d+$')));
    expect(int.parse(version[2]!), lessThan(1000));
  });

  test('the builds have the configuration of CI', () {
    final ci = loadYaml(File('.github/workflows/ci.yml').readAsStringSync()) as YamlMap;
    for (final name in ['DART_DEFINES', 'FLUTTER_VERSION']) {
      expect((workflow['env'] as YamlMap)[name], (ci['env'] as YamlMap)[name], reason: name);
    }
  });

  test('every build is a release build with the configuration, numbered 1000 + the run', () {
    final builds = [
      for (final job in jobs.values.cast<YamlMap>())
        for (final step in steps(job))
          if (step['run'] case final String run)
            for (final line in run.replaceAll('\\\n', ' ').split('\n'))
              if (line.trim().startsWith('flutter build ')) line.trim(),
    ];
    expect(builds.map((build) => build.split(RegExp(r'\s+'))[2]), unorderedEquals(['appbundle', 'ipa', 'windows']));
    for (final build in builds) {
      expect(build, contains(' --release '));
      expect(build, contains(r' --build-number=$((1000 + GITHUB_RUN_NUMBER)) '));
      expect(build, endsWith(r' $DART_DEFINES'));
    }
  });

  test('Android is signed with the upload key, and goes to internal testing as a draft', () {
    final android = jobs['android'] as YamlMap;
    // Required, where CI goes on without it.
    expect(step(android, 'Release signing')['if'], isNull);
    final upload = step(android, 'Upload to Google Play')['with'] as YamlMap;
    expect(File('android/app/build.gradle.kts').readAsStringSync(),
        contains('applicationId = "${upload['packageName']}"'));
    expect(upload['releaseFiles'], 'build/app/outputs/bundle/release/app-release.aab');
    expect(upload['track'], 'internal');
    expect(upload['status'], 'draft');
    // One file of release notes for each listing (tool/store/test_store.py).
    final notes = Directory(upload['whatsNewDirectory'] as String).listSync().map((file) => file.uri.pathSegments.last);
    final listings = Directory('store/play')
        .listSync()
        .whereType<Directory>()
        .map((folder) => folder.uri.pathSegments.where((segment) => segment.isNotEmpty).last)
        .where((name) => name != 'whatsnew');
    expect(notes.toSet(), {for (final locale in listings) 'whatsnew-$locale'});
  });

  // So that the one store build can't be taken for one of CI's, which have
  // whatever configuration CI has (docs/RELEASE.md, The Release workflow).
  test("the bundle's artifact is named apart from CI's", () {
    final upload = steps(jobs['android'] as YamlMap)
        .firstWhere((step) => step['uses'] == 'actions/upload-artifact@v4' && '${(step['with'] as YamlMap)['path']}'.endsWith('.aab'));
    expect((upload['with'] as YamlMap)['name'], 'android-release-aab');
    final ci = File('.github/workflows/ci.yml').readAsStringSync();
    final names = RegExp(r'^\s+name: (.+)$', multiLine: true)
        .allMatches(ci.substring(ci.indexOf('actions/upload-artifact')))
        .map((match) => match[1]!)
        .join(' ');
    expect(names, isNot(contains('android-release-aab')));
    expect(names, isNot(matches(RegExp(r"'android'"))));
    final release = File('docs/RELEASE.md').readAsStringSync();
    expect(release, contains('`android-release-aab`'));
    expect(release, isNot(contains('`android` artifact')));
  });

  test('iOS is exported for the App Store', () {
    final ios = jobs['ios'] as YamlMap;
    expect(step(ios, 'Build the IPA')['run'], contains('--export-options-plist=ios/ExportOptions.plist'));
    expect(File('ios/ExportOptions.plist').readAsStringSync(), contains('<string>app-store-connect</string>'));
    // Build settings for every target alike, which the widget's own profile
    // rules out: tool/ios/sign_for_app_store.py signs each target instead.
    expect(source, isNot(contains('FLUTTER_XCODE_PROVISIONING_PROFILE_SPECIFIER')));
  });

  test('Windows is signed with the certificate alone, into a draft release', () {
    final windows = jobs['windows'] as YamlMap;
    final package = step(windows, 'Package as MSIX, signed with the certificate')['run'] as String;
    expect(package, contains('--certificate-path "\$certificate" --certificate-password "\$CERTIFICATE_PASSWORD"'));
    expect(package, isNot(contains('else')));
    expect((windows['permissions'] as YamlMap)['contents'], 'write');
    final release = step(windows, 'Draft the release with the installer')['with'] as YamlMap;
    expect(release['draft'], isTrue);
    expect(release['generate_release_notes'], isTrue);
    final outputName = ((loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap)['msix_config'] as YamlMap)['output_name'];
    expect(release['files'], 'build/windows/msix/$outputName.msix');
  });

  test('docs/RELEASE.md names every variable and secret it reads', () {
    final release = File('docs/RELEASE.md').readAsStringSync();
    final names = {...referenced('vars'), ...referenced('secrets')};
    expect(names.where((name) => !release.contains('`$name`')), isEmpty);
  });
}
