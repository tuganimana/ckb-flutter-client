import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/blake2b.dart';

import '../hex.dart';

/// CKB `blake2b` with personalization `ckb-default-hash`.
class CkbHash {
  CkbHash._();

  static const personalization = 'ckb-default-hash';

  static Uint8List blake2b(List<int> data, {int digestSize = 32}) {
    final digest = Blake2bDigest(
      digestSize: digestSize,
      personalization: Uint8List.fromList(utf8.encode(personalization)),
    );
    return digest.process(Uint8List.fromList(data));
  }

  /// First 20 bytes of [blake2b], used as secp256k1-blake160 lock args.
  static Uint8List blake160(List<int> data) {
    return Uint8List.fromList(blake2b(data).sublist(0, 20));
  }

  static String blake160Hex(List<int> data) => bytesToHex(blake160(data));
}
