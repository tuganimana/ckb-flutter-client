import 'dart:typed_data';

import 'package:ckb_flutter_client/ckb_flutter_client.dart';

Future<({Uint8List publicKey, bool platformPasskey})> createPasskey() async {
  final keys = CkbPasskeyKeyPair.generate();
  return (publicKey: keys.uncompressedPublicKey, platformPasskey: false);
}
