import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/services/home_widget_sync.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';

/// The native side of the home-screen widgets (lib/services/home_widget_sync.dart),
/// which no Dart test runs and this machine can't build: checked here against
/// the Dart side and the design tokens, and for structure, so that CI's
/// Android and iOS builds find them whole.
void main() {
  const res = 'android/app/src/main/res';
  const kotlin = 'android/app/src/main/kotlin/org/shnayimmikra/shnayim_mikra';
  final provider = File('$kotlin/ParshaWidgetProvider.kt').readAsStringSync();
  final swift = File('ios/ParshaWidget/ParshaWidget.swift').readAsStringSync();

  /// Every key the timeline's JSON has, at any level.
  final payloadKeys = <String>{};
  void collect(Object? json) {
    if (json is Map) {
      payloadKeys.addAll(json.keys.cast<String>());
      json.values.forEach(collect);
    } else if (json is List) {
      json.forEach(collect);
    }
  }

  collect(WidgetTimeline(
    rtl: false,
    stale: '',
    weeks: const [
      WidgetWeek(
          id: '', hebrew: '', name: '', spoken: '', progress: '', spokenProgress: '', mikra1: 0, mikra2: 0, targum: 0, next: ''),
    ],
    days: const [],
    rests: {LocalDate(2026, 10, 24): ''},
  ).toJson());
  collect(WidgetDay(
    date: LocalDate(2026, 10, 9),
    until: DateTime(2026, 10, 9, 12),
    week: 0,
    kind: WidgetDayKind.weekday,
    eyebrow: '',
    line: '',
  ).toJson());

  test('both widgets open the links the app gives them, in its own scheme', () {
    final json = jsonDecode(const WidgetTimeline(rtl: false, stale: '', weeks: [], days: []).encode()) as Map;
    expect(json['open'], startsWith('${WidgetLink.scheme}://widget/'));
    expect(json['continue'], startsWith('${WidgetLink.scheme}://widget/'));
    // home_widget hands iOS's app only links marked as the widget's.
    expect(Uri.parse(json['open'] as String).queryParameters, contains('homeWidget'));
    expect(provider, contains('openLink = timeline.openLink'));
    expect(provider, contains('continueLink = timeline.continueLink'));
    expect(provider, contains('launch(context, content.openLink)'));
    expect(provider, contains('launch(context, content.continueLink)'));
    expect(swift, contains('.widgetURL(URL(string: timeline.open))'));
    expect(swift, contains('URL(string: timeline.continueLink)'));
    for (final native in [provider, swift]) {
      expect(native, isNot(contains('${WidgetLink.scheme}://')));
    }
  });

  test("both widgets turn their day at 3 a.m., as the app's does", () {
    expect(rolloverDate(DateTime(2026, 10, 10, 2, 59)), LocalDate(2026, 10, 9));
    expect(rolloverDate(DateTime(2026, 10, 10, 3)), LocalDate(2026, 10, 10));
    expect(provider, contains('const val DAY_STARTS_AT_HOUR = 3'));
    expect(swift, contains('private let dayStartsAtHour = 3'));

    // Three hours after midnight by the hours that pass, as rolloverDate
    // counts them, rather than at 3 o'clock: on the night the clocks go
    // forward, 3 o'clock comes two hours after midnight.
    expect(provider, contains('fun appDate(time: Long) = dateOf(time - DAY_STARTS_AT_HOUR * HOUR_MS)'));
    expect(provider, contains('val turn = midnight.timeInMillis + DAY_STARTS_AT_HOUR * HOUR_MS + TURN_DELAY_MS'));
    expect(provider, isNot(contains('set(Calendar.HOUR_OF_DAY, DAY_STARTS_AT_HOUR)')));
    expect(swift, contains('localDate(date.addingTimeInterval(-Double(dayStartsAtHour) * 3600))'));
    expect(swift, contains('var midnight = calendar.startOfDay(for: yesterday)'));
    expect(swift, contains('let turn = midnight.addingTimeInterval(TimeInterval(dayStartsAtHour * 3600 + 5))'));
    expect(swift, isNot(contains('bySettingHour')));
  });

  test('past their days, both widgets still rest on Shabbat and Yom Tov', () {
    expect(provider, contains('timeline.rests[appDate(now)]'));
    expect(provider, contains('date in timeline.rests'));
    expect(swift, contains('rests?[appDate(date)]'));
    expect(swift, contains('rests[date] != nil'));
  });

  group('Android', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    /// The element of [manifest] named [name], from its opening tag to its
    /// close.
    String element(String tag, String name) =>
        RegExp('<$tag\\s[^>]*android:name="${RegExp.escape(name)}"[^>]*>.*?</$tag>', dotAll: true)
            .firstMatch(manifest)![0]!;

    /// The names defined in res/values*/ files of [type] ("color", "string",
    /// "dimen", "style"), by folder.
    Map<String, Set<String>> defined(String type) => {
          for (final dir in Directory(res).listSync().whereType<Directory>().where((d) => d.path.contains('/values')))
            dir.path.split('/').last: {
              for (final file in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.xml')))
                for (final m in RegExp('<$type\\s+name="([^"]+)"').allMatches(file.readAsStringSync())) m[1]!,
            },
        };

    test('the provider is registered, not exported, with its widget info', () {
      expect(kAndroidWidgetProvider, 'org.shnayimmikra.shnayim_mikra.ParshaWidgetProvider');
      expect(provider, contains('package org.shnayimmikra.shnayim_mikra'));
      expect(provider, contains('class ParshaWidgetProvider : HomeWidgetProvider()'));
      final receiver = element('receiver', '.ParshaWidgetProvider');
      expect(receiver, contains('android:exported="false"'));
      expect(receiver, contains('android:label="@string/widget_label"'));
      expect(receiver, contains('<action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>'));
      expect(receiver, contains('android:resource="@xml/parsha_widget_info"'));
      expect(File('$res/xml/parsha_widget_info.xml').existsSync(), isTrue);
    });

    test('its scheduled updates survive a reboot, with no exact-alarm permission', () {
      final receiver = element('receiver', 'es.antonborri.home_widget.HomeWidgetScheduledUpdateReceiver');
      expect(receiver, contains('android:exported="false"'));
      for (final action in ['android.intent.action.BOOT_COMPLETED', 'android.intent.action.MY_PACKAGE_REPLACED']) {
        expect(receiver, contains('<action android:name="$action"/>'));
      }
      expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
      expect(manifest, isNot(contains('SCHEDULE_EXACT_ALARM"')));
      expect(manifest, isNot(contains('USE_EXACT_ALARM')));
      expect(provider, contains('HomeWidgetScheduler.schedule(context, provider, times)'));
    });

    test("a tap opens the app's own link, and only home_widget routes it", () {
      final activity = element('activity', '.MainActivity');
      expect(activity, contains('<action android:name="es.antonborri.home_widget.action.LAUNCH"/>'));
      // Flutter would otherwise push the link as a route as well.
      expect(activity, contains('android:name="flutter_deeplinking_enabled"'));
      expect(activity, contains('android:value="false"'));

      // A recreated activity forgets the tap that started it, by home_widget's
      // own action.
      final config = File('.dart_tool/package_config.json');
      final packages = (jsonDecode(config.readAsStringSync()) as Map<String, dynamic>)['packages'] as List;
      final plugin = packages.cast<Map<String, dynamic>>().firstWhere((p) => p['name'] == 'home_widget');
      final root = config.absolute.uri.resolve('${plugin['rootUri']}/');
      final intent =
          File.fromUri(root.resolve('android/src/main/kotlin/es/antonborri/home_widget/HomeWidgetIntent.kt'))
              .readAsStringSync();
      expect(intent, contains('const val HOME_WIDGET_LAUNCH_ACTION = "es.antonborri.home_widget.action.LAUNCH"'));
      final mainActivity = File('$kotlin/MainActivity.kt').readAsStringSync();
      expect(mainActivity, contains('intent.action == HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION'));
      expect(mainActivity, contains('intent.data = null'));
    });

    test('the widget info: resizable from 2×2, opening at 4×2, with a preview and a description', () {
      final info = File('$res/xml/parsha_widget_info.xml').readAsStringSync();
      String attribute(String name) => RegExp('android:$name="([^"]*)"').firstMatch(info)![1]!;
      expect(attribute('initialLayout'), '@layout/widget_parsha_medium');
      expect(attribute('previewLayout'), '@layout/widget_parsha_preview');
      expect(attribute('previewImage'), '@drawable/widget_preview');
      expect(attribute('description'), '@string/widget_description');
      expect((attribute('targetCellWidth'), attribute('targetCellHeight')), ('4', '2'));
      expect((attribute('minResizeWidth'), attribute('minResizeHeight')), ('110dp', '110dp'));
      expect(attribute('resizeMode'), 'horizontal|vertical');
      expect(attribute('updatePeriodMillis'), '3600000');
      for (final layout in ['widget_parsha_small', 'widget_parsha_medium', 'widget_parsha_preview']) {
        expect(File('$res/layout/$layout.xml').existsSync(), isTrue, reason: layout);
      }
      expect(File('$res/drawable-nodpi/widget_preview.png').existsSync(), isTrue);
    });

    test('every resource the widget names is defined, in both languages and themes', () {
      final files = [
        for (final dir in ['layout', 'drawable', 'drawable-v31', 'xml'])
          for (final f in Directory('$res/$dir').listSync().whereType<File>())
            if (f.path.contains('widget')) f,
        File('$res/values/widget_styles.xml'),
        File('$res/values-iw/widget_styles.xml'),
      ];
      final colors = defined('color');
      final strings = defined('string');
      final dimens = defined('dimen');
      final styles = defined('style');
      final drawables = {
        for (final dir in Directory(res).listSync().whereType<Directory>().where((d) => d.path.contains('/drawable')))
          for (final f in dir.listSync().whereType<File>()) f.uri.pathSegments.last.split('.').first,
      };
      final layouts = {for (final f in Directory('$res/layout').listSync()) f.uri.pathSegments.last.split('.').first};
      for (final file in files) {
        final xml = file.readAsStringSync();
        for (final m in RegExp(r'@(color|string|dimen|style|drawable|layout)/([A-Za-z0-9_.]+)').allMatches(xml)) {
          final (type, name) = (m[1]!, m[2]!);
          final where = '${file.path}: @$type/$name';
          switch (type) {
            case 'color':
              expect(colors['values']!.contains(name), isTrue, reason: where);
              expect(colors['values-night']!.contains(name), isTrue, reason: '$where (dark)');
            case 'string':
              expect(strings['values']!.contains(name), isTrue, reason: where);
            case 'dimen':
              expect(dimens['values']!.contains(name), isTrue, reason: where);
            case 'style':
              expect(styles['values']!.contains(name), isTrue, reason: where);
            case 'drawable':
              expect(drawables.contains(name), isTrue, reason: where);
            case 'layout':
              expect(layouts.contains(name), isTrue, reason: where);
          }
        }
      }
      // Each string the widget shows itself, in Hebrew too.
      final values = File('$res/values/strings.xml').readAsStringSync();
      for (final m in RegExp(r'<string name="(widget_[a-z_]+)"(?! translatable="false")').allMatches(values)) {
        expect(strings['values-iw']!.contains(m[1]), isTrue, reason: m[1]);
      }
      expect(strings['values']!.containsAll(['widget_label', 'widget_description', 'widget_empty']), isTrue);
    });

    test('the provider uses only views its layouts have, and reads only what the app sends', () {
      final ids = {
        for (final f in Directory('$res/layout').listSync().whereType<File>().where((f) => f.path.contains('widget_parsha')))
          for (final m in RegExp(r'@\+id/(\w+)').allMatches(f.readAsStringSync())) m[1]!,
      };
      for (final m in RegExp(r'(?<!android\.)R\.id\.(\w+)').allMatches(provider)) {
        expect(ids.contains(m[1]), isTrue, reason: 'R.id.${m[1]}');
      }
      final small = File('$res/layout/widget_parsha_small.xml').readAsStringSync();
      final medium = File('$res/layout/widget_parsha_medium.xml').readAsStringSync();
      for (final layout in [small, medium]) {
        // The launcher's transition and the card's tap and description.
        expect(layout, contains('android:id="@android:id/background"'));
        expect(layout, contains('android:importantForAccessibility="noHideDescendants"'));
      }
      // Continue, and today's reading, at the medium size only.
      expect(medium, contains('@+id/widget_continue'));
      expect(small, isNot(contains('@+id/widget_continue')));

      expect(provider, contains('const val TIMELINE_KEY = "$kWidgetTimelineKey"'));
      final read = {
        for (final m in RegExp(r'\b(?:getString|getInt|getLong|getJSONArray|getJSONObject|optJSONObject|optBoolean|has)\("(\w+)"')
            .allMatches(provider))
          m[1]!,
      };
      expect(read, containsAll(['weeks', 'days', 'rest']));
      expect(payloadKeys.containsAll(read), isTrue, reason: '${read.difference(payloadKeys)}');
    });

    test('the provider measures the lines by the dimensions the layouts set them in', () {
      final styles = File('$res/values/widget_styles.xml').readAsStringSync();
      final dimens = {
        for (final m in RegExp(r'<dimen name="(\w+)">([\d.]+)(dp|sp)</dimen>').allMatches(styles)) m[1]!: (m[2]!, m[3]!),
      };
      final measured = {for (final m in RegExp(r'R\.dimen\.(\w+)').allMatches(provider)) m[1]!};
      expect(measured, containsAll(['widget_padding', 'widget_hebrew_box', 'widget_greeting_box', 'widget_tap']));
      expect(dimens.keys, containsAll(measured));

      /// The item [name] of style [style], following its parents by name.
      String? item(String style, String name) {
        for (var s = style; s.contains('.'); s = s.substring(0, s.lastIndexOf('.'))) {
          final body = RegExp('<style name="${RegExp.escape(s)}"[^>]*>(.*?)</style>', dotAll: true).firstMatch(styles)?[1];
          final value = RegExp('<item name="android:$name">([^<]*)</item>').firstMatch(body ?? '')?[1];
          if (value != null) return value;
        }
        return null;
      }

      // Each line in a box of its own, in sp so that it grows with the
      // system's text size, which the provider adds up.
      for (final (style, box) in [
        ('ParshaWidget.Text.Fitted.Eyebrow', 'widget_eyebrow_box'),
        ('ParshaWidget.Text.Fitted.Eyebrow.Hebrew', 'widget_eyebrow_box_hebrew'),
        ('ParshaWidget.Text.Fitted.Hebrew', 'widget_hebrew_box'),
        ('ParshaWidget.Text.Fitted.Name', 'widget_name_box'),
        ('ParshaWidget.Text.Fitted.Progress', 'widget_progress_box'),
        ('ParshaWidget.Text.Fitted.Greeting', 'widget_greeting_box'),
      ]) {
        expect(item(style, 'layout_height'), '@dimen/$box', reason: style);
        expect(dimens[box]!.$2, 'sp', reason: box);
        expect(measured, contains(box));
        expect(item(style, 'autoSizeTextType'), 'uniform', reason: style);
      }
      // Gaps in dp, in the styles and layouts alike.
      expect(item('ParshaWidget.Text.Fitted.Hebrew', 'layout_marginTop'), '@dimen/widget_title_gap');
      expect(item('ParshaWidget.Text.Fitted.Progress', 'layout_marginTop'), '@dimen/widget_line_gap');
      expect(item('ParshaWidget.Text.Continue', 'layout_marginTop'), '@dimen/widget_line_gap');
      expect(item('ParshaWidget.Text.Continue', 'minHeight'), '@dimen/widget_tap');
      for (final layout in ['widget_parsha_small', 'widget_parsha_medium']) {
        final xml = File('$res/layout/$layout.xml').readAsStringSync();
        expect(RegExp(r'android:layout_(?:height|margin\w*)="[1-9]').hasMatch(xml), isFalse, reason: '$layout: a size of its own');
        expect(xml, contains('android:layout_marginTop="@dimen/widget_section_gap"'), reason: layout);
      }

      // The greeting in whole words, never cut short: in two lines, or three
      // at a narrow widget's smallest sizes, which the box holds.
      expect(item('ParshaWidget.Text.Fitted.Greeting', 'maxLines'), '3');
      expect(item('ParshaWidget.Text.Fitted.Greeting', 'ellipsize'), 'none');
      expect(dimens['widget_greeting_box'], ('40', 'sp'));

      // Its smallest size and the medium layout's width are the widget info's.
      final info = File('$res/xml/parsha_widget_info.xml').readAsStringSync();
      String attribute(String name) => RegExp('android:$name="([^"]*)"').firstMatch(info)![1]!;
      expect(provider, contains('const val MIN_SIZE_DP = ${attribute('minResizeHeight').replaceAll('dp', '')}f'));
      expect(attribute('minResizeWidth'), attribute('minResizeHeight'));
      expect(provider, contains('const val MEDIUM_WIDTH_DP = ${attribute('minWidth').replaceAll('dp', '')}f'));
    });

    test("the colours are the design system's, light and dark", () {
      Map<String, String> colours(String dir) => {
            for (final m in RegExp(r'<color name="(widget_\w+)">#([0-9A-Fa-f]{6})</color>')
                .allMatches(File('$res/$dir/widget_colors.xml').readAsStringSync()))
              m[1]!: m[2]!.toUpperCase(),
          };
      expect(colours('values'), _tokens(light: true, prefix: 'widget_'));
      expect(colours('values-night'), _tokens(light: false, prefix: 'widget_'));
    });
  });

  group('iOS', () {
    final pbxproj = Pbxproj(File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync());

    test('the project file is whole: every object defined once, referenced objects exist, sections sorted', () {
      expect(pbxproj.duplicates, isEmpty);
      expect(pbxproj.dangling, isEmpty);
      for (final MapEntry(key: section, value: ids) in pbxproj.sections.entries) {
        expect(ids, [...ids]..sort(), reason: '$section is sorted');
        for (final id in ids) {
          expect(pbxproj.isa(id), section, reason: '$id in $section');
        }
      }
      // Balanced, so that Xcode can read it at all.
      final text = pbxproj.text.replaceAll(RegExp(r'"(?:[^"\\]|\\.)*"'), '');
      expect('{'.allMatches(text).length, '}'.allMatches(text).length);
      expect('('.allMatches(text).length, ')'.allMatches(text).length);
    });

    test('the widget is an app extension, built and embedded with the app', () {
      final target = pbxproj.target('ParshaWidget')!;
      expect(pbxproj.field(target, 'productType'), '"com.apple.product-type.app-extension"');
      final product = pbxproj.field(target, 'productReference')!;
      expect(pbxproj.field(product, 'path'), 'ParshaWidget.appex');
      expect(pbxproj.field(product, 'explicitFileType'), '"wrapper.app-extension"');
      expect(pbxproj.list(pbxproj.rootObject, 'targets'), contains(target));

      final runner = pbxproj.target('Runner')!;
      final dependency = pbxproj.list(runner, 'dependencies').single;
      expect(pbxproj.field(dependency, 'target'), target);
      expect(pbxproj.field(pbxproj.field(dependency, 'targetProxy')!, 'remoteGlobalIDString'), target);

      // Embedded in the app's PlugIns, before Thin Binary (after it, Xcode
      // finds a cycle).
      final phases = pbxproj.list(runner, 'buildPhases');
      final embed = phases.singleWhere((p) => pbxproj.field(p, 'name') == '"Embed Foundation Extensions"');
      expect(pbxproj.field(embed, 'dstSubfolderSpec'), '13');
      final file = pbxproj.list(embed, 'files').single;
      expect(pbxproj.field(file, 'fileRef'), product);
      final thin = phases.indexWhere((p) => pbxproj.field(p, 'name') == '"Thin Binary"');
      expect(phases.indexOf(embed), lessThan(thin));
    });

    test("its build settings mirror the app's, with no signing of its own", () {
      final configs = pbxproj.list(pbxproj.field(pbxproj.target('ParshaWidget')!, 'buildConfigurationList')!,
          'buildConfigurations');
      final runnerConfigs =
          pbxproj.list(pbxproj.field(pbxproj.target('Runner')!, 'buildConfigurationList')!, 'buildConfigurations');
      String name(String id) => pbxproj.field(id, 'name')!;
      expect([for (final c in configs) name(c)], [for (final c in runnerConfigs) name(c)]);
      for (final config in configs) {
        final settings = pbxproj.settings(config);
        final runner = pbxproj.settings(runnerConfigs.firstWhere((c) => name(c) == name(config)));
        expect(settings['PRODUCT_BUNDLE_IDENTIFIER'], '${runner['PRODUCT_BUNDLE_IDENTIFIER']}.ParshaWidget');
        expect(settings['PRODUCT_BUNDLE_IDENTIFIER'], 'org.shnayimmikra.app.ParshaWidget');
        expect(settings['IPHONEOS_DEPLOYMENT_TARGET'], '15.0');
        expect(settings['SKIP_INSTALL'], 'YES');
        expect(settings['INFOPLIST_FILE'], 'ParshaWidget/Info.plist');
        expect(settings['CODE_SIGN_ENTITLEMENTS'], 'ParshaWidget/ParshaWidget.entitlements');
        expect(runner['CODE_SIGN_ENTITLEMENTS'], 'Runner/Runner.entitlements');
        // Its version is the app's, from Flutter's xcconfig.
        expect(pbxproj.field(config, 'baseConfigurationReference'), pbxproj.field(
            runnerConfigs.firstWhere((c) => name(c) == name(config)), 'baseConfigurationReference'));
        for (final key in settings.keys) {
          expect(key.startsWith('CODE_SIGN') && key != 'CODE_SIGN_ENTITLEMENTS', isFalse, reason: key);
          expect(key, isNot(anyOf('DEVELOPMENT_TEAM', 'PROVISIONING_PROFILE_SPECIFIER')));
        }
      }
      for (final file in ['ios/ParshaWidget/Info.plist', 'ios/ParshaWidget/ParshaWidget.entitlements', 'ios/Runner/Runner.entitlements']) {
        expect(File(file).existsSync(), isTrue, reason: file);
      }
    });

    test("every file the extension builds is on disk", () {
      final target = pbxproj.target('ParshaWidget')!;
      final group = pbxproj.groupNamed('ParshaWidget')!;
      expect(pbxproj.list(pbxproj.mainGroup, 'children'), contains(group));
      for (final phase in pbxproj.list(target, 'buildPhases')) {
        for (final file in pbxproj.list(phase, 'files')) {
          final ref = pbxproj.field(file, 'fileRef')!;
          for (final path in pbxproj.pathsOf(ref, 'ParshaWidget')) {
            expect(FileSystemEntity.typeSync('ios/$path'), isNot(FileSystemEntityType.notFound), reason: path);
          }
        }
      }
    });

    test('the App Group, the key and the kind are the Dart side’s', () {
      for (final file in ['ios/Runner/Runner.entitlements', 'ios/ParshaWidget/ParshaWidget.entitlements']) {
        final plist = File(file).readAsStringSync();
        expect(plist, contains('<key>com.apple.security.application-groups</key>'), reason: file);
        expect(plist, contains('<string>$kWidgetAppGroup</string>'), reason: file);
      }
      expect(swift, contains('private let appGroup = "$kWidgetAppGroup"'));
      expect(swift, contains('private let timelineKey = "$kWidgetTimelineKey"'));
      expect(swift, contains('let kind = "$kIOSWidgetKind"'));
      expect(swift, contains('.supportedFamilies([.systemSmall, .systemMedium])'));
    });

    test('it reads only what the app sends', () {
      final structs = RegExp(r'struct (?:Week|Day): Decodable \{(.*?)\n  \}', dotAll: true).allMatches(swift);
      final fields = {
        for (final s in structs)
          for (final m in RegExp(r'^\s+let (\w+):', multiLine: true).allMatches(s[1]!)) m[1]!,
        'rtl', 'open', 'continue', 'stale', 'weeks', 'days', 'rest',
      };
      expect(fields, hasLength(greaterThan(12)));
      expect(payloadKeys.containsAll(fields), isTrue, reason: '${fields.difference(payloadKeys)}');
      expect(swift, contains('case continueLink = "continue"'));
      expect(swift, contains('case rests = "rest"'));
      expect(swift, contains('let rests: [String: String]?'));
      // Optional where the app may leave them out.
      expect(swift, contains('let next: String?'));
      expect(swift, contains('let until: Double?'));
    });

    test('the extension registers the fonts it names, which are the app’s', () {
      final info = File('ios/ParshaWidget/Info.plist').readAsStringSync();
      final appFonts = RegExp(r'<key>UIAppFonts</key>\s*<array>(.*?)</array>', dotAll: true).firstMatch(info)![1]!;
      final registered = [for (final m in RegExp(r'<string>([^<]+)</string>').allMatches(appFonts)) m[1]!];
      final bundled = [
        for (final phase in pbxproj.list(pbxproj.target('ParshaWidget')!, 'buildPhases'))
          for (final file in pbxproj.list(phase, 'files'))
            if ((pbxproj.field(pbxproj.field(file, 'fileRef')!, 'name') ?? '').endsWith('.ttf"'))
              pbxproj.field(pbxproj.field(file, 'fileRef')!, 'name')!.replaceAll('"', ''),
      ];
      expect(registered..sort(), bundled..sort());
      final named = {for (final m in RegExp(r'"((?:FrankRuhlLibre|EBGaramond)-\w+)"').allMatches(swift)) m[1]!};
      expect(named, {'FrankRuhlLibre-Medium', 'FrankRuhlLibre-SemiBold', 'EBGaramond-Medium'});
      // Font.custom takes a font's PostScript name.
      expect({for (final font in registered) _postScriptName(File('assets/fonts/$font'))}, named);
    });

    test('its strings are in English and Hebrew', () {
      Map<String, String> strings(String language) => {
            for (final m in RegExp(r'^"([\w.]+)" = "((?:[^"\\]|\\.)*)";$', multiLine: true)
                .allMatches(File('ios/ParshaWidget/$language.lproj/Localizable.strings').readAsStringSync()))
              m[1]!: m[2]!,
          };
      final en = strings('en');
      final he = strings('he');
      expect(he.keys.toSet(), en.keys.toSet());
      final used = {
        for (final m in RegExp(r'NSLocalizedString\("([\w.]+)"').allMatches(swift)) m[1]!,
        for (final m in RegExp(r'\.(?:configurationDisplayName|description)\("([\w.]+)"\)').allMatches(swift)) m[1]!,
      };
      expect(used, containsAll(['widget.name', 'widget.description', 'widget.empty']));
      expect(en.keys.toSet().containsAll(used), isTrue, reason: '${used.difference(en.keys.toSet())}');
    });

    test("its text follows the reader's text size, to the largest standard size", () {
      // The serifs (Font.custom(_:size:)) are scaled by the system, and the
      // system's lines by @ScaledMetric: a literal size, or a fixed one,
      // would hold a line at the default text size while the names grow.
      expect(RegExp(r'\.system\(size: \d').hasMatch(swift), isFalse);
      expect(swift, isNot(contains('fixedSize:')));
      expect(RegExp(r'@ScaledMetric\(relativeTo: \.\w+\)').allMatches(swift), isNotEmpty);
      // Beyond it the small widget has no room. Held outside the view, so
      // that its own scaled sizes are held too.
      expect(swift, contains('ParshaWidgetView(entry: entry)\n        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)'));
    });

    test('its privacy manifest declares each reason it reads what the system asks one for', () {
      const path = 'ios/ParshaWidget/PrivacyInfo.xcprivacy';
      final manifest = File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), '');
      expect(manifest, startsWith('<?xmlversion="1.0"encoding="UTF-8"?><!DOCTYPEplist'));
      expect(manifest, contains('<key>NSPrivacyTracking</key><false/>'));
      expect(manifest, contains('<key>NSPrivacyTrackingDomains</key><array/>'));
      expect(manifest, contains('<key>NSPrivacyCollectedDataTypes</key><array/>'));
      // Apple's required-reason APIs the extension might call, and the reason
      // each is called for: the user defaults of the App Group it shares
      // with the app (1C8F.1).
      const apis = {
        'UserDefaults': ('NSPrivacyAccessedAPICategoryUserDefaults', '1C8F.1'),
        'systemUptime': ('NSPrivacyAccessedAPICategorySystemBootTime', null),
        'creationDate': ('NSPrivacyAccessedAPICategoryFileTimestamp', null),
        'modificationDate': ('NSPrivacyAccessedAPICategoryFileTimestamp', null),
        'volumeAvailableCapacity': ('NSPrivacyAccessedAPICategoryDiskSpace', null),
        'activeInputModes': ('NSPrivacyAccessedAPICategoryActiveKeyboards', null),
      };
      final used = {for (final MapEntry(:key, :value) in apis.entries) if (swift.contains(key)) value};
      expect(used, {('NSPrivacyAccessedAPICategoryUserDefaults', '1C8F.1')});
      final declared = RegExp(r'<key>NSPrivacyAccessedAPIType</key><string>(\w+)</string>'
              r'<key>NSPrivacyAccessedAPITypeReasons</key><array><string>([\w.]+)</string></array>')
          .allMatches(manifest)
          .map((m) => (m[1]!, m[2]!))
          .toSet();
      expect(declared, used);

      // Built into the extension's bundle.
      final resources = pbxproj.list(pbxproj.target('ParshaWidget')!, 'buildPhases')
          .singleWhere((phase) => pbxproj.isa(phase) == 'PBXResourcesBuildPhase');
      final files = [
        for (final file in pbxproj.list(resources, 'files'))
          ...pbxproj.pathsOf(pbxproj.field(file, 'fileRef')!, 'ParshaWidget'),
      ];
      expect(files, contains('ParshaWidget/PrivacyInfo.xcprivacy'));
      expect(File(path).existsSync(), isTrue);
    });

    test("the colours are the design system's, light and dark", () {
      final named = {for (final m in RegExp(r'Color\("(\w+)"\)').allMatches(swift)) m[1]!};
      Map<String, String> colours({required bool dark}) => {
            for (final name in named)
              name: () {
                final json = jsonDecode(File('ios/ParshaWidget/Assets.xcassets/$name.colorset/Contents.json')
                    .readAsStringSync()) as Map<String, dynamic>;
                final entry = (json['colors'] as List).cast<Map<String, dynamic>>().singleWhere(
                    (c) => (c['appearances'] != null) == dark);
                final c = (entry['color'] as Map)['components'] as Map;
                return [c['red'], c['green'], c['blue']].map((v) => (v as String).substring(2)).join().toUpperCase();
              }(),
          };
      expect(colours(dark: false), _tokens(light: true, prefix: 'Widget'));
      expect(colours(dark: true), _tokens(light: false, prefix: 'Widget'));
      expect(pbxproj.text, contains('ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME = WidgetPaper;'));
    });
  });
}

