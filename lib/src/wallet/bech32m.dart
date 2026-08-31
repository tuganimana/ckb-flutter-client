import 'dart:typed_data';

/// Bech32m (BIP-350) without the 90-character limit (CKB RFC 0021).
class Bech32m {
  Bech32m._();

  static const charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
  static const _const = 0x2bc830a3;
  static const _generator = [
    0x3b6a57b2,
    0x26508e6d,
    0x1ea119fa,
    0x3d4233dd,
    0x2a1462b3,
  ];

  static String encode(String hrp, List<int> data) {
    final checksum = _createChecksum(hrp, data);
    final combined = [...data, ...checksum];
    final buffer = StringBuffer(hrp)..write('1');
    for (final value in combined) {
      buffer.write(charset[value]);
    }
    return buffer.toString();
  }

  static ({String hrp, List<int> data}) decode(String address) {
    final trimmed = address.trim();
    if (trimmed != trimmed.toLowerCase() && trimmed != trimmed.toUpperCase()) {
      throw const FormatException('Mixed-case bech32m string');
    }
    final lower = trimmed.toLowerCase();
    final sep = lower.lastIndexOf('1');
    if (sep < 1 || sep + 7 > lower.length) {
      throw const FormatException('Invalid bech32m separator');
    }
    final hrp = lower.substring(0, sep);
    final dataPart = lower.substring(sep + 1);
    final values = <int>[];
    for (final char in dataPart.split('')) {
      final index = charset.indexOf(char);
      if (index == -1) {
        throw FormatException('Invalid bech32m character: $char');
      }
      values.add(index);
    }
    if (!_verifyChecksum(hrp, values)) {
      throw const FormatException('Invalid bech32m checksum');
    }
    return (hrp: hrp, data: values.sublist(0, values.length - 6));
  }

  static List<int> convertBits(
    List<int> data, {
    required int from,
    required int to,
    bool pad = true,
  }) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxValue = (1 << to) - 1;
    final maxAcc = (1 << (from + to - 1)) - 1;
    for (final value in data) {
      if (value < 0 || value >> from != 0) {
        throw FormatException('Invalid value for convertBits: $value');
      }
      acc = ((acc << from) | value) & maxAcc;
      bits += from;
      while (bits >= to) {
        bits -= to;
        result.add((acc >> bits) & maxValue);
      }
    }
    if (pad) {
      if (bits > 0) {
        result.add((acc << (to - bits)) & maxValue);
      }
    } else if (bits >= from || ((acc << (to - bits)) & maxValue) != 0) {
      throw const FormatException('Invalid padding in convertBits');
    }
    return result;
  }

  static Uint8List toBytes(List<int> words) {
    return Uint8List.fromList(convertBits(words, from: 5, to: 8, pad: false));
  }

  static List<int> toWords(List<int> bytes) {
    return convertBits(bytes, from: 8, to: 5);
  }

  static int _polymod(List<int> values) {
    var chk = 1;
    for (final value in values) {
      final top = chk >> 25;
      chk = ((chk & 0x1ffffff) << 5) ^ value;
      for (var i = 0; i < 5; i++) {
        if ((top >> i) & 1 == 1) {
          chk ^= _generator[i];
        }
      }
    }
    return chk;
  }

  static List<int> _hrpExpand(String hrp) {
    return [
      for (final code in hrp.codeUnits) code >> 5,
      0,
      for (final code in hrp.codeUnits) code & 31,
    ];
  }

  static List<int> _createChecksum(String hrp, List<int> data) {
    final polymod =
        _polymod([..._hrpExpand(hrp), ...data, 0, 0, 0, 0, 0, 0]) ^ _const;
    return [for (var i = 0; i < 6; i++) (polymod >> 5 * (5 - i)) & 31];
  }

  static bool _verifyChecksum(String hrp, List<int> data) {
    return _polymod([..._hrpExpand(hrp), ...data]) == _const;
  }
}
