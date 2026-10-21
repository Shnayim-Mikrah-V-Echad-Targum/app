// The web build's stand-in for update_io.dart: the web app updates itself
// through its service worker (lib/services/web_update.dart), and never asks
// for these (updateServiceProvider is null there).
import 'update_core.dart';
import 'update_service.dart';

UpdateHttp createUpdateHttp() => throw UnsupportedError('Updates are for the Windows app');

UpdateInstaller createUpdateInstaller() => throw UnsupportedError('Updates are for the Windows app');

Never forceExit() => throw UnsupportedError('Updates are for the Windows app');
