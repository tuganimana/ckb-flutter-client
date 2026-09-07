import 'dart:typed_data';

/// Parses a CKB hex-encoded unsigned integer (`0x1a`, `0x0`, …).
int parseHexUint(String value) {
  final hex = stripHexPrefix(value);
  if (hex.isEmpty) return 0;
  return int.parse(hex, radix: 16);
}

/// Parses a CKB hex-encoded unsigned integer that may exceed 64 bits.
BigInt parseHexBigInt(String value) {
  final hex = stripHexPrefix(value);
  if (hex.isEmpty) return BigInt.zero;
  return BigInt.parse(hex, radix: 16);
}

/// Encodes [value] as a CKB hex quantity (`0x0`, `0x64`, …).
String toHexUint(int value) {
  if (value < 0) {
    throw ArgumentError.value(value, 'value', 'must be non-negative');
  }
  return '0x${value.toRadixString(16)}';
}

/// Encodes [value] as a CKB hex quantity.
String toHexBigInt(BigInt value) {
  if (value.isNegative) {
    throw ArgumentError.value(value, 'value', 'must be non-negative');
  }
  return '0x${value.toRadixString(16)}';
}

/// CKB native token: 1 CKB = 10^8 shannons.
const shannonsPerCkb = 100000000;

/// Typical occupancy of a secp256k1-blake160 cell with empty data.
const minCellCapacityShannons = 61 * shannonsPerCkb;

int ckbToShannons(num ckb) => (ckb * shannonsPerCkb).round();

double shannonsToCkb(int shannons) => shannons / shannonsPerCkb;

String stripHexPrefix(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
    return trimmed.substring(2);
  }
  return trimmed;
}

/// Decodes a hex string (`0xab` or `ab`) into bytes.
Uint8List hexToBytes(String value) {
  var hex = stripHexPrefix(value);
  if (hex.length.isOdd) {
    hex = '0$hex';
  }
  if (hex.isEmpty) return Uint8List(0);
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

/// Encodes [bytes] as a hex string. Defaults to a `0x` prefix.
String bytesToHex(List<int> bytes, {bool withPrefix = true}) {
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return withPrefix ? '0x$hex' : hex;
}
