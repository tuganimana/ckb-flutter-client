import 'dart:typed_data';

import 'package:ckb_flutter_client/ckb_flutter_client.dart';

import 'passkey_impl_stub.dart'
    if (dart.library.js_interop) 'passkey_impl_web.dart'
    as impl;

class PasskeyResult {
  const PasskeyResult({required this.publicKey, required this.platformPasskey});

  final Uint8List publicKey;
  final bool platformPasskey;
}

/// Creates a passkey (WebAuthn on web, software secp256r1 elsewhere).
Future<PasskeyResult> createPasskey() async {
  final result = await impl.createPasskey();
  return PasskeyResult(
    publicKey: result.publicKey,
    platformPasskey: result.platformPasskey,
  );
}

CkbPasskeyAccount accountFromPasskey(
  PasskeyResult result, {
  CkbNetwork network = CkbNetwork.testnet,
}) {
  return CkbPasskeyAccount.fromPublicKey(result.publicKey, network: network);
}
