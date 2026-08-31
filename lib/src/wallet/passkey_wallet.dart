import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/prime256v1.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/ec_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';

import '../hex.dart';
import '../models/script.dart';
import 'address.dart';
import 'ckb_hash.dart';
import 'network.dart';

/// JoyID WebAuthn algorithm index for secp256r1 passkeys (`0x0001`).
const joyIdSecp256r1Alg = 0x0001;

/// A CKB passkey (JoyID) account: secp256r1 pubkey → lock → fundable address.
class CkbPasskeyAccount {
  const CkbPasskeyAccount({
    required this.network,
    required this.uncompressedPublicKey,
    required this.lock,
    required this.address,
  });

  final CkbNetwork network;

  /// 64-byte uncompressed P-256 public key (`x || y`, no `0x04` prefix).
  final Uint8List uncompressedPublicKey;
  final CkbScript lock;
  final String address;

  String get publicKeyHex => bytesToHex(uncompressedPublicKey);
  String get blake160 => lock.args.length >= 6
      ? '0x${stripHexPrefix(lock.args).substring(4)}'
      : lock.args;

  /// Builds a JoyID lock from a P-256 public key.
  ///
  /// Accepts 64-byte `x||y` or 65-byte uncompressed (`0x04||x||y`) keys.
  factory CkbPasskeyAccount.fromPublicKey(
    List<int> publicKey, {
    CkbNetwork network = CkbNetwork.testnet,
  }) {
    final uncompressed = normalizeUncompressedP256(publicKey);
    final pubkeyHash = CkbHash.blake160(uncompressed);
    final args = bytesToHex([
      (joyIdSecp256r1Alg >> 8) & 0xff,
      joyIdSecp256r1Alg & 0xff,
      ...pubkeyHash,
    ]);
    final lock = CkbScript(
      codeHash: network.joyIdCodeHash,
      hashType: HashType.type,
      args: args,
    );
    return CkbPasskeyAccount(
      network: network,
      uncompressedPublicKey: uncompressed,
      lock: lock,
      address: CkbAddress.encode(lock, network: network),
    );
  }
}

/// Software secp256r1 key used when the platform has no WebAuthn passkey.
class CkbPasskeyKeyPair {
  const CkbPasskeyKeyPair({
    required this.privateKey,
    required this.uncompressedPublicKey,
  });

  final Uint8List privateKey;
  final Uint8List uncompressedPublicKey;

  CkbPasskeyAccount account({CkbNetwork network = CkbNetwork.testnet}) {
    return CkbPasskeyAccount.fromPublicKey(
      uncompressedPublicKey,
      network: network,
    );
  }

  factory CkbPasskeyKeyPair.generate() {
    final random = FortunaRandom()..seed(KeyParameter(_secureBytes(32)));
    final generator = ECKeyGenerator()
      ..init(
        ParametersWithRandom(
          ECKeyGeneratorParameters(ECCurve_prime256v1()),
          random,
        ),
      );
    final pair = generator.generateKeyPair();
    final private = pair.privateKey;
    final public = pair.publicKey;
    return CkbPasskeyKeyPair(
      privateKey: _bigIntToBytes(private.d!, 32),
      uncompressedPublicKey: _p256Xy(public.Q!),
    );
  }
}

/// Normalizes a P-256 public key to 64-byte `x||y`.
Uint8List normalizeUncompressedP256(List<int> publicKey) {
  if (publicKey.length == 64) {
    return Uint8List.fromList(publicKey);
  }
  if (publicKey.length == 65 && publicKey[0] == 0x04) {
    return Uint8List.fromList(publicKey.sublist(1));
  }
  if (publicKey.length >= 65 && publicKey[publicKey.length - 65] == 0x04) {
    return Uint8List.fromList(publicKey.sublist(publicKey.length - 64));
  }
  throw FormatException(
    'Expected a P-256 uncompressed public key (64 or 65 bytes), got ${publicKey.length}',
  );
}

Uint8List _p256Xy(ECPoint point) {
  final x = point.x!.toBigInteger()!;
  final y = point.y!.toBigInteger()!;
  return Uint8List.fromList([
    ..._bigIntToBytes(x, 32),
    ..._bigIntToBytes(y, 32),
  ]);
}

Uint8List _bigIntToBytes(BigInt value, int length) {
  final hex = value.toRadixString(16).padLeft(length * 2, '0');
  return hexToBytes(hex);
}

Uint8List _secureBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}
