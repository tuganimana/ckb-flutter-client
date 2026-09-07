import 'dart:typed_data';

import '../hex.dart';
import '../models/script.dart';

/// Minimal Molecule encoder for CKB scripts, witnesses, and raw transactions.
class Molecule {
  Molecule._();

  static Uint8List u32le(int value) {
    return Uint8List.fromList([
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ]);
  }

  static Uint8List u64le(int value) {
    final out = Uint8List(8);
    var remaining = value;
    for (var i = 0; i < 8; i++) {
      out[i] = remaining & 0xff;
      remaining = remaining ~/ 256;
    }
    return out;
  }

  static Uint8List bytes(List<int> data) {
    return Uint8List.fromList([...u32le(data.length), ...data]);
  }

  static Uint8List option(Uint8List? inner) => inner ?? Uint8List(0);

  static Uint8List table(List<Uint8List> fields) {
    final headerSize = 4 + 4 * fields.length;
    final offsets = <int>[];
    var cursor = headerSize;
    for (final field in fields) {
      offsets.add(cursor);
      cursor += field.length;
    }
    final out = BytesBuilder(copy: false)..add(u32le(cursor));
    for (final offset in offsets) {
      out.add(u32le(offset));
    }
    for (final field in fields) {
      out.add(field);
    }
    return out.toBytes();
  }

  static Uint8List fixvec(List<Uint8List> items) {
    final out = BytesBuilder(copy: false)..add(u32le(items.length));
    for (final item in items) {
      out.add(item);
    }
    return out.toBytes();
  }

  static Uint8List dynvec(List<Uint8List> items) => table(items);

  static Uint8List script(CkbScript script) {
    return table([
      hexToBytes(script.codeHash),
      Uint8List.fromList([script.hashType.byte]),
      bytes(hexToBytes(script.args)),
    ]);
  }

  static Uint8List witnessArgs({
    List<int>? lock,
    List<int>? inputType,
    List<int>? outputType,
  }) {
    return table([
      option(lock == null ? null : bytes(lock)),
      option(inputType == null ? null : bytes(inputType)),
      option(outputType == null ? null : bytes(outputType)),
    ]);
  }
}
