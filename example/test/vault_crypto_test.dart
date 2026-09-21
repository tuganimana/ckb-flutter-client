import 'dart:convert';

import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:example/passkey_types.dart';
import 'package:example/session.dart';
import 'package:example/vault_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AES-GCM wrap round-trips the mnemonic', () {
    final wrapKey = deriveWrapKey(randomBytes(32));
    final packed = encryptSecret(wrapKey, jsonEncode({'mnemonic': 'alpha beta'}));
    final plain = decryptSecret(wrapKey, packed);
    expect(jsonDecode(plain), {'mnemonic': 'alpha beta'});
  });

  test('wrong wrap key fails to decrypt', () {
    final packed = encryptSecret(
      deriveWrapKey(randomBytes(32)),
      jsonEncode({'mnemonic': 'alpha beta'}),
    );
    expect(
      () => decryptSecret(deriveWrapKey(randomBytes(32)), packed),
      throwsA(isA<FormatException>()),
    );
  });

  test('enroll seals keys so passkey wrap can unlock them', () async {
    SharedPreferences.setMockInitialValues({});
    final wallet = CkbMnemonicWallet.generate();
    final secret = randomBytes(32);
    final session = await WalletSession.enroll(
      network: CkbNetwork.testnet,
      mnemonic: wallet.mnemonic,
      passkey: PasskeyEnrollment(
        credentialId: 'cred',
        prfSalt: randomBytes(32),
        wrapKey: deriveWrapKey(secret),
        platformPasskey: false,
        localWrapSecret: bytesToHex(secret),
      ),
    );
    expect(session.address, isNotEmpty);
    expect(session.vault.encryptedSecret, isNot(contains(wallet.mnemonic)));

    final unlocked = WalletSession.unlock(
      vault: session.vault,
      wrapKey: deriveWrapKey(secret),
    );
    expect(unlocked.mnemonic, wallet.mnemonic);
    expect(unlocked.derivedAccount.address, session.address);
  });
}
