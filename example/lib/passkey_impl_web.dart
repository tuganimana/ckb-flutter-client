import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:ckb_flutter_client/ckb_flutter_client.dart';

import 'passkey_types.dart';
import 'vault_crypto.dart';

@JS('location.hostname')
external JSString get _hostname;

@JS('__ckbCreatePasskey')
external JSPromise<JSString>? _createPasskey(
  JSString rpId,
  JSString userName,
  JSString challengeB64,
  JSString userIdB64,
  JSString saltB64,
);

@JS('__ckbGetPasskey')
external JSPromise<JSString>? _getPasskey(
  JSString rpId,
  JSString challengeB64,
  JSString credentialIdB64,
  JSString saltB64,
);

Future<PasskeyEnrollment> createPasskey() async {
  final challenge = _randomBytes(32);
  final userId = _randomBytes(16);
  final salt = _randomBytes(32);
  final promise = _createPasskey(
    _hostname,
    'CKB Wallet'.toJS,
    base64UrlEncode(challenge).toJS,
    base64UrlEncode(userId).toJS,
    base64UrlEncode(salt).toJS,
  );
  if (promise == null) {
    return _software(salt);
  }
  try {
    final created = _parse(await promise.toDart);
    var prf = created.prf;
    if (prf == null || prf.isEmpty) {
      try {
        final asserted = await _authenticate(
          credentialId: created.credentialId,
          salt: salt,
        );
        prf = asserted.prf;
      } catch (_) {
        prf = null;
      }
    }
    return _enrollmentFromWeb(
      credentialId: created.credentialId,
      publicKey: created.publicKey,
      salt: salt,
      prf: prf,
    );
  } catch (error) {
    if (_isUnsupported(error) || _isMissingBridge(error)) {
      return _software(salt);
    }
    throw _friendlyError(error, fallback: 'Could not create a passkey.');
  }
}

Future<PasskeyAssertion> authenticatePasskey({
  required String credentialId,
  required Uint8List prfSalt,
  String? localWrapSecret,
}) async {
  try {
    final result = await _authenticate(credentialId: credentialId, salt: prfSalt);
    final prf = result.prf;
    if (prf != null && prf.isNotEmpty) {
      return PasskeyAssertion(
        credentialId: result.credentialId,
        wrapKey: deriveWrapKey(prf),
        prfWrapped: true,
      );
    }
    if (localWrapSecret != null && localWrapSecret.isNotEmpty) {
      return PasskeyAssertion(
        credentialId: result.credentialId,
        wrapKey: deriveWrapKey(hexToBytes(localWrapSecret)),
        prfWrapped: false,
      );
    }
    throw const FormatException(
      'This passkey unlocked, but it cannot unwrap the vault. Create a new wallet.',
    );
  } catch (error) {
    if (error is FormatException) rethrow;
    if ((_isUnsupported(error) || _isMissingBridge(error)) &&
        localWrapSecret != null &&
        localWrapSecret.isNotEmpty) {
      return PasskeyAssertion(
        credentialId: credentialId,
        wrapKey: deriveWrapKey(hexToBytes(localWrapSecret)),
        prfWrapped: false,
      );
    }
    throw _friendlyError(
      error,
      fallback: 'Passkey sign-in was cancelled or failed.',
    );
  }
}

Future<({String credentialId, Uint8List? publicKey, Uint8List? prf})>
_authenticate({required String credentialId, required Uint8List salt}) async {
  final challenge = _randomBytes(32);
  final promise = _getPasskey(
    _hostname,
    base64UrlEncode(challenge).toJS,
    credentialId.toJS,
    base64UrlEncode(salt).toJS,
  );
  if (promise == null) {
    throw const FormatException('Passkeys are not available in this browser.');
  }
  return _parse(await promise.toDart);
}

PasskeyEnrollment _enrollmentFromWeb({
  required String credentialId,
  required Uint8List? publicKey,
  required Uint8List salt,
  required Uint8List? prf,
}) {
  final fallback = randomBytes(32);
  final secret = (prf != null && prf.isNotEmpty) ? prf : fallback;
  final prfWrapped = identical(secret, prf);
  return PasskeyEnrollment(
    credentialId: credentialId,
    publicKey: publicKey,
    prfSalt: salt,
    wrapKey: deriveWrapKey(secret),
    platformPasskey: true,
    prfWrapped: prfWrapped,
    localWrapSecret: prfWrapped ? null : bytesToHex(fallback),
  );
}

PasskeyEnrollment _software(Uint8List salt) {
  final keys = CkbPasskeyKeyPair.generate();
  final credentialId = base64UrlEncode(_randomBytes(16));
  return PasskeyEnrollment(
    credentialId: credentialId,
    publicKey: keys.uncompressedPublicKey,
    prfSalt: salt,
    wrapKey: deriveWrapKey(keys.privateKey),
    platformPasskey: false,
    prfWrapped: false,
    localWrapSecret: bytesToHex(keys.privateKey),
  );
}

({String credentialId, Uint8List? publicKey, Uint8List? prf}) _parse(
  JSString json,
) {
  final decoded = jsonDecode(json.toDart);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Unexpected passkey response');
  }
  final credentialId = decoded['credentialId'] as String? ?? '';
  if (credentialId.isEmpty) {
    throw const FormatException('Passkey credential id is missing');
  }
  return (
    credentialId: credentialId,
    publicKey: _optionalBytes(decoded['publicKey']),
    prf: _optionalBytes(decoded['prf']),
  );
}

Uint8List? _optionalBytes(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return Uint8List.fromList(base64Decode(_normalizeB64(value)));
}

Uint8List _randomBytes(int length) => randomBytes(length);

String _normalizeB64(String value) {
  var b64 = value.replaceAll('-', '+').replaceAll('_', '/');
  final pad = (4 - b64.length % 4) % 4;
  return b64.padRight(b64.length + pad, '=');
}

bool _isUnsupported(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('unsupported') || text.contains('not supported');
}

bool _isMissingBridge(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('unexpected null') || text.contains('isnull');
}

Object _friendlyError(Object error, {required String fallback}) {
  final text = error.toString();
  final lower = text.toLowerCase();
  if (lower.contains('notallowed') ||
      lower.contains('abort') ||
      lower.contains('cancel')) {
    return FormatException(fallback);
  }
  return FormatException('$fallback $text');
}
