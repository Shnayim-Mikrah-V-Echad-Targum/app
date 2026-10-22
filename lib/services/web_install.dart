import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart' show sharedPreferencesProvider;
import 'web_install_stub.dart' if (dart.library.js_interop) 'web_install_web.dart' as platform;

/// The releases on GitHub, where the Android app (an APK, which opens this
/// website as an app) and the Windows installer (an MSI) are.
export 'updates/update_core.dart' show kReleasesPage;

/// The line that installs the Windows app, for PowerShell
/// (tool/windows/install.ps1). It isn't translated.
const kWindowsInstallCommand =
    'Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://shnayimmikrah.org/install.ps1 | iex';

/// How the browser's install dialog ended.
enum InstallOutcome { accepted, dismissed, unavailable }

/// The web app's ways onto the reader's device, by way of web/index.html,
/// which keeps the browser's offer to install it (beforeinstallprompt) in
/// window.smInstall. Off the web there are none: the app is installed.
class WebInstall {
  const WebInstall();

  /// Whether the browser has offered to install the app (Chrome and Edge,
  /// on Android and on computers), and the offer hasn't been made yet.
  bool get canPrompt => platform.promptAvailable();

  /// Whether the app was installed from this page since it opened.
  bool get installed => platform.installedNow();

  /// Whether the app runs as an installed app: from the home screen, in a
  /// window of its own, or as the Android app.
  bool get standalone => platform.runningStandalone();

  /// Asks the browser to install the app, which shows its own dialog.
  Future<InstallOutcome> prompt() async => switch (await platform.prompt()) {
        'accepted' => InstallOutcome.accepted,
        'dismissed' => InstallOutcome.dismissed,
        _ => InstallOutcome.unavailable,
      };

  /// Calls [onChange] as the offer comes or goes, or the app is installed;
  /// returns what stops listening.
  void Function() listen(void Function() onChange) => platform.listen(onChange);
}

/// The web's ways to install the app, or null off the web (and in the
/// tests, which replace it).
final webInstallProvider = Provider<WebInstall?>((ref) => kIsWeb ? const WebInstall() : null);

/// A way to install the app from the web (docs/DESIGN_SYSTEM.md §9 About,
/// Install the app).
enum InstallOption {
  /// The browser's own dialog: "Add to home screen" on a phone, "Install on
  /// this computer" on a computer.
  prompt,

  /// Safari's Add to Home Screen, which only the reader can choose: a sheet
  /// with the steps, on an iPhone or iPad.
  homeScreenSteps,

  /// The Android app, an APK on the releases page, which opens this website
  /// as an app.
  apk,

  /// The Windows app, installed with one line in PowerShell, or with the
  /// MSI on the releases page.
  windows,
}

/// The ways to install the app on a device of [platform], where the app
/// runs in a browser: none where it runs installed already ([standalone])
/// or has just been installed ([installed]). The browser's dialog comes
/// first where it is offered ([canPrompt]); then the device's own way: the
/// steps on an iPhone, the APK on Android, the one line in PowerShell on
/// Windows.
List<InstallOption> installOptionsFor(
  TargetPlatform platform, {
  required bool standalone,
  required bool installed,
  required bool canPrompt,
}) {
  if (standalone || installed) return const [];
  return [
    if (canPrompt && platform != TargetPlatform.iOS) InstallOption.prompt,
    ...switch (platform) {
      TargetPlatform.iOS => const [InstallOption.homeScreenSteps],
      TargetPlatform.android => const [InstallOption.apk],
      TargetPlatform.windows => const [InstallOption.windows],
      _ => const <InstallOption>[],
    },
  ];
}

/// The ways to install the app here ([installOptionsFor]), following the
/// browser's offer as it comes and goes: empty off the web, and in the app
/// installed.
class InstallOptions extends Notifier<List<InstallOption>> {
  @override
  List<InstallOption> build() {
    final install = ref.watch(webInstallProvider);
    if (install == null) return const [];
    ref.onDispose(install.listen(() => state = _options(install)));
    return _options(install);
  }

  List<InstallOption> _options(WebInstall install) => installOptionsFor(
        defaultTargetPlatform,
        standalone: install.standalone,
        installed: install.installed,
        canPrompt: install.canPrompt,
      );

  /// Shows the browser's install dialog, and says how it ended.
  Future<InstallOutcome> prompt() async {
    final install = ref.read(webInstallProvider);
    if (install == null) return InstallOutcome.unavailable;
    final outcome = await install.prompt();
    if (ref.mounted) state = _options(install);
    return outcome;
  }

  @override
  bool updateShouldNotify(List<InstallOption> previous, List<InstallOption> next) => !listEquals(previous, next);
}

final installOptionsProvider = NotifierProvider<InstallOptions, List<InstallOption>>(InstallOptions.new);

/// Whether Today's card offering to install the app has been put away on
/// this device. It is offered once: put away, it never comes back, and the
/// ways to install stay in About and Settings.
class InstallCardDismissed extends Notifier<bool> {
  /// Where it is kept: on this device alone (a backup doesn't carry it).
  static const storageKey = 'installCard.dismissed';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(storageKey) ?? false;

  void dismiss() {
    state = true;
    ref.read(sharedPreferencesProvider).setBool(storageKey, true);
  }
}

final installCardDismissedProvider = NotifierProvider<InstallCardDismissed, bool>(InstallCardDismissed.new);
