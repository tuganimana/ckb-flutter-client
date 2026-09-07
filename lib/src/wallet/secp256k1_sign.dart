import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';

import '../hex.dart';

final _curve = ECCurve_secp256k1();
final _n = _curve.n;

/// Signs a 32-byte CKB sighash with secp256k1 and a recoverable id.
Uint8List signRecoverable(Uint8List message, Uint8List privateKey) {
  if (message.length != 32) {
    throw ArgumentError.value(message.length, 'message.length', 'must be 32');
  }
  if (privateKey.length != 32) {
    throw ArgumentError.value(
      privateKey.length,
      'privateKey.length',
      'must be 32',
    );
  }

  final d = _toBigInt(privateKey);
  final signer = ECDSASigner(null, HMac(SHA256Digest(), 64))
    ..init(true, PrivateKeyParameter(ECPrivateKey(d, _curve)));
  var signature = signer.generateSignature(message) as ECSignature;
  var r = signature.r;
  var s = signature.s;
  var recid = 0;

  final halfN = _n >> 1;
  if (s > halfN) {
    s = _n - s;
  }

  final expected = _compressedPublicKey(d);
  var found = false;
  for (var id = 0; id < 4; id++) {
    final recovered = recoverPublicKey(message, r, s, id);
    if (recovered != null && _bytesEqual(recovered, expected)) {
      recid = id;
      found = true;
      break;
    }
  }
  if (!found) {
    throw StateError('Could not determine secp256k1 recovery id');
  }

  return Uint8List.fromList([
    ..._bigIntToBytes(r, 32),
    ..._bigIntToBytes(s, 32),
    recid,
  ]);
}

Uint8List? recoverPublicKey(Uint8List message, BigInt r, BigInt s, int recid) {
  if (r <= BigInt.zero || r >= _n || s <= BigInt.zero || s >= _n) {
    return null;
  }
  final x = r + (BigInt.from(recid >> 1) * _n);
  final prefix = (recid & 1) == 0 ? 0x02 : 0x03;
  final encoded = Uint8List.fromList([prefix, ..._bigIntToBytes(x, 32)]);
  final R = _curve.curve.decodePoint(encoded);
  if (R == null || R.isInfinity) return null;

  final e = _toBigInt(message) % _n;
  final rInv = r.modInverse(_n);
  final eG = (_curve.G * ((_n - e) % _n))!;
  final sR = (R * s)!;
  final Q = ((sR + eG)! * rInv)!;
  if (Q.isInfinity) return null;
  return Q.getEncoded(true);
}

Uint8List _compressedPublicKey(BigInt privateKey) {
  return (_curve.G * privateKey)!.getEncoded(true);
}

BigInt _toBigInt(List<int> bytes) {
  return BigInt.parse(bytesToHex(bytes, withPrefix: false), radix: 16);
}

Uint8List _bigIntToBytes(BigInt value, int length) {
  return hexToBytes(value.toRadixString(16).padLeft(length * 2, '0'));
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
