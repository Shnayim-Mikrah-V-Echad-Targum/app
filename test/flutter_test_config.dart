import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

/// Runs before every test file (flutter_test picks this file up by name).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Every test starts as if the app had just launched. The parsha rings
  // remember, for the run of the app, what they last showed for each week;
  // left over from another test, that memory would make a test that shows
  // the same week sweep from the other test's progress, and pass or fail by
  // the order the tests run in.
  setUp(ParshaRings.forgetShown);
  await testMain();
}
