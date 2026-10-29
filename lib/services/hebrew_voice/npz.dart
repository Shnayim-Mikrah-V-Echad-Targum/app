import 'dart:convert';
import 'dart:typed_data';

/// One array of a NumPy .npy file: its shape, and its values in order.
class NpyArray {
  const NpyArray(this.shape, this.data);
  final List<int> shape;
  final Float32List data;
}

/// The arrays of a NumPy .npz archive, by name (without ".npy"), as
/// numpy.savez writes one: a ZIP of uncompressed .npy files of little-endian
/// float32. The voices ship their statistics, guidance and styles so.
/// Throws a FormatException for anything else.
Map<String, NpyArray> readNpz(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  // The end of central directory record, found from the end.
  var eocd = -1;
  for (var i = bytes.length - 22; i >= 0 && i >= bytes.length - 22 - 0xFFFF; i--) {
    if (data.getUint32(i, Endian.little) == 0x06054b50) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) throw const FormatException('Not a ZIP archive');
  final count = data.getUint16(eocd + 10, Endian.little);
  var at = data.getUint32(eocd + 16, Endian.little);
  final out = <String, NpyArray>{};
  for (var n = 0; n < count; n++) {
    if (data.getUint32(at, Endian.little) != 0x02014b50) throw const FormatException('Bad ZIP directory');
    final method = data.getUint16(at + 10, Endian.little);
    final size = data.getUint32(at + 24, Endian.little);
    final nameLength = data.getUint16(at + 28, Endian.little);
    final extraLength = data.getUint16(at + 30, Endian.little);
    final commentLength = data.getUint16(at + 32, Endian.little);
    final local = data.getUint32(at + 42, Endian.little);
    final name = utf8.decode(bytes.sublist(at + 46, at + 46 + nameLength));
    at += 46 + nameLength + extraLength + commentLength;
    if (method != 0) throw FormatException('$name is compressed');
    final start = local + 30 + data.getUint16(local + 26, Endian.little) + data.getUint16(local + 28, Endian.little);
    out[name.endsWith('.npy') ? name.substring(0, name.length - 4) : name] = readNpy(Uint8List.sublistView(bytes, start, start + size));
  }
  return out;
}

/// A NumPy .npy file of little-endian float32, in C order.
NpyArray readNpy(Uint8List bytes) {
  if (bytes.length < 10 || bytes[0] != 0x93 || ascii.decode(bytes.sublist(1, 6)) != 'NUMPY') {
    throw const FormatException('Not an .npy file');
  }
  final data = ByteData.sublistView(bytes);
  final major = bytes[6];
  final headerLength = major == 1 ? data.getUint16(8, Endian.little) : data.getUint32(8, Endian.little);
  final headerStart = major == 1 ? 10 : 12;
  final header = latin1.decode(bytes.sublist(headerStart, headerStart + headerLength));
  if (!header.contains("'descr': '<f4'")) throw FormatException('Not little-endian float32: $header');
  if (header.contains("'fortran_order': True")) throw const FormatException('Fortran order');
  final shapeText = RegExp(r"'shape': \(([^)]*)\)").firstMatch(header)?.group(1) ?? '';
  final shape = [
    for (final d in shapeText.split(','))
      if (d.trim().isNotEmpty) int.parse(d.trim()),
  ];
  final count = shape.fold<int>(1, (a, b) => a * b);
  final start = headerStart + headerLength;
  final values = Float32List(count);
  for (var i = 0; i < count; i++) {
    values[i] = data.getFloat32(start + i * 4, Endian.little);
  }
  return NpyArray(shape, values);
}
