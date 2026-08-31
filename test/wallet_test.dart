import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full address encode matches RFC 0021', () {
    const script = CkbScript(
      codeHash:
          '0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8',
      hashType: HashType.type,
      args: '0xb39bbc0b3673c7d36450bc14cfcdad2d559c6c64',
    );

    expect(
      CkbAddress.encode(script, network: CkbNetwork.mainnet),
      'ckb1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqdnnw7qkdnnclfkg59uzn8umtfd2kwxceqxwquc4',
    );
  });

  test('full address round-trips', () {
    const encoded =
        'ckb1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqdnnw7qkdnnclfkg59uzn8umtfd2kwxceqxwquc4';
    final decoded = CkbAddress.decode(encoded);
    expect(decoded.network, CkbNetwork.mainnet);
    expect(decoded.script.hashType, HashType.type);
    expect(decoded.script.codeHash, CkbScript.secp256k1Blake160CodeHash);
    expect(decoded.script.args, '0xb39bbc0b3673c7d36450bc14cfcdad2d559c6c64');
    expect(decoded.encoded, encoded);
  });

  test('mnemonic generate and restore yield the same address', () {
    final generated = CkbMnemonicWallet.generate();
    expect(generated.mnemonic.split(' '), hasLength(12));

    final restored = CkbMnemonicWallet.fromMnemonic(
      generated.mnemonic,
      network: CkbNetwork.testnet,
    );
    final a = generated.deriveDefault();
    final b = restored.deriveDefault();

    expect(a.path, ckbDefaultDerivationPath);
    expect(a.address, startsWith('ckt1'));
    expect(a.address, b.address);
    expect(a.lock.args, b.lock.args);
    expect(hexToBytes(a.lock.args), hasLength(20));
  });

  test('known mnemonic derives a stable testnet address', () {
    const mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    final wallet = CkbMnemonicWallet.fromMnemonic(mnemonic);
    final account = wallet.deriveDefault();
    expect(account.publicKey, hasLength(33));
    expect(account.privateKey, hasLength(32));
    expect(CkbAddress.decode(account.address).script.args, account.lock.args);
  });

  test('passkey account builds a JoyID lock and fundable address', () {
    final keys = CkbPasskeyKeyPair.generate();
    final account = keys.account(network: CkbNetwork.testnet);
    expect(account.uncompressedPublicKey, hasLength(64));
    expect(hexToBytes(account.lock.args), hasLength(22));
    expect(stripHexPrefix(account.lock.args), startsWith('0001'));
    expect(account.lock.codeHash, CkbNetwork.testnet.joyIdCodeHash);
    expect(account.address, startsWith('ckt1'));

    final decoded = CkbAddress.decode(account.address);
    expect(decoded.script.args, account.lock.args);
    expect(decoded.script.codeHash, account.lock.codeHash);
  });

  test('passkey public key accepts 65-byte uncompressed form', () {
    final keys = CkbPasskeyKeyPair.generate();
    final withPrefix = [0x04, ...keys.uncompressedPublicKey];
    final a = CkbPasskeyAccount.fromPublicKey(keys.uncompressedPublicKey);
    final b = CkbPasskeyAccount.fromPublicKey(withPrefix);
    expect(a.address, b.address);
  });
}
