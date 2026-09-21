import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

const vaultKdfLabel = 'ckb-flutter-client-vault-v1';

Uint8List randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

/// 32-byte AES key from a passkey PRF output, software secret, or random wrap key.
Uint8List deriveWrapKey(List<int> secret) {
  final digest = SHA256Digest();
  final secretBytes = Uint8List.fromList(secret);
  final label = Uint8List.fromList(utf8.encode(vaultKdfLabel));
  digest.update(secretBytes, 0, secretBytes.length);
  digest.update(label, 0, label.length);
  final out = Uint8List(digest.digestSize);
  digest.doFinal(out, 0);
  return out;
}

/// AES-256-GCM: `nonce (12) || ciphertext || tag (16)`, returned as raw bytes.
Uint8List encryptSecret(Uint8List wrapKey, String plaintext) {
  if (wrapKey.length != 32) {
    throw ArgumentError.value(wrapKey.length, 'wrapKey.length', 'must be 32');
  }
  final nonce = randomBytes(12);
  final cipher = GCMBlockCipher(AESEngine())
    ..init(true, AEADParameters(KeyParameter(wrapKey), 128, nonce, Uint8List(0)));
  final cipherText = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
  return Uint8List.fromList([...nonce, ...cipherText]);
}

String decryptSecret(Uint8List wrapKey, Uint8List packed) {
  if (wrapKey.length != 32) {
    throw ArgumentError.value(wrapKey.length, 'wrapKey.length', 'must be 32');
  }
  if (packed.length < 12 + 16) {
    throw const FormatException('Encrypted vault payload is too short');
  }
  final nonce = packed.sublist(0, 12);
  final cipherText = packed.sublist(12);
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      false,
      AEADParameters(KeyParameter(wrapKey), 128, nonce, Uint8List(0)),
    );
  try {
    return utf8.decode(cipher.process(cipherText));
  } catch (_) {
    throw const FormatException('Passkey could not unlock the vault');
  }
}