/// The widget's colours from the design tokens (lib/ui/theme/palette.dart),
/// as Android names them ("widget_paper") or iOS ("WidgetPaper").
Map<String, String> _tokens({required bool light, required String prefix}) {
  final scheme = light ? Palettes.light : Palettes.dark;
  final sefer = light ? Palettes.seferLight : Palettes.seferDark;
  String hex(Color c) => (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  final tokens = {
    'paper': sefer.paper,
    'hairline': sefer.hairline,
    'ink': scheme.onSurface,
    'ink_muted': scheme.onSurfaceVariant,
    'techelet': scheme.primary,
    'gold': scheme.secondary,
    'mikra1': sefer.ringMikra1,
    'mikra2': sefer.ringMikra2,
    'targum': sefer.ringTargum,
    'track': sefer.ringTrack,
  };
  String name(String token) => prefix == 'widget_'
      ? 'widget_$token'
      : 'Widget${token.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join()}';
  return {for (final MapEntry(:key, :value) in tokens.entries) name(key): hex(value)};
}

/// The PostScript name (name ID 6) of the TrueType font [file].
String _postScriptName(File file) {
  final data = ByteData.sublistView(file.readAsBytesSync());
  final tables = data.getUint16(4);
  for (var i = 0; i < tables; i++) {
    final record = 12 + i * 16;
    if (String.fromCharCodes(Uint8List.sublistView(data, record, record + 4)) != 'name') continue;
    final table = data.getUint32(record + 8);
    final count = data.getUint16(table + 2);
    final strings = table + data.getUint16(table + 4);
    for (var n = 0; n < count; n++) {
      final r = table + 6 + n * 12;
      final (platform, nameId) = (data.getUint16(r), data.getUint16(r + 6));
      if (platform != 3 || nameId != 6) continue;
      final length = data.getUint16(r + 8);
      final offset = strings + data.getUint16(r + 10);
      return String.fromCharCodes([for (var c = 0; c < length; c += 2) data.getUint16(offset + c)]);
    }
  }
  throw StateError('${file.path} has no PostScript name');
}

/// A light reading of an Xcode project file: its objects, by id, and their
/// fields as text.
class Pbxproj {
  Pbxproj(this.text) {
    final objectsAt = text.indexOf('objects = {');
    for (final m in RegExp(r'/\* Begin (\w+) section \*/\n(.*?)/\* End \1 section \*/', dotAll: true)
        .allMatches(text, objectsAt)) {
      final ids = <String>[];
      for (final o in RegExp(r'^\t\t([0-9A-F]{24}) (?:/\*.*?\*/ )?= \{', multiLine: true).allMatches(m[2]!)) {
        final id = o[1]!;
        ids.add(id);
        if (_bodies.containsKey(id)) duplicates.add(id);
        _bodies[id] = _bodyAt(m[2]!, o.end);
      }
      sections[m[1]!] = ids;
    }
  }

  final String text;
  final sections = <String, List<String>>{};
  final duplicates = <String>[];
  final _bodies = <String, String>{};

  /// The object body that begins at [start] (just after its opening brace),
  /// up to its matching close.
  static String _bodyAt(String s, int start) {
    var depth = 1;
    for (var i = start; i < s.length; i++) {
      if (s[i] == '{') depth++;
      if (s[i] == '}' && --depth == 0) return s.substring(start, i);
    }
    throw const FormatException('unbalanced object');
  }

  /// Ids referenced anywhere in an object that no object defines.
  Set<String> get dangling => {
        for (final body in _bodies.values)
          for (final m in RegExp(r'\b[0-9A-F]{24}\b').allMatches(body))
            if (!_bodies.containsKey(m[0])) m[0]!,
        if (!_bodies.containsKey(rootObject)) rootObject,
      };

  String get rootObject => RegExp(r'rootObject = ([0-9A-F]{24})').firstMatch(text)![1]!;

  String get mainGroup => field(rootObject, 'mainGroup')!;

  String? isa(String id) => field(id, 'isa');

  /// The value of [key] in object [id], as written, less any comment.
  String? field(String id, String key) {
    final m = RegExp('(?:^|[;{\\s])$key = ([^;]*);').firstMatch(_bodies[id] ?? '');
    return m?[1]!.replaceAll(RegExp(r'\s*/\*.*?\*/'), '').trim();
  }

  /// The ids listed under [key] in object [id].
  List<String> list(String id, String key) {
    final m = RegExp('$key = \\((.*?)\\);', dotAll: true).firstMatch(_bodies[id] ?? '');
    if (m == null) return const [];
    return [for (final i in RegExp(r'\b[0-9A-F]{24}\b').allMatches(m[1]!)) i[0]!];
  }

  /// The build settings of configuration [id], as written.
  Map<String, String> settings(String id) {
    final body = RegExp(r'buildSettings = \{(.*?)\n\t\t\t\};', dotAll: true).firstMatch(_bodies[id]!)![1]!;
    return {
      for (final m in RegExp(r'^\t\t\t\t("?[\w\[\]=*]+"?) = (.*?);$', multiLine: true).allMatches(body))
        m[1]!: m[2]!.replaceAll('"', ''),
    };
  }

  String? target(String name) => sections['PBXNativeTarget']!.where((t) => field(t, 'name') == name).firstOrNull;

  String? groupNamed(String path) => sections['PBXGroup']!.where((g) => field(g, 'path') == path).firstOrNull;

  /// The paths under ios/ of file reference [ref] (or each file of a
  /// variant group), whose group is [group].
  List<String> pathsOf(String ref, String group) {
    if (isa(ref) == 'PBXVariantGroup') return [for (final child in list(ref, 'children')) ...pathsOf(child, group)];
    final path = field(ref, 'path')!.replaceAll('"', '');
    return [if (field(ref, 'sourceTree') == 'SOURCE_ROOT') path else '$group/$path'];
  }
}
