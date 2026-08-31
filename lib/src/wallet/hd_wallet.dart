import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/digests/sha512.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/macs/hmac.dart';

import '../hex.dart';
import '../models/script.dart';
import 'address.dart';
import 'ckb_hash.dart';
import 'network.dart';

/// BIP-44 coin type registered for Nervos CKB.
const ckbCoinType = 309;

/// Default receiving path: `m/44'/309'/0'/0/0`.
const ckbDefaultDerivationPath = "m/44'/309'/0'/0/0";

/// A BIP-39 mnemonic that derives CKB secp256k1-blake160 addresses.
class CkbMnemonicWallet {
  CkbMnemonicWallet._({
    required this.mnemonic,
    required this.seed,
    required this.network,
  });

  /// Space-separated BIP-39 words.
  final String mnemonic;
  final Uint8List seed;
  final CkbNetwork network;

  /// 12-word English mnemonic by default.
  factory CkbMnemonicWallet.generate({
    CkbNetwork network = CkbNetwork.testnet,
    int words = 12,
  }) {
    final length = switch (words) {
      12 => MnemonicLength.words12,
      15 => MnemonicLength.words15,
      18 => MnemonicLength.words18,
      21 => MnemonicLength.words21,
      24 => MnemonicLength.words24,
      _ => throw ArgumentError.value(
        words,
        'words',
        'must be 12, 15, 18, 21, or 24',
      ),
    };
    final generated = Mnemonic.generate(Language.english, length: length);
    return CkbMnemonicWallet._(
      mnemonic: generated.sentence,
      seed: Uint8List.fromList(generated.seed),
      network: network,
    );
  }

  factory CkbMnemonicWallet.fromMnemonic(
    String mnemonic, {
    CkbNetwork network = CkbNetwork.testnet,
    String passphrase = '',
  }) {
    final parsed = Mnemonic.fromSentence(
      mnemonic.trim(),
      Language.english,
      passphrase: passphrase,
    );
    return CkbMnemonicWallet._(
      mnemonic: parsed.sentence,
      seed: Uint8List.fromList(parsed.seed),
      network: network,
    );
  }

  /// Derives the first receiving account (`m/44'/309'/0'/0/0`).
  CkbDerivedAccount deriveDefault() => derive();

  CkbDerivedAccount derive({int account = 0, int change = 0, int index = 0}) {
    final path = "m/44'/$ckbCoinType'/$account'/$change/$index";
    return derivePath(path);
  }

  CkbDerivedAccount derivePath(String path) {
    final privateKey = _derivePrivateKey(seed, path);
    final publicKey = _compressedPublicKey(privateKey);
    final blake160 = CkbHash.blake160Hex(publicKey);
    final lock = CkbScript.secp256k1Blake160(blake160);
    return CkbDerivedAccount(
      network: network,
      path: path,
      privateKey: privateKey,
      publicKey: publicKey,
      lock: lock,
      address: CkbAddress.encode(lock, network: network),
    );
  }
}

class CkbDerivedAccount {
  const CkbDerivedAccount({
    required this.network,
    required this.path,
    required this.privateKey,
    required this.publicKey,
    required this.lock,
    required this.address,
  });

  final CkbNetwork network;
  final String path;
  final Uint8List privateKey;
  final Uint8List publicKey;
  final CkbScript lock;
  final String address;

  String get blake160 => lock.args;
  String get privateKeyHex => bytesToHex(privateKey);
  String get publicKeyHex => bytesToHex(publicKey);
}

final _secp256k1 = ECCurve_secp256k1();
final _curveOrder = _secp256k1.n;

Uint8List _derivePrivateKey(Uint8List seed, String path) {
  var key = _masterKey(seed);
  for (final part in _parsePath(path)) {
    key = _ckdPriv(key, part);
  }
  return key.privateKey;
}

({Uint8List privateKey, Uint8List chainCode}) _masterKey(Uint8List seed) {
  final hash = _hmacSha512(Uint8List.fromList('Bitcoin seed'.codeUnits), seed);
  return (
    privateKey: Uint8List.fromList(hash.sublist(0, 32)),
    chainCode: Uint8List.fromList(hash.sublist(32)),
  );
}

({Uint8List privateKey, Uint8List chainCode}) _ckdPriv(
  ({Uint8List privateKey, Uint8List chainCode}) parent,
  int index,
) {
  final data = Uint8List(37);
  if (index >= 0x80000000) {
    data[0] = 0x00;
    data.setRange(1, 33, parent.privateKey);
  } else {
    data.setRange(0, 33, _compressedPublicKey(parent.privateKey));
  }
  data[33] = (index >> 24) & 0xff;
  data[34] = (index >> 16) & 0xff;
  data[35] = (index >> 8) & 0xff;
  data[36] = index & 0xff;

  final hash = _hmacSha512(parent.chainCode, data);
  final il = BigInt.parse(
    bytesToHex(hash.sublist(0, 32), withPrefix: false),
    radix: 16,
  );
  final parentKey = BigInt.parse(
    bytesToHex(parent.privateKey, withPrefix: false),
    radix: 16,
  );
  if (il >= _curveOrder) {
    throw StateError('Derived key IL is not valid');
  }
  final child = (il + parentKey) % _curveOrder;
  if (child == BigInt.zero) {
    throw StateError('Derived key is zero');
  }
  return (
    privateKey: _bigIntToBytes(child, 32),
    chainCode: Uint8List.fromList(hash.sublist(32)),
  );
}

List<int> _parsePath(String path) {
  final trimmed = path.trim();
  if (!trimmed.startsWith('m')) {
    throw FormatException('Derivation path must start with m: $path');
  }
  if (trimmed == 'm') return const [];
  return trimmed.split('/').skip(1).map((segment) {
    final hardened = segment.endsWith("'") || segment.endsWith('h');
    final number = int.parse(
      hardened ? segment.substring(0, segment.length - 1) : segment,
    );
    return hardened ? number + 0x80000000 : number;
  }).toList();
}

Uint8List _compressedPublicKey(Uint8List privateKey) {
  final d = BigInt.parse(bytesToHex(privateKey, withPrefix: false), radix: 16);
  final q = (_secp256k1.G * d)!;
  return q.getEncoded(true);
}

Uint8List _hmacSha512(Uint8List key, Uint8List data) {
  final hmac = HMac(SHA512Digest(), 128)..init(KeyParameter(key));
  return hmac.process(data);
}

Uint8List _bigIntToBytes(BigInt value, int length) {
  final hex = value.toRadixString(16).padLeft(length * 2, '0');
  return hexToBytes(hex);
}
