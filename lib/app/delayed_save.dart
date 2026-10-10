import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Writes a value to storage, as JSON under [key], a moment after the last
/// change to it, so that a burst of changes (a reader stepping verse by verse
/// through an aliyah, a slider being dragged) is encoded and written once
/// rather than every time.
///
/// Whatever is waiting must be written with [flush] before the app can stop:
/// when it goes into the background or is closed (see [PendingSaves]), and
/// when its owner is disposed.
class DelayedSave {
  DelayedSave(this._prefs, this.key);

  /// How long a value must rest unchanged before it is written.
  static const delay = Duration(milliseconds: 500);

  final SharedPreferences _prefs;
  final String key;

  Timer? _timer;
  Object? Function()? _pending;

  /// Whether a value is waiting to be written.
  @visibleForTesting
  bool get isPending => _pending != null;

  /// Writes the value [toJson] gives after [delay], unless another one is
  /// saved first. [toJson] is called only when the value is written.
  void save(Object? Function() toJson) {
    _pending = toJson;
    _timer?.cancel();
    _timer = Timer(delay, flush);
  }

  /// Writes the waiting value, if any, now. Storage holds it as soon as this
  /// returns; the future completes once it is on disk.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final toJson = _pending;
    _pending = null;
    if (toJson != null) await _prefs.setString(key, jsonEncode(toJson()));
  }
}
