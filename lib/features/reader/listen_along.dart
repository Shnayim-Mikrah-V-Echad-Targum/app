import 'package:flutter/foundation.dart';

import '../../services/tts.dart';

/// What Listen reads (DESIGN.md §3): one utterance for each layer of each
/// verse, in order (the Mikra, then its Targum), each with the verse it
/// belongs to, which is highlighted while it is read and which the player
/// moves between.
class SpeechQueue {
  SpeechQueue({required this.language});

  /// The voice's language: 'he-IL' for the Hebrew and the Aramaic, 'en-US'
  /// for Rashi in English.
  final String language;

  /// The utterances, in order.
  final items = <String>[];

  /// For each of [items], the index of its verse among the verses the queue
  /// was made from.
  final verses = <int>[];

  bool get isEmpty => items.isEmpty;

  /// Adds [text] as part of verse [verse]; nothing, if it has nothing to say.
  void add(int verse, String text) {
    if (text.trim().isEmpty) return;
    assert(verses.isEmpty || verse >= verses.last, 'a verse is read after the one before it');
    items.add(text);
    verses.add(verse);
  }

  /// The first item of [verse], or of the first verse after it that has one;
  /// the last item, if none does.
  int startOf(int verse) {
    final i = verses.indexWhere((v) => v >= verse);
    return i < 0 ? items.length - 1 : i;
  }
}

/// How a Listen ended.
enum ListenEnd {
  /// Read to its end.
  finished,

  /// Stopped, or replaced by another.
  stopped,

  /// The device couldn't speak it.
  failed,
}

/// The Listen of one page, from the moment it starts until it ends or is
/// stopped: the verse being read, whether it is paused, and the controls of
/// the bar that shows while it lasts (ListenBar). It tells its listeners as
/// the voice moves from verse to verse, and as it pauses or goes on.
class ListenController extends ChangeNotifier {
  ListenController(this.tts) {
    tts.currentIndex.addListener(_changed);
    tts.paused.addListener(_changed);
  }

  final TtsService tts;

  SpeechQueue? _queue;
  int _queueId = -1;
  int? _verse;

  /// Whether a Listen is on, playing or paused.
  bool get active => _queue != null;

  // Whether the speech service's queue is this page's.
  bool get _ours => _queue != null && tts.queueId == _queueId;

  /// The verse being read, or paused at: its index among the verses the
  /// queue was made from. Null while no Listen is on.
  int? get verse => active ? _verse : null;

  bool get paused => _ours && tts.paused.value;

  /// Whether there is a verse to move on or back to.
  bool get hasNext => _ours && tts.hasNext;
  bool get hasPrevious => _ours && tts.hasPrevious;

  void _changed() {
    if (!_ours) return;
    final i = tts.currentIndex.value;
    if (i != null) _verse = _queue!.verses[i];
    notifyListeners();
  }

  /// Reads [queue] at [rate] from the first item of verse [startVerse], and
  /// completes once it ends: read to its end (when the Listen is still on,
  /// for the caller to end or go on with), stopped, or failed (when it is
  /// over).
  Future<ListenEnd> play(SpeechQueue queue, {required double rate, int startVerse = 0}) async {
    _queue = queue;
    _verse = null;
    final done = tts.speakQueue(
      queue.items,
      language: queue.language,
      rate: rate,
      startAt: queue.startOf(startVerse),
      groups: queue.verses,
    );
    _queueId = tts.queueId;
    _changed();
    try {
      final finished = await done;
      // Replaced by another Listen of this page's, which goes on.
      if (!identical(_queue, queue)) return ListenEnd.stopped;
      if (finished) return ListenEnd.finished;
      // Stopped from elsewhere, or by another page's Listen.
      end();
      return ListenEnd.stopped;
    } catch (_) {
      if (!identical(_queue, queue)) return ListenEnd.stopped;
      end();
      return ListenEnd.failed;
    }
  }

  /// Ends the Listen, once speech has stopped.
  void end() {
    if (_queue == null) return;
    _queue = null;
    _verse = null;
    notifyListeners();
  }

  /// Ends the Listen and stops speech.
  Future<void> stop() {
    end();
    return tts.stop();
  }

  void pause() {
    if (_ours) tts.pause();
  }

  void resume() {
    if (_ours) tts.resume();
  }

  void next() {
    if (_ours) tts.next();
  }

  void previous() {
    if (_ours) tts.previous();
  }

  /// Moves to [verse] (an index among the verses the queue was made from),
  /// or the first after it with something to read. A paused Listen stays
  /// paused there.
  void moveTo(int verse) {
    if (_ours) tts.moveTo(_queue!.startOf(verse));
  }

  /// Reads on at [rate], from the start of the item being read.
  void setRate(double rate) {
    if (_ours) tts.setRate(rate);
  }

  @override
  void dispose() {
    tts.currentIndex.removeListener(_changed);
    tts.paused.removeListener(_changed);
    // A Listen still on ends with its page, quietly: [play] has no one left
    // to tell.
    _queue = null;
    super.dispose();
  }
}

/// The speech rates the player offers: the setting's scale (0.1 to 1.0, as
/// Settings → Accessibility shows it, in percent), with the default, 0.45,
/// among them.
const kSpeechRates = [0.25, 0.35, 0.45, 0.55, 0.65, 0.8, 1.0];

/// [kSpeechRates], with [current] among them if it is set to another.
List<double> speechRatesWith(double current) {
  final rates = [...kSpeechRates];
  if (!rates.any((r) => sameSpeechRate(r, current))) rates.add(current);
  return rates..sort();
}

/// Whether [a] and [b] are the same speech rate, as Settings shows it: the
/// slider's steps add up to rates a little off the menu's (0.1 + 7 × 0.05 is
/// 0.45000000000000007).
bool sameSpeechRate(double a, double b) => (a - b).abs() < 0.001;

/// A speech rate as Settings → Accessibility shows it: "45%".
String speechRateLabel(double rate) => '${(rate * 100).round()}%';
