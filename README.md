# ckb_flutter_client

Flutter/Dart client for a running [CKB light client](https://github.com/nervosnetwork/ckb-light-client) JSON-RPC endpoint.

The package talks to a CKB JSON-RPC node over HTTP (public testnet/mainnet by default). It also derives wallets: BIP-39 mnemonics (secp256k1-blake160) and passkey / JoyID locks (secp256r1), then encodes fundable CKB addresses.

## Features

- JSON-RPC 2.0 transport with typed errors
- Header sync snapshot (`get_tip_header`, `get_header`, `fetch_header`)
- Script filters (`set_scripts`, `get_scripts`)
- Cell queries by lock (`get_cells`, `get_cells_capacity`)
- Mnemonic wallets (`m/44'/309'/0'/0/0`) and CKB full addresses
- Passkey / JoyID lock addresses from a P-256 public key
- Transactions, peers, and `local_node_info`

## Install

In your app `pubspec.yaml`:

```yaml
dependencies:
  ckb_flutter_client:
    path: ../ckb_flutter_client
```

Then:

```bash
flutter pub get
```

## Usage

```dart
import 'package:ckb_flutter_client/ckb_flutter_client.dart';

final wallet = CkbMnemonicWallet.generate(network: CkbNetwork.testnet);
final account = wallet.deriveDefault();
print(account.address); // fund this

final client = CkbLightClient(
  rpcUrl: CkbLightClient.publicRpcUrlFor(CkbNetwork.testnet),
);
await client.watchAddress(account.address);
final capacity = await client.getCapacityByAddress(account.address);
print('${capacity.capacityCkb} CKB');
client.close();
```

Passkey / JoyID:

```dart
final keys = CkbPasskeyKeyPair.generate();
final passkey = keys.account(network: CkbNetwork.testnet);
print(passkey.address);
```

## Run the example app

```bash
cd example
flutter pub get
flutter run -d macos   # or chrome / ios / android
```

The example creates a mnemonic or passkey wallet, shows the CKB address to fund, then watches that lock on the public testnet (`https://testnet.ckb.dev/rpc`) or mainnet (`https://mainnet.ckb.dev/rpc`) RPC.
