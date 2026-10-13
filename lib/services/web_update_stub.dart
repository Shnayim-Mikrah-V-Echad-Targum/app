// Off the web, where the app updates through its store or installer, never
// while it runs (see web_update.dart).

bool updateWaiting() => false;

void Function() listenForUpdate(void Function() onReady) => () {};

void restartIntoUpdate() {}
