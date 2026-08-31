import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:ckb_flutter_client/ckb_flutter_client.dart';

@JS('location.hostname')
external JSString get _hostname;

@JS('__ckbCreatePasskey')
external JSPromise<JSString>? _createPasskey(
  JSString rpId,
  JSString userName,
  JSString challengeB64,
  JSString userIdB64,
);

Future<({Uint8List publicKey, bool platformPasskey})> createPasskey() async {
  try {
    final challenge = _randomBytes(32);
    final userId = _randomBytes(16);
    final promise = _createPasskey(
      _hostname,
      'CKB Wallet'.toJS,
      base64UrlEncode(challenge).toJS,
      base64UrlEncode(userId).toJS,
    );
    if (promise == null) {
      return _software();
    }
    final spkiB64 = (await promise.toDart).toDart;
    final spki = base64Decode(_normalizeB64(spkiB64));
    return (publicKey: normalizeUncompressedP256(spki), platformPasskey: true);
  } catch (_) {
    return _software();
  }
}

({Uint8List publicKey, bool platformPasskey}) _software() {
  final keys = CkbPasskeyKeyPair.generate();
  return (publicKey: keys.uncompressedPublicKey, platformPasskey: false);
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

String _normalizeB64(String value) {
  var b64 = value.replaceAll('-', '+').replaceAll('_', '/');
  final pad = (4 - b64.length % 4) % 4;
  return b64.padRight(b64.length + pad, '=');
}
