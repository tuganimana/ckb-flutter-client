/// Parses a CKB hex-encoded unsigned integer (`0x1a`, `0x0`, …).
int parseHexUint(String value) {
  final hex = _stripHexPrefix(value);
  if (hex.isEmpty) return 0;
  return int.parse(hex, radix: 16);
}

/// Parses a CKB hex-encoded unsigned integer that may exceed 64 bits.
BigInt parseHexBigInt(String value) {
  final hex = _stripHexPrefix(value);
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

String _stripHexPrefix(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
    return trimmed.substring(2);
  }
  return trimmed;
}
