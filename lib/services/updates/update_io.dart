// The Windows app's requests and installer handoff (see update_service.dart),
// on dart:io. The web build has update_stub.dart in its place, and never asks
// for either: updates are the Windows app's alone.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'update_core.dart';
import 'update_service.dart';

UpdateHttp createUpdateHttp() => IoUpdateHttp();

UpdateInstaller createUpdateInstaller() => const WindowsUpdateInstaller();

/// Ends the process, where closing the window didn't: install.ps1 waits for
/// it to exit before it installs.
Never forceExit() => exit(0);

/// [UpdateHttp] on dart:io's HttpClient, which follows no redirect by
/// itself, so that [fetchAllowed] checks each hop's host.
class IoUpdateHttp implements UpdateHttp {
  IoUpdateHttp()
      : _client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 20)
          ..idleTimeout = const Duration(seconds: 15)
          ..userAgent = kUpdateUserAgent;

  final HttpClient _client;

  /// How long an answer may take to begin, and how long it may pause.
  static const _answerTimeout = Duration(seconds: 30);
  static const _bodyTimeout = Duration(seconds: 60);

  @override
  Future<UpdateResponse> get(Uri uri, {required Map<String, String> headers, required int maxBytes}) async {
    // fetchAllowed checks every address first; this is the last word.
    if (!isAllowedUpdateUri(uri)) {
      throw UpdateException(UpdateFailure.disallowedHost, 'Refused to fetch ${uri.scheme}://${uri.host}');
    }
    try {
      final request = await _client.getUrl(uri).timeout(_answerTimeout);
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(_answerTimeout);
      final names = <String, String>{};
      response.headers.forEach((name, values) => names[name.toLowerCase()] = values.join(', '));
      if (response.statusCode != HttpStatus.ok) {
        // A redirect's or an error's body is never read.
        unawaited(response.drain<void>().catchError((Object _) {}));
        return UpdateResponse(response.statusCode, headers: names);
      }
      if (response.contentLength > maxBytes) {
        unawaited(response.drain<void>().catchError((Object _) {}));
        throw UpdateException(UpdateFailure.tooLarge, '${uri.host}${uri.path} is ${response.contentLength} bytes');
      }
      final body = BytesBuilder(copy: false);
      // Leaving the loop cancels the download.
      await for (final chunk in response.timeout(_bodyTimeout)) {
        body.add(chunk);
        if (body.length > maxBytes) {
          throw UpdateException(UpdateFailure.tooLarge, '${uri.host}${uri.path} is over $maxBytes bytes');
        }
      }
      return UpdateResponse(response.statusCode, headers: names, body: body.takeBytes());
    } on UpdateException {
      rethrow;
    } on TimeoutException {
      throw UpdateException(UpdateFailure.network, 'No answer in time from ${uri.host}');
    } on IOException catch (e) {
      // SocketException, HandshakeException, HttpException.
      throw UpdateException(UpdateFailure.network, '${e.runtimeType} from ${uri.host}: $e');
    }
  }
}

/// Hands a release to its install.ps1 (tool/windows/install.ps1), which
/// waits for the app to close, installs the release's MSI over it (a
/// MajorUpgrade) and opens it again.
class WindowsUpdateInstaller implements UpdateInstaller {
  const WindowsUpdateInstaller();

  /// The folder the script of [tag] is saved in, under [localAppData]
  /// (%LOCALAPPDATA%): beside the installer's log, apart from the app's data
  /// in %APPDATA%.
  static String folderFor(String localAppData, String tag) => '$localAppData\\Shnayim Mikrah\\updates\\$tag';

  /// The command that starts the script: Windows PowerShell, which every
  /// Windows 10 and 11 has, given [powershellArguments], in a console window
  /// of its own, so that its progress shows and it outlives the app. A
  /// detached process has no console (Dart starts it with DETACHED_PROCESS),
  /// so cmd's `start` opens one for it: cmd /d (no AutoRun) /v:off (no
  /// delayed expansion) /c start "Shnayim Mikrah" powershell.exe ….
  ///
  /// The line is the same for every release and every reader: Windows' own
  /// folder, then the app's own words. The script is named relative to the
  /// folder it is started in ([folderFor]), and the release and the app's
  /// process come in its environment ([scriptEnvironment]), so that nothing
  /// from GitHub, nor the names of the reader's own folders, is ever read by
  /// cmd.
  static (String executable, List<String> arguments) command({required Map<String, String> environment}) {
    final root = systemRoot(environment);
    return (
      '$root\\System32\\cmd.exe',
      [
        '/d',
        '/v:off',
        '/c',
        'start',
        'Shnayim Mikrah',
        '$root\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
        ...powershellArguments,
      ],
    );
  }

  /// Windows' folder, from SystemRoot (or windir): where cmd.exe and
  /// powershell.exe are, never wherever PATH finds them first. One that
  /// isn't a plain folder on a drive is not believed.
  static String systemRoot(Map<String, String> environment) {
    for (final name in ['SystemRoot', 'windir']) {
      final value = environment[name];
      if (value != null && RegExp(r'^[A-Za-z]:\\[A-Za-z0-9 _.\-\\]*$').hasMatch(value)) {
        return value.endsWith('\\') ? value.substring(0, value.length - 1) : value;
      }
    }
    return r'C:\Windows';
  }

  /// What Windows PowerShell is given: no profile, the script let run
  /// whatever the machine's execution policy, and the script itself, in the
  /// folder it is started in.
  static const powershellArguments = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', kInstallScriptAsset];

  /// What the script reads: the release to install, and the app to wait for
  /// (install.ps1 waits up to 60 seconds for it to exit).
  static Map<String, String> scriptEnvironment(String tag, int appPid) => {'SM_TAG': tag, 'SM_WAIT_PID': '$appPid'};

  @override
  Future<void> start({required String tag, required List<int> script}) async {
    if (!isInstallerTag(tag)) throw UpdateException(UpdateFailure.install, 'Not a release tag: $tag');
    final environment = Platform.environment;
    final local = environment['LOCALAPPDATA'];
    if (local == null || local.isEmpty) throw const UpdateException(UpdateFailure.install, 'LOCALAPPDATA is not set');
    try {
      final folder = await Directory(folderFor(local, tag)).create(recursive: true);
      await File('${folder.path}\\$kInstallScriptAsset').writeAsBytes(script, flush: true);
      final (executable, arguments) = command(environment: environment);
      await Process.start(
        executable,
        arguments,
        workingDirectory: folder.path,
        environment: scriptEnvironment(tag, pid),
        mode: ProcessStartMode.detached,
      );
    } on IOException catch (e) {
      // FileSystemException, ProcessException.
      throw UpdateException(UpdateFailure.install, '${e.runtimeType}: $e');
    }
  }
}
