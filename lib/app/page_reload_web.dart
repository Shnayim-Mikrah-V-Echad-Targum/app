// The web app's page, loaded again from the start (see start_failure.dart).
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

const VoidCallback reloadPage = _reload;

void _reload() => web.window.location.reload();
