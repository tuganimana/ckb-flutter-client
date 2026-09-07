import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WitnessArgs with 65-byte lock matches CKB molecule layout', () {
    final encoded = Molecule.witnessArgs(lock: List.filled(65, 0));
    expect(encoded.length, 85);
    expect(encoded[0], 85);
    expect(encoded[4], 16);
    expect(encoded[8], 85);
    expect(encoded[12], 85);
    expect(encoded[16], 65);
    expect(encoded.sublist(20), everyElement(0));
  });

  test('secp256k1 recoverable signature recovers the public key', () {
    final wallet = CkbMnemonicWallet.fromMnemonic(
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    );
    final account = wallet.deriveDefault();
    final message = CkbHash.blake2b(List<int>.generate(32, (i) => i));
    final signature = signRecoverable(message, account.privateKey);
    expect(signature, hasLength(65));
    final recovered = recoverPublicKey(
      message,
      BigInt.parse(
        bytesToHex(signature.sublist(0, 32), withPrefix: false),
        radix: 16,
      ),
      BigInt.parse(
        bytesToHex(signature.sublist(32, 64), withPrefix: false),
        radix: 16,
      ),
      signature[64],
    );
    expect(recovered, account.publicKey);
  });

  test('transfer builder creates a signed secp256k1 transaction', () {
    final wallet = CkbMnemonicWallet.fromMnemonic(
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    );
    final from = wallet.deriveDefault();
    final to = wallet.derive(index: 1).address;
    final cell = IndexedCell(
      output: CellOutput(
        capacity: toHexUint(200 * shannonsPerCkb),
        lock: from.lock,
      ),
      outPoint: const OutPoint(
        txHash:
            '0xe8f2180dfba0cb15b45f771d520834515a5f8d7aa07f88894da88c22629b79e9',
        index: '0x0',
      ),
      blockNumber: '0x10',
      txIndex: '0x0',
      outputData: '0x',
    );

    final signed = CkbSecp256k1Transfer.build(
      from: from,
      toAddress: to,
      amountShannons: 70 * shannonsPerCkb,
      cells: [cell],
    );

    expect(signed.txHash, startsWith('0x'));
    expect(hexToBytes(signed.txHash), hasLength(32));
    expect(signed.raw['inputs'], hasLength(1));
    expect(signed.raw['outputs'], hasLength(2));
    expect((signed.raw['witnesses'] as List).first, startsWith('0x'));
    expect(
      hexToBytes((signed.raw['witnesses'] as List).first as String).length,
      85,
    );
  });

  test('transfer builder rejects amounts below occupancy', () {
    final wallet = CkbMnemonicWallet.generate();
    final from = wallet.deriveDefault();
    expect(
      () => CkbSecp256k1Transfer.build(
        from: from,
        toAddress: from.address,
        amountShannons: 10 * shannonsPerCkb,
        cells: const [],
      ),
      throwsA(isA<CkbTransferException>()),
    );
  });
}
