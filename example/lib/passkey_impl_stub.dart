import 'dart:convert';
import 'dart:typed_data';

import 'package:ckb_flutter_client/ckb_flutter_client.dart';

import 'passkey_types.dart';
import 'vault_crypto.dart';

Future<PasskeyEnrollment> createPasskey() async {
  final keys = CkbPasskeyKeyPair.generate();
  return PasskeyEnrollment(
    credentialId: base64UrlEncode(randomBytes(16)),
    publicKey: keys.uncompressedPublicKey,
    prfSalt: randomBytes(32),
    wrapKey: deriveWrapKey(keys.privateKey),
    platformPasskey: false,
    prfWrapped: false,
    localWrapSecret: bytesToHex(keys.privateKey),
  );
}

Future<PasskeyAssertion> authenticatePasskey({
  required String credentialId,
  required Uint8List prfSalt,
  String? localWrapSecret,
}) async {
  if (localWrapSecret == null || localWrapSecret.isEmpty) {
    throw const FormatException(
      'No local passkey secret is stored on this device.',
    );
  }
  return PasskeyAssertion(
    credentialId: credentialId,
    wrapKey: deriveWrapKey(hexToBytes(localWrapSecret)),
    prfWrapped: false,
  );
}
