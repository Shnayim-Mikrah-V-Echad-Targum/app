import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// .github/workflows/prerelease.yml, which a tag v0.Y.Z runs: it builds a
/// preview of every platform the owner releases first (the Windows MSI and
/// zip, the Android web app and the web app), deploys the site, and drafts a
/// GitHub pre-release with the files (docs/RELEASE.md, Pre-releases).
/// test/app/twa_project_test.dart checks the Android web app's project.
void main() {
  final source = File('.github/workflows/prerelease.yml').readAsStringSync();
  final workflow = loadYaml(source) as YamlMap;
  final jobs = workflow['jobs'] as YamlMap;
  final env = workflow['env'] as YamlMap;
  final ci = loadYaml(File('.github/workflows/ci.yml').readAsStringSync()) as YamlMap;
  final ciJobs = ci['jobs'] as YamlMap;

  const assets = [
    r'ShnayimMikrah-$VERSION-windows-x64.msi',
    r'ShnayimMikrah-$VERSION-windows-x64.zip',
    r'ShnayimMikrah-$VERSION-android-webapp.apk',
    'install.ps1',
  ];
  const oneLiner = 'Set-ExecutionPolicy Bypass -Scope Process -Force; irm '
      'https://raw.githubusercontent.com/Shnayim-Mikrah-V-Echad-Targum/app/main/tool/windows/install.ps1 | iex';

  YamlMap job(String name) => jobs[name] as YamlMap;
  Iterable<YamlMap> steps(YamlMap job) => (job['steps'] as YamlList).cast<YamlMap>();
  YamlMap step(YamlMap job, String name) => steps(job).firstWhere((step) => step['name'] == name);
  String run(String jobName, String stepName) => step(job(jobName), stepName)['run'] as String;
  List<YamlMap> uses(YamlMap job, String action) =>
      steps(job).where((step) => '${step['uses']}'.split('@').first == action).toList();
  int index(YamlMap job, YamlMap step) => steps(job).toList().indexOf(step);
  Set<String> needs(String name) => switch (job(name)['needs']) {
        final String one => {one},
        final YamlList many => many.cast<String>().toSet(),
        _ => {},
      };
  Set<String> referenced(String context) =>
      RegExp('\\b$context\\.(\\w+)').allMatches(source).map((match) => match[1]!).toSet();

  test('runs for a pre-release tag, or by hand for a tag', () {
    expect(workflow['on'], {
      'push': {
        'tags': ['v0.*.*'],
      },
      'workflow_dispatch': {
        'inputs': {
          'tag': {
            'description': isA<String>(),
            'required': true,
            'type': 'string',
          },
        },
      },
    });
    expect(env['TAG'], r'${{ inputs.tag || github.ref_name }}');
    // Every job builds the tag's commit, also when run by hand from main.
    for (final name in jobs.keys) {
      for (final checkout in uses(job(name as String), 'actions/checkout')) {
        expect((checkout['with'] as YamlMap)['ref'], r'refs/tags/${{ env.TAG }}', reason: name);
      }
    }
  });

  test('one run at a time for each tag, never cancelled part-way', () {
    expect(workflow['concurrency'], {
      'group': r'prerelease-${{ inputs.tag || github.ref_name }}',
      'cancel-in-progress': false,
    });
  });

  test('the preflight checks the tag against the version in pubspec.yaml', () {
    final preflight = job('preflight');
    // A tag given by hand is checked before anything uses it.
    expect(steps(preflight).first['run'], contains(r'[[ ! "$TAG" =~ ^v0\.[0-9]+\.[0-9]+$ ]]'));
    final check = run('preflight', 'The tag is the version in pubspec.yaml');
    expect(check, contains(r"version=$(sed -n 's/^version: \([0-9.]*\).*/\1/p' pubspec.yaml)"));
    expect(check, contains(r'[ "${TAG#v}" != "$version" ]'));
    expect(check, contains('exit 1'));
    expect((preflight['outputs'] as YamlMap)['version'], r'${{ steps.version.outputs.version }}');
  });

  test('the jobs: the builds after the preflight, the site and the draft after them', () {
    expect(jobs.keys, unorderedEquals(['preflight', 'windows', 'twa', 'web', 'pages', 'pages-help', 'release']));
    expect(needs('windows'), {'preflight'});
    expect(needs('twa'), {'preflight'});
    // The site's asset links name the APK's certificate.
    expect(needs('web'), {'preflight', 'twa'});
    expect(needs('pages'), {'web'});
    expect(needs('release'), {'preflight', 'windows', 'twa', 'web'});
    for (final name in ['windows', 'twa', 'release']) {
      expect((job(name)['env'] as YamlMap)['VERSION'], r'${{ needs.preflight.outputs.version }}', reason: name);
    }
  });

  group('the configuration', () {
    test("is CI's, with the site's address and without the community", () {
      expect(env['FLUTTER_VERSION'], (ci['env'] as YamlMap)['FLUTTER_VERSION']);
      final ciDefines = (ci['env'] as YamlMap)['DART_DEFINES'] as String;
      expect(ciDefines, contains(r'--dart-define=WEB_URL=${{ vars.WEB_URL }}'));
      expect(
        env['DART_DEFINES'],
        '${ciDefines.replaceFirst(r'--dart-define=WEB_URL=${{ vars.WEB_URL }}', '--dart-define=WEB_URL=https://shnayimmikrah.org/')}'
        ' --dart-define=COMMUNITY=off',
      );
    });

    test('Windows looks for updates among the pre-releases, numbered from the tag and the run', () {
      expect(
        run('windows', 'Build'),
        contains(r'flutter build windows --release --build-name="$VERSION" --build-number="$GITHUB_RUN_NUMBER" '
            r'$DART_DEFINES --dart-define=UPDATE_CHANNEL=prerelease'),
      );
    });

    test("the web app is at the domain's root", () {
      final build = run('web', 'Build (self-hosted engine, no third-party CDN)').replaceAll('\\\n', ' ');
      expect(build, matches(RegExp(r'flutter build web --release --no-web-resources-cdn --no-wasm-dry-run\s+--base-href / \$DART_DEFINES')));
      expect((step(job('web'), 'Absolute link-preview URLs')['env'] as YamlMap)['WEB_URL'], 'https://shnayimmikrah.org/');
    });

    test('the update channel is for Windows alone', () {
      final builds = RegExp(r'flutter build (\w+)').allMatches(source).map((match) => match[1]).toList();
      expect(builds, ['windows', 'web']);
      expect(env['DART_DEFINES'], isNot(contains('UPDATE_CHANNEL')));
      expect(run('web', 'Build (self-hosted engine, no third-party CDN)'), isNot(contains('UPDATE_CHANNEL')));
    });
  });

  group('Windows', () {
    final windows = job('windows');

    test('the folder has the Visual C++ runtime, as in CI', () {
      final check = step(windows, 'The Visual C++ runtime is in the folder');
      final ciWindows = ciJobs['windows'] as YamlMap;
      expect(check['run'], step(ciWindows, 'The Visual C++ runtime is in the folder')['run']);
      expect(index(windows, check), lessThan(index(windows, step(windows, 'The folder, zipped'))));
      expect(index(windows, check), lessThan(index(windows, step(windows, 'The MSI'))));
    });

    test('zips the folder and builds the MSI from it with tool/windows/build_msi.ps1', () {
      expect(run('windows', 'The folder, zipped'),
          contains(r'Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath "ShnayimMikrah-$env:VERSION-windows-x64.zip"'));
      final msi = step(windows, 'The MSI');
      expect(msi['shell'], 'pwsh');
      expect(
        msi['run'],
        r'powershell -ExecutionPolicy Bypass -File tool\windows\build_msi.ps1 -ReleaseDir build\windows\x64\runner\Release '
        r'-Version $env:VERSION -Out "ShnayimMikrah-$env:VERSION-windows-x64.msi"',
      );
      final dotnet = uses(windows, 'actions/setup-dotnet').single;
      expect((dotnet['with'] as YamlMap)['dotnet-version'], '8.0.x');
      expect(index(windows, dotnet), lessThan(index(windows, msi)));
      final upload = (uses(windows, 'actions/upload-artifact').single['with'] as YamlMap);
      expect(upload['name'], 'windows');
      expect('${upload['path']}'.trim().split('\n'), [
        r'ShnayimMikrah-${{ env.VERSION }}-windows-x64.msi',
        r'ShnayimMikrah-${{ env.VERSION }}-windows-x64.zip',
      ]);
    });
  });

  group('the Android web app', () {
    final twa = job('twa');
    final key = step(twa, 'The signing key');

    test("is built with Java 17 and android/'s Gradle", () {
      final java = uses(twa, 'actions/setup-java').single['with'] as YamlMap;
      expect(java['distribution'], 'temurin');
      expect(java['java-version'], '17');
      final wrapper = File('android/gradle/wrapper/gradle-wrapper.properties').readAsStringSync();
      final gradle = RegExp(r'gradle-([0-9.]+)-(?:all|bin)\.zip').firstMatch(wrapper)![1];
      expect((uses(twa, 'gradle/actions/setup-gradle').single['with'] as YamlMap)['gradle-version'], gradle);
      expect(
        run('twa', 'Build the APK'),
        contains(r'gradle -p tool/android_twa assembleRelease -PversionName="$VERSION" -PversionCode="$GITHUB_RUN_NUMBER"'),
      );
      expect(run('twa', 'Build the APK'),
          contains(r'cp tool/android_twa/app/build/outputs/apk/release/app-release.apk "ShnayimMikrah-$VERSION-android-webapp.apk"'));
    });

    test("is signed with the secrets' key if there is one, and otherwise with one made for the run", () {
      final keyEnv = key['env'] as YamlMap;
      for (final name in ['KEYSTORE_BASE64', 'KEYSTORE_PASSWORD', 'KEY_ALIAS', 'KEY_PASSWORD']) {
        expect(keyEnv[name], '\${{ secrets.ANDROID_TWA_$name }}');
      }
      final script = key['run'] as String;
      expect(script, contains(r'if [ -n "$KEYSTORE_BASE64" ]; then'));
      expect(script, contains(r'KEYSTORE_PASSWORD=$(openssl rand -hex 32)'));
      expect(script, contains(r'echo "::add-mask::$KEYSTORE_PASSWORD"'));
      expect(script, contains('keytool -genkeypair'));
      expect(script, contains('-dname "CN=Shnayim Mikrah, O=Shnayim Mikrah"'));
      // As tool/android_twa/app/build.gradle.kts reads them.
      final gradle = File('tool/android_twa/app/build.gradle.kts').readAsStringSync();
      for (final name in ['TWA_KEYSTORE', 'TWA_KEYSTORE_PASSWORD', 'TWA_KEY_ALIAS', 'TWA_KEY_PASSWORD']) {
        expect(script, contains('echo "$name='), reason: name);
        expect(gradle, contains('providers.environmentVariable("$name")'), reason: name);
      }
    });

    test("gives its certificate's SHA-256 to the site, checked against the APK", () {
      expect((twa['outputs'] as YamlMap)['fingerprint'], r'${{ steps.key.outputs.fingerprint }}');
      expect(key['run'], contains(r'[[ ! "$fingerprint" =~ ^([0-9A-F]{2}:){31}[0-9A-F]{2}$ ]]'));
      final check = step(twa, 'The APK is org.shnayimmikrah.web, signed with the key');
      expect((check['env'] as YamlMap)['FINGERPRINT'], r'${{ steps.key.outputs.fingerprint }}');
      expect(check['run'], contains(r'"$build_tools/apksigner" verify --print-certs "$apk"'));
      expect(check['run'], contains("^package: name='org.shnayimmikrah.web' versionCode='\$GITHUB_RUN_NUMBER' versionName='\$VERSION'"));
      final upload = uses(twa, 'actions/upload-artifact').single['with'] as YamlMap;
      expect(upload['name'], 'android-webapp');
      expect(upload['path'], r'ShnayimMikrah-${{ env.VERSION }}-android-webapp.apk');
    });
  });

  group('the web app', () {
    final web = job('web');
    final ciWeb = ciJobs['web'] as YamlMap;

    test("is built as CI's web job builds it", () {
      // Every step of CI's that runs a command, in the same order, and but
      // for the build's flags and the site's address, the same.
      final ciSteps = steps(ciWeb).where((step) => step['run'] != null).toList();
      final mine = [for (final ciStep in ciSteps) step(web, ciStep['name'] as String)];
      final order = [for (final s in mine) index(web, s)];
      expect(order, [...order]..sort());
      for (final (i, ciStep) in ciSteps.indexed) {
        if (ciStep['name'] == 'Build (self-hosted engine, no third-party CDN)') continue;
        expect(mine[i]['run'], ciStep['run'], reason: ciStep['name'] as String);
        if (ciStep['name'] != 'Absolute link-preview URLs') {
          expect(mine[i]['env'], ciStep['env'], reason: ciStep['name'] as String);
        }
      }
      expect(run('web', 'Offline service worker'), contains('node tool/web/sw_build.cjs check build/web'));
    });

    test("serves the Android web app's asset links and the install script, before the service worker", () {
      final links = step(web, 'Digital Asset Links for the Android web app');
      expect((links['env'] as YamlMap)['FINGERPRINT'], r'${{ needs.twa.outputs.fingerprint }}');
      final script = links['run'] as String;
      expect(script, contains('relation: ["delegate_permission/common.handle_all_urls"]'));
      expect(script, contains('namespace: "android_app"'));
      expect(script, contains('package_name: "org.shnayimmikrah.web"'));
      expect(script, contains(r'sha256_cert_fingerprints: [$fingerprint]'));
      expect(script, contains('> build/web/.well-known/assetlinks.json'));
      expect(File('tool/android_twa/app/build.gradle.kts').readAsStringSync(), contains('applicationId = "org.shnayimmikrah.web"'));
      final install = step(web, 'The Windows install script');
      expect(install['run'], 'cp tool/windows/install.ps1 build/web/install.ps1');
      final worker = index(web, step(web, 'Offline service worker'));
      for (final added in [links, install]) {
        expect(index(web, added), greaterThan(index(web, step(web, "The app at every page's address"))));
        expect(index(web, added), lessThan(worker));
      }
    });

    // upload-pages-artifact v4 leaves out every file and folder whose name
    // starts with a dot, .well-known among them.
    test('uploads the site for GitHub Pages with .well-known in it', () {
      final upload = uses(web, 'actions/upload-pages-artifact').single;
      expect(upload['uses'], 'actions/upload-pages-artifact@v3');
      expect((upload['with'] as YamlMap)['path'], 'build/web');
      final check = step(web, "The site's artifact has the asset links and the install script");
      expect(index(web, check), index(web, upload) + 1);
      expect(check['run'], contains(r'tar -tf "$RUNNER_TEMP/artifact.tar"'));
      expect(check['run'], contains('./.well-known/assetlinks.json ./install.ps1'));
    });
  });

  group('GitHub Pages', () {
    final pages = job('pages');

    test('deploys the site when Pages is on, and never fails the release', () {
      expect(pages['continue-on-error'], isTrue);
      expect((pages['environment'] as YamlMap)['name'], 'github-pages');
      expect(uses(pages, 'actions/configure-pages'), hasLength(1));
      final deploy = uses(pages, 'actions/deploy-pages').single;
      expect(deploy['id'], 'deployment');
      expect((pages['outputs'] as YamlMap)['url'], r'${{ steps.deployment.outputs.page_url }}');
      expect(needs('release'), isNot(contains('pages')));
    });

    test("says how to turn Pages on when the site wasn't deployed", () {
      final help = job('pages-help');
      expect(needs('pages-help'), {'web', 'pages'});
      // Also when the github-pages environment's rules kept the job from
      // starting: no address came of it either way.
      expect(help['if'], r"${{ !cancelled() && needs.web.result == 'success' && needs.pages.outputs.url == '' }}");
      final summary = steps(help).single['run'] as String;
      expect(summary, contains(r'>> "$GITHUB_STEP_SUMMARY"'));
      expect(summary, contains('*Settings → Pages*: set *Source* to *GitHub Actions*'));
      expect(summary, contains('`shnayimmikrah.org`'));
      expect(summary, contains('*Settings → Environments → github-pages'));
    });
  });

  test('each job has the least permissions it needs', () {
    expect(workflow['permissions'], {'contents': 'read'});
    final granted = {
      for (final name in jobs.keys)
        if (job(name as String)['permissions'] case final YamlMap permissions) name: permissions,
    };
    expect(granted, {
      'pages': {'pages': 'write', 'id-token': 'write'},
      'pages-help': <String, String>{},
      'release': {'contents': 'write'},
    });
  });

  group('the draft pre-release', () {
    final release = job('release');

    test('has the five files, with their SHA-256 sums', () {
      final downloads = uses(release, 'actions/download-artifact').map((step) => (step['with'] as YamlMap)['name']);
      expect(downloads, unorderedEquals(['windows', 'android-webapp']));
      // A bash array's words, unquoted.
      List<String> array(String script, String name) => RegExp('$name=\\((.*?)\\)', dotAll: true)
          .firstMatch(script)![1]!
          .trim()
          .split(RegExp(r'\s+'))
          .map((word) => word.replaceAll('"', ''))
          .toList();
      final sums = run('release', 'The install script and the SHA-256 sums');
      expect(sums, contains('cp tool/windows/install.ps1 assets/install.ps1'));
      expect(array(sums, 'files'), assets);
      expect(sums, contains(r'sha256sum "${files[@]}" > SHA256SUMS.txt'));
      final draft = run('release', 'Draft the pre-release with the files');
      expect(array(draft, 'assets'), [for (final asset in [...assets, 'SHA256SUMS.txt']) 'assets/$asset']);
    });

    test('is a draft pre-release, made with the gh CLI and GITHUB_TOKEN', () {
      expect((release['env'] as YamlMap)['GH_TOKEN'], r'${{ github.token }}');
      final draft = run('release', 'Draft the pre-release with the files').replaceAll(RegExp(r'\\\n\s*'), '');
      expect(
        draft,
        contains(r'gh release create "$TAG" --repo "$GITHUB_REPOSITORY" --verify-tag --draft --prerelease '
            r'--title "Shnayim Mikrah $TAG (preview)" --notes-file "$RUNNER_TEMP/notes.md" "${assets[@]}"'),
      );
      // Run again for the tag: the draft gets the new files, and keeps its
      // notes; a published release is left alone.
      expect(draft, contains(r'gh release upload "$TAG" --repo "$GITHUB_REPOSITORY" --clobber "${assets[@]}"'));
      expect(draft, contains('is published already'));
      // No third-party release action.
      final actions = {
        for (final job in jobs.values.cast<YamlMap>())
          for (final step in steps(job))
            if (step['uses'] case final String action) action.split('@').first,
      };
      expect(actions.where((action) => !action.startsWith('actions/')), unorderedEquals(['subosito/flutter-action', 'gradle/actions/setup-gradle']));
    });

    test('its notes say what the preview is, how to install it, and what to keep in mind', () {
      final notes = File('.github/prerelease_notes.md').readAsStringSync();
      expect(run('release', 'The notes'), contains('.github/prerelease_notes.md > "\$RUNNER_TEMP/notes.md"'));
      expect(notes, startsWith('A preview of Shnayim Mikrah'));
      expect(notes, contains('```powershell\n$oneLiner\n```'));
      for (final file in ['windows-x64.msi', 'windows-x64.zip', 'android-webapp.apk']) {
        expect(notes, contains('ShnayimMikrah-{{VERSION}}-$file'));
      }
      expect(notes, contains('**https://shnayimmikrah.org/**'));
      expect(notes, contains('add it to your home screen'));
      expect(notes, contains('The community is coming soon.'));
      expect(notes, contains('*Settings → Your data*'));
      expect(notes, contains("This preview's Android APK and later ones are signed with different keys"));
      expect(notes, contains('export a backup'));
      expect(notes, contains('uninstall this app, then install the new one'));
      // The key's paragraph that applies, the throwaway's or the
      // permanent's, from the TWA job.
      for (final marker in ['throwaway-key', 'permanent-key']) {
        expect(notes, contains('<!-- $marker -->\n'));
        expect(notes, contains('<!-- /$marker -->\n'));
      }
      expect((step(release, 'The notes')['env'] as YamlMap)['THROWAWAY'], r'${{ needs.twa.outputs.throwaway }}');
    });
  });

  test("the actions CI uses too are CI's versions", () {
    Map<String, String> versions(Iterable<YamlMap> jobs) => {
          for (final job in jobs)
            for (final step in steps(job))
              if (step['uses'] case final String action) action.split('@').first: action.split('@').last,
        };
    final mine = versions(jobs.values.cast<YamlMap>());
    final theirs = versions(ciJobs.values.cast<YamlMap>());
    for (final action in mine.keys.where(theirs.containsKey)) {
      expect(mine[action], theirs[action], reason: action);
    }
    expect(mine.keys.where(theirs.containsKey), containsAll(['actions/checkout', 'actions/upload-pages-artifact', 'actions/deploy-pages']));
  });

  group('Publish pre-release', () {
    final publishSource = File('.github/workflows/publish_prerelease.yml').readAsStringSync();
    final publish = loadYaml(publishSource) as YamlMap;
    final publishJob = (publish['jobs'] as YamlMap)['publish'] as YamlMap;
    String publishRun(String name) => step(publishJob, name)['run'] as String;

    test('runs by hand for a tag, after any build of the same tag', () {
      final on = publish['on'] as YamlMap;
      expect(on.keys, ['workflow_dispatch']);
      expect(((on['workflow_dispatch'] as YamlMap)['inputs'] as YamlMap).keys, ['tag']);
      // The Pre-release workflow's group: never while it uploads the files.
      expect((publish['concurrency'] as YamlMap)['group'], r'prerelease-${{ inputs.tag }}');
      expect((workflow['concurrency'] as YamlMap)['group'], startsWith('prerelease-'));
      expect(publish['permissions'], {'contents': 'read'});
      expect(publishJob['permissions'], {'contents': 'write'});
      expect((publishJob['env'] as YamlMap)['GH_TOKEN'], r'${{ github.token }}');
    });

    test("publishes only a draft pre-release whose files match its sums", () {
      final draft = publishRun('The draft');
      expect(draft, contains(r'^v0\.[0-9]+\.[0-9]+$'));
      expect(draft, contains('"true true") ;;'));
      final files = publishRun('Its files and their SHA-256 sums');
      for (final asset in assets) {
        expect(files, contains('"${asset.replaceAll(r'$VERSION', r'$version')}"'.replaceAll('"install.ps1"', 'install.ps1')));
      }
      expect(files, contains('sha256sum --check --strict SHA256SUMS.txt'));
      expect(publishRun("The one-liner's script"), contains('contents/tool/windows/install.ps1'));
      final names = steps(publishJob).map((step) => step['name']).toList();
      expect(names.last, 'Publish it');
      expect(publishRun('Publish it'), contains(r'gh release edit "$TAG" --repo "$GITHUB_REPOSITORY" --draft=false --prerelease'));
      // Only GitHub's own CLI: no actions at all.
      expect(steps(publishJob).where((step) => step['uses'] != null), isEmpty);
    });

    test('docs/RELEASE.md says to run it', () {
      expect(File('docs/RELEASE.md').readAsStringSync(), contains('*Actions → Publish pre-release → Run workflow*'));
    });
  });

  test('docs/RELEASE.md names every variable and secret it reads', () {
    final release = File('docs/RELEASE.md').readAsStringSync();
    final names = {...referenced('vars'), ...referenced('secrets')};
    expect(names, containsAll(['ANDROID_TWA_KEYSTORE_BASE64', 'ANDROID_TWA_KEYSTORE_PASSWORD']));
    expect(names.where((name) => !release.contains('`$name`')), isEmpty);
  });
}
