import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../ui/l10n.dart';
import 'feedback.dart';
import 'recent_errors.dart';

/// The app's version and build, "0.0.1 (1)", or empty where the platform
/// doesn't say.
final appVersionLabelProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } catch (_) {
    return '';
  }
});

/// Copies what has gone wrong ([recentErrors]), under the app's version, for
/// a message to us, then says so: About's Copy details for support, and the
/// same action wherever an error is told of, such as an update that couldn't
/// be prepared. The version is in hand once About's header or the page has
/// read it, so the copy is made at once, within the tap, as a browser may
/// require.
Future<void> copySupportDetails(BuildContext context, WidgetRef ref) async {
  final String version = ref.read(appVersionLabelProvider).value ?? await ref.read(appVersionLabelProvider.future);
  await Clipboard.setData(ClipboardData(text: recentErrors.report(version: version)));
  if (context.mounted) showStatus(context, context.l10n.supportDetailsCopied);
}
