import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Goldens are compared on Linux only, as CI renders them (ubuntu-latest, at
/// the Flutter version of .github/workflows/ci.yml): text renders a little
/// differently on each platform.
final goldensSkipped = !Platform.isLinux;

/// Compares goldens as [LocalFileComparator] does, but accepts an image that
/// differs from its golden in at most [tolerance] of its pixels (0.5%), so
/// that the antialiasing of glyph edges, which varies a little from one
/// machine to another, doesn't fail a test that changed nothing visible.
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(super.testFile, {this.tolerance = 0.005});

  /// The fraction of pixels that may differ.
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden));
    try {
      if (result.passed || result.diffPercent <= tolerance) return true;
      throw FlutterError(await generateFailureOutput(result, golden, basedir));
    } finally {
      result.dispose();
    }
  }
}

/// Compares this test file's goldens with a [TolerantGoldenComparator]
/// until its tests are done. Call it from `setUpAll`.
void useTolerantGoldens() {
  final previous = goldenFileComparator;
  // flutter test sets a LocalFileComparator for the file being run, which
  // resolves goldens against the file's directory: so does this one.
  if (previous is! LocalFileComparator) return;
  goldenFileComparator = TolerantGoldenComparator(previous.basedir.resolve('golden_test.dart'));
  addTearDown(() => goldenFileComparator = previous);
}
