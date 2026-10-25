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

  /// The browser the app runs in, as far as it says ([browserFrom]), for the
  /// guide to open at its steps.
  InstallBrowser? get browser => browserFrom(platform.userAgent(), brave: platform.isBrave());
}

/// A browser the guide to saving the app has steps for (install_app.dart).
/// Their names are their own, never translated.
enum InstallBrowser {
  safari('Safari'),
  chrome('Chrome'),
  samsung('Samsung Internet'),
  firefox('Firefox'),
  brave('Brave'),
  duckDuckGo('DuckDuckGo'),
  edge('Edge'),
  opera('Opera');

  const InstallBrowser(this.label);
  final String label;
}

/// A kind of device the guide has steps for.
enum InstallDevice { iphone, android, computer }

/// The device the app runs on, as the guide groups them.
InstallDevice installDeviceOf(TargetPlatform platform) => switch (platform) {
      TargetPlatform.iOS => InstallDevice.iphone,
      TargetPlatform.android => InstallDevice.android,
      _ => InstallDevice.computer,
    };

/// The browsers there are on [device], in the order the guide offers them:
/// the device's own first.
List<InstallBrowser> browsersOn(InstallDevice device) => switch (device) {
      InstallDevice.iphone => const [
          InstallBrowser.safari,
          InstallBrowser.chrome,
          InstallBrowser.firefox,
          InstallBrowser.brave,
          InstallBrowser.duckDuckGo,
          InstallBrowser.edge,
          InstallBrowser.opera,
        ],
      InstallDevice.android => const [
          InstallBrowser.chrome,
          InstallBrowser.samsung,
          InstallBrowser.firefox,
          InstallBrowser.brave,
          InstallBrowser.duckDuckGo,
          InstallBrowser.edge,
          InstallBrowser.opera,
        ],
      InstallDevice.computer => const [
          InstallBrowser.chrome,
          InstallBrowser.edge,
          InstallBrowser.brave,
          InstallBrowser.safari,
          InstallBrowser.firefox,
          InstallBrowser.opera,
        ],
    };

/// The browser a user agent names, where it names one: each puts its own
/// token beside those of the engine it shares (Chrome's, Safari's). Brave
/// names none of its own, and says so by [brave] (navigator.brave); on an
/// iPhone it can't be told from Safari. Null where it is none of these.
InstallBrowser? browserFrom(String userAgent, {bool brave = false}) {
  bool has(String token) => userAgent.contains(token);
  if (has('DuckDuckGo/') || has('Ddg/')) return InstallBrowser.duckDuckGo;
  if (has('SamsungBrowser/')) return InstallBrowser.samsung;
  if (has('EdgiOS/') || has('EdgA/') || has('Edg/')) return InstallBrowser.edge;
  if (has('OPiOS/') || has('OPT/') || has('OPR/')) return InstallBrowser.opera;
  if (has('FxiOS/') || has('Firefox/')) return InstallBrowser.firefox;
  if (brave) return InstallBrowser.brave;
  if (has('CriOS/') || has('Chrome/') || has('Chromium/')) return InstallBrowser.chrome;
  if (has('Safari/') || has('AppleWebKit/')) return InstallBrowser.safari;
  return null;
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

  /// The guide to saving the app from the browser's own menu, step by step
  /// for each browser and device (Safari, Chrome, Firefox, Brave,
  /// DuckDuckGo, Edge, Samsung Internet, Opera), which only the reader can
  /// do.
  guide,

  /// The Android app, an APK on the releases page, which opens this website
  /// as an app. Not offered while it is being made ready ([installOptionsFor]).
  apk,

  /// The Windows app, installed with one line in PowerShell, or with the
  /// MSI on the releases page.
  windows,
}

/// The ways to install the app on a device of [platform], where the app
/// runs in a browser: none where it runs installed already ([standalone])
/// or has just been installed ([installed]). The browser's dialog comes
/// first where it is offered ([canPrompt]); then the guide to saving it from
/// the browser's menu, on every device; then on Windows the one line in
/// PowerShell. The Android app (an APK) is left out until it is ready: the
/// guide saves the site from any Android browser meanwhile.
List<InstallOption> installOptionsFor(
  TargetPlatform platform, {
  required bool standalone,
  required bool installed,
  required bool canPrompt,
}) {
  if (standalone || installed) return const [];
  return [
    if (canPrompt && platform != TargetPlatform.iOS) InstallOption.prompt,
    InstallOption.guide,
    if (platform == TargetPlatform.windows) InstallOption.windows,
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
