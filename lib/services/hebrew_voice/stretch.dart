import 'dart:math' as math;
import 'dart:typed_data';

/// [audio], at [rate] samples a second, played [speed] times as fast at the
/// same pitch, by WSOLA (waveform-similarity overlap-add): each next 30 ms
/// is taken from where, within 10 ms of where it falls, it best continues
/// the 30 ms before it, so that the waves join without a seam.
///
/// For the voices that can't change their own pace (Pocket TTS), and for
/// those that read less clearly when they change all of it themselves
/// (Kokoro, Blue).
Float32List stretch(Float32List audio, double speed, int rate) {
  if ((speed - 1).abs() < 0.01 || audio.isEmpty) return audio;
  final n = (rate * 0.03).round() & ~1;
  final hop = n ~/ 2;
  final tolerance = (rate * 0.01).round();
  final window = Float32List(n);
  for (var i = 0; i < n; i++) {
    window[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / n);
  }
  // The input, with silence around it for the frames that reach past it:
  // the first starts half a frame before it, so that every sample of the
  // output lies under two.
  final lead = (hop * speed).ceil() + tolerance + 1;
  final x = Float32List(lead + audio.length + 2 * n + tolerance + (hop * speed).ceil())..setRange(lead, lead + audio.length, audio);
  final length = (audio.length / speed).round();
  final y = Float32List(length + n + hop);
  final weight = Float32List(y.length);
  int? previous;
  for (var k = 0; k * hop - hop < length; k++) {
    // Where the frame falls in the input, and goes in the output (shifted
    // by a hop, as the first starts a hop before the output does).
    final nominal = lead + ((k - 1) * hop * speed).round();
    var start = nominal;
    if (previous != null) {
      // Where the previous frame would have gone on: the frame most like it,
      // looked for coarsely, then sample by sample around the best found.
      final next = previous + hop;
      double similarity(int at, int step) {
        var sum = 0.0;
        for (var i = 0; i < n; i += step) {
          sum += x[at + i] * x[next + i];
        }
        return sum;
      }

      var best = nominal;
      var bestScore = double.negativeInfinity;
      for (var d = -tolerance; d <= tolerance; d += 2) {
        final score = similarity(nominal + d, 4);
        if (score > bestScore) {
          bestScore = score;
          best = nominal + d;
        }
      }
      start = best;
      bestScore = double.negativeInfinity;
      for (var at = math.max(nominal - tolerance, best - 2); at <= math.min(nominal + tolerance, best + 2); at++) {
        final score = similarity(at, 1);
        if (score > bestScore) {
          bestScore = score;
          start = at;
        }
      }
    }
    final out = k * hop;
    for (var i = 0; i < n && out + i < y.length; i++) {
      y[out + i] += x[start + i] * window[i];
      weight[out + i] += window[i];
    }
    previous = start;
  }
  final result = Float32List(length);
  for (var i = 0; i < length; i++) {
    final w = weight[i + hop];
    result[i] = w > 1e-3 ? y[i + hop] / w : 0;
  }
  return result;
}
