import 'dart:typed_data';

class PasskeyEnrollment {
  const PasskeyEnrollment({
    required this.credentialId,
    required this.prfSalt,
    required this.wrapKey,
    this.publicKey,
    this.platformPasskey = false,
    this.prfWrapped = false,
    this.localWrapSecret,
  });

  final String credentialId;
  final Uint8List prfSalt;
  final Uint8List wrapKey;
  final Uint8List? publicKey;
  final bool platformPasskey;
  final bool prfWrapped;
  final String? localWrapSecret;
}

class PasskeyAssertion {
  const PasskeyAssertion({
    required this.credentialId,
    required this.wrapKey,
    this.prfWrapped = false,
  });

  final String credentialId;
  final Uint8List wrapKey;
  final bool prfWrapped;
}
