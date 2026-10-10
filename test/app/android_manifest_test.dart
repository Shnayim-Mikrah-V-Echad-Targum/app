import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// android/app/src/main/AndroidManifest.xml: predictive back, and a system
/// backup of the settings and progress alone.
void main() {
  const res = 'android/app/src/main/res';
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final application = RegExp(r'<application\b[^>]*>').firstMatch(manifest)![0]!;

  String? attribute(String name) => RegExp('android:$name="([^"]*)"').firstMatch(application)?[1];

  // Android 14 and later then preview the destination of a back gesture,
  // home included; the app's routes follow the gesture too (motion.dart).
  test('opts in to predictive back', () {
    expect(attribute('enableOnBackInvokedCallback'), 'true');
  });

  group('system backup', () {
    // shared_preferences keeps the settings and progress in this one file.
    const prefs = '<include domain="sharedpref" path="FlutterSharedPreferences.xml" />';

    String rules(String attributeName) {
      final reference = attribute(attributeName);
      expect(reference, startsWith('@xml/'), reason: attributeName);
      return File('$res/xml/${reference!.substring(5)}.xml').readAsStringSync();
    }

    test('is on', () {
      expect(attribute('allowBackup'), 'true');
    });

    test('Android 12 and later back up and transfer only the preferences', () {
      final xml = rules('dataExtractionRules');
      for (final section in ['cloud-backup', 'device-transfer']) {
        final body = RegExp('<$section>(.*?)</$section>', dotAll: true).firstMatch(xml)?[1];
        expect(body?.trim(), prefs, reason: section);
      }
    });

    test('Android 11 and earlier back up only the preferences', () {
      final body = RegExp('<full-backup-content>(.*?)</full-backup-content>', dotAll: true)
          .firstMatch(rules('fullBackupContent'))?[1];
      expect(body?.trim(), prefs);
    });
  });
}
