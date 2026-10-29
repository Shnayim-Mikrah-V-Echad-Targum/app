import 'dart:convert';
import 'dart:typed_data';

/// Small ONNX models the app writes itself, to keep a streaming model's
/// caches inside ONNX Runtime (PocketRunner): joining the keys and values a
/// step made to those before it, natively, so that they never cross into
/// Dart and back once a frame.
abstract final class OnnxGraphs {
  /// A model that joins `past` and `next` along their first axis into
  /// `joined`, float32 tensors of [rest] after it.
  static Uint8List concat(List<int> rest) => _model(
    nodes: [
      _node('Concat', ['past', 'next'], ['joined'], axis: 0),
    ],
    inputs: [
      _value('past', ['p', ...rest]),
      _value('next', ['n', ...rest]),
    ],
    outputs: [
      _value('joined', ['j', ...rest]),
    ],
  );

  /// A model that joins `past`, [keep] long, and `next`, [step] long, along
  /// their first axis, and keeps the last [keep] of them as `window`: a
  /// sliding window of the past. (Its bounds are fixed, and positive: the
  /// web's integers can't spell a negative 64-bit one.)
  static Uint8List window(List<int> rest, {required int keep, required int step}) => _model(
    nodes: [
      _node('Concat', ['past', 'next'], ['joined'], axis: 0),
      _node('Slice', ['joined', 'starts', 'ends', 'axes'], ['window']),
    ],
    initializers: [
      _int64s('starts', [step]),
      _int64s('ends', [keep + step]),
      _int64s('axes', [0]),
    ],
    inputs: [
      _value('past', [keep, ...rest]),
      _value('next', [step, ...rest]),
    ],
    outputs: [
      _value('window', [keep, ...rest]),
    ],
  );

  // --- Protocol buffers, as onnx.proto has them ------------------------------

  static Uint8List _model({
    required List<List<int>> nodes,
    required List<List<int>> inputs,
    required List<List<int>> outputs,
    List<List<int>> initializers = const [],
  }) {
    final graph = <int>[
      for (final n in nodes) ..._field(1, n),
      ..._string(2, 'app'),
      for (final t in initializers) ..._field(5, t),
      for (final i in inputs) ..._field(11, i),
      for (final o in outputs) ..._field(12, o),
    ];
    final opset = [..._string(1, ''), ..._varintField(2, 17)];
    return Uint8List.fromList([
      ..._varintField(1, 8), // ir_version
      ..._string(2, 'shnayim_mikrah'), // producer_name
      ..._field(7, graph),
      ..._field(8, opset),
    ]);
  }

  static List<int> _node(String op, List<String> inputs, List<String> outputs, {int? axis}) => [
    for (final i in inputs) ..._string(1, i),
    for (final o in outputs) ..._string(2, o),
    ..._string(4, op),
    if (axis != null) ..._field(5, [..._string(1, 'axis'), ..._varintField(3, axis), ..._varintField(20, 2)]),
  ];

  /// A float32 tensor input or output of [dims]: a size, or a name for a
  /// size that varies.
  static List<int> _value(String name, List<Object> dims) {
    final shape = [for (final d in dims) ..._field(1, d is int ? _varintField(1, d) : _string(2, d as String))];
    final tensor = [..._varintField(1, 1), ..._field(2, shape)];
    return [..._string(1, name), ..._field(2, _field(1, tensor))];
  }

  static List<int> _int64s(String name, List<int> values) => [
    ..._varintField(1, values.length), // dims
    ..._varintField(2, 7), // data_type: INT64
    ..._field(7, [for (final v in values) ..._varint(v)]), // int64_data, packed
    ..._string(8, name),
  ];

  static List<int> _field(int number, List<int> bytes) => [..._varint(number << 3 | 2), ..._varint(bytes.length), ...bytes];
  static List<int> _string(int number, String s) => _field(number, utf8.encode(s));
  static List<int> _varintField(int number, int value) => [..._varint(number << 3), ..._varint(value)];

  /// [value], at least 0, as a protobuf varint.
  static List<int> _varint(int value) {
    assert(value >= 0);
    final out = <int>[];
    var v = value;
    while (v >= 0x80) {
      out.add(v % 0x80 + 0x80);
      v ~/= 0x80;
    }
    out.add(v);
    return out;
  }
}
