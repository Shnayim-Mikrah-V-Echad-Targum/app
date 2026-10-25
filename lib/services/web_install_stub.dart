// Off the web, where the app is installed already (see web_install.dart).

bool promptAvailable() => false;

bool installedNow() => false;

bool runningStandalone() => true;

Future<String> prompt() async => 'unavailable';

void Function() listen(void Function() onChange) => () {};

String userAgent() => '';

bool isBrave() => false;
