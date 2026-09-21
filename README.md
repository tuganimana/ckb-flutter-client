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

## Requirements

| Requirement | Version |
| --- | --- |
| Dart SDK | `^3.12.1` |
| Flutter | `>=1.17.0` |
| Network | HTTPS (or HTTP) access to a CKB JSON-RPC endpoint |

Check your toolchain:

```bash
flutter --version
dart --version
```

This package is **not published to [pub.dev](https://pub.dev)** (`publish_to: none`). Install it from Git or from a local clone.

## Installation

### 1. Add the dependency

Pick **one** of the options below in your app `pubspec.yaml`.

#### Git (recommended)

HTTPS:

```yaml
dependencies:
  ckb_flutter_client:
    git:
      url: https://github.com/tuganimana/ckb-flutter-client.git
      ref: main
```

SSH (use this if the repository is private, or if you already authenticate with GitHub over SSH):

```yaml
dependencies:
  ckb_flutter_client:
    git:
      url: git@github.com:tuganimana/ckb-flutter-client.git
      ref: main
```

Pin a tag or commit instead of `main` when you need a stable revision:

```yaml
      ref: v0.1.0   # or a full commit SHA
```

Equivalent CLI:

```bash
flutter pub add ckb_flutter_client \
  --git-url https://github.com/tuganimana/ckb-flutter-client.git \
  --git-ref main
```

#### Local path

Clone the package next to your app (or anywhere you prefer):

```bash
git clone https://github.com/tuganimana/ckb-flutter-client.git
```

Then point `path` at that directory, relative to **your app's** `pubspec.yaml`:

```yaml
dependencies:
  ckb_flutter_client:
    path: ../ckb-flutter-client
```

If the folder is named `ckb_flutter_client` instead:

```yaml
dependencies:
  ckb_flutter_client:
    path: ../ckb_flutter_client
```

Path dependencies are best for local development. Use a Git dependency (or a pinned `ref`) in shared / CI projects.

### 2. Fetch packages

From your **app** directory (the one that contains `pubspec.yaml`):

```bash
flutter pub get
```

A successful install prints the resolved version of `ckb_flutter_client` and its transitive dependencies (`http`, `bip39_mnemonic`, `pointycastle`).

### 3. Import

```dart
import 'package:ckb_flutter_client/ckb_flutter_client.dart';
```

That single import exposes `CkbLightClient`, mnemonic/passkey wallets, addresses, and RPC models.

## Platform setup

`ckb_flutter_client` is a Dart package (no native plugin). It runs on Android, iOS, macOS, Windows, Linux, and web.

### Android

Release builds need internet access so the client can reach the RPC:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET"/>
```

Debug and profile manifests created by Flutter already include this permission.

If you use a **local HTTP** node (`http://10.0.2.2:9000` on an emulator, or `http://192.168.x.x:9000` on a device), allow cleartext in the application tag:

```xml
<application
    android:usesCleartextTraffic="true"
    ...>
```

### iOS / macOS

Public HTTPS RPCs work with default App Transport Security. A **local HTTP** light client needs an ATS exception, for example:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsLocalNetworking</key>
  <true/>
</dict>
```

### Web

The public Nervos RPCs send CORS headers, so the default testnet/mainnet URLs work from Flutter web. A local node must allow your origin, or you will see CORS failures in the browser console.

## Connect to a CKB node

The client defaults to the public testnet RPC. You do **not** need a local node to start.

| Network | RPC |
| --- | --- |
| Testnet (default) | `https://testnet.ckb.dev/rpc` |
| Mainnet | `https://mainnet.ckb.dev/rpc` |
| Local light client | `http://127.0.0.1:9000` |

```dart
// Public testnet (default)
final client = CkbLightClient();

// Public RPC for a chosen network
final client = CkbLightClient(
  rpcUrl: CkbLightClient.publicRpcUrlFor(CkbNetwork.testnet),
);

// Local ckb-light-client
final client = CkbLightClient(rpcUrl: 'http://127.0.0.1:9000');
```

Public full nodes (including `testnet.ckb.dev`) do not implement light-client-only methods such as `set_scripts`. `watchAddress` ignores that and still lets you query capacity and cells.

## Verify the install

```dart
import 'package:ckb_flutter_client/ckb_flutter_client.dart';

Future<void> main() async {
  final wallet = CkbMnemonicWallet.generate(network: CkbNetwork.testnet);
  final account = wallet.deriveDefault();
  print(account.address);

  final client = CkbLightClient(
    rpcUrl: CkbLightClient.publicRpcUrlFor(CkbNetwork.testnet),
  );
  final tip = await client.getTipHeader();
  print('tip ${tip.number}');
  client.close();
}
```

If this prints a `ckt1…` address and a tip header number, the package is installed and can reach the RPC.

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

await client.transferCkb(
  from: account,
  toAddress: 'ckt1q...',
  amountShannons: ckbToShannons(61),
);
client.close();
```

Passkey / JoyID:

```dart
final keys = CkbPasskeyKeyPair.generate();
final passkey = keys.account(network: CkbNetwork.testnet);
print(passkey.address);
```

Testnet faucet: [https://faucet.nervos.org/](https://faucet.nervos.org/).

## Run the example app

```bash
cd example
flutter pub get
flutter run -d macos   # or chrome / ios / android
```

The example is a self-custodial wallet: it generates or imports keys on device, wraps them with a passkey, and requires passkey sign-in to unlock. On web that uses WebAuthn (`https://testnet.ckb.dev/rpc` / `https://mainnet.ckb.dev/rpc` after login).

## License

MIT. See [LICENSE](LICENSE).
