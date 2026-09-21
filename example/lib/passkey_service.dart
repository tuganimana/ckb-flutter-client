import 'dart:typed_data';

import 'passkey_impl_stub.dart'
    if (dart.library.js_interop) 'passkey_impl_web.dart'
    as impl;
import 'passkey_types.dart';

export 'passkey_types.dart';

/// Creates a device passkey (WebAuthn on web) used to wrap the wallet seed.
Future<PasskeyEnrollment> enrollPasskey() => impl.createPasskey();

/// Asserts the enrolled passkey and returns the vault wrap key.
Future<PasskeyAssertion> unlockWithPasskey({
  required String credentialId,
  required Uint8List prfSalt,
  String? localWrapSecret,
}) {
  return impl.authenticatePasskey(
    credentialId: credentialId,
    prfSalt: prfSalt,
    localWrapSecret: localWrapSecret,
  );
}
