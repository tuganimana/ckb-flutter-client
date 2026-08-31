import '../hex.dart';
import '../models/script.dart';
import 'bech32m.dart';
import 'network.dart';

/// A CKB full address (RFC 0021) wrapping a lock script.
class CkbAddress {
  const CkbAddress({required this.network, required this.script});

  final CkbNetwork network;
  final CkbScript script;

  String get encoded => encode(script, network: network);

  /// Encodes [script] as a full CKB address (`ckb1q…` / `ckt1q…`).
  static String encode(
    CkbScript script, {
    CkbNetwork network = CkbNetwork.testnet,
  }) {
    final payload = <int>[
      0x00,
      ...hexToBytes(script.codeHash),
      script.hashType.byte,
      ...hexToBytes(script.args),
    ];
    return Bech32m.encode(network.hrp, Bech32m.toWords(payload));
  }

  static CkbAddress decode(String address) {
    final decoded = Bech32m.decode(address);
    final network = CkbNetwork.fromHrp(decoded.hrp);
    final payload = Bech32m.toBytes(decoded.data);
    if (payload.isEmpty) {
      throw const FormatException('Empty CKB address payload');
    }
    if (payload[0] != 0x00) {
      throw FormatException(
        'Only full CKB addresses (format 0x00) are supported, got 0x${payload[0].toRadixString(16)}',
      );
    }
    if (payload.length < 34) {
      throw const FormatException('CKB address payload is too short');
    }
    final codeHash = bytesToHex(payload.sublist(1, 33));
    final hashType = HashType.fromByte(payload[33]);
    final args = bytesToHex(payload.sublist(34));
    return CkbAddress(
      network: network,
      script: CkbScript(codeHash: codeHash, hashType: hashType, args: args),
    );
  }
}
