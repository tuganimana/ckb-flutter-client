# ckb_flutter_client

Flutter/Dart client for a running [CKB light client](https://github.com/nervosnetwork/ckb-light-client) JSON-RPC endpoint.

The package talks to `ckb-light-client` over HTTP. It does not embed the Rust binary — run a light client (default `http://127.0.0.1:9000`) and point this client at it.

## Features

- JSON-RPC 2.0 transport with typed errors
- Header sync snapshot (`get_tip_header`, `get_header`, `fetch_header`)
- Script filters (`set_scripts`, `get_scripts`)
- Cell queries by lock (`get_cells`, `get_cells_capacity`)
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

final client = CkbLightClient(rpcUrl: 'http://127.0.0.1:9000');

final sync = await client.getHeaderSyncStatus();
print('tip #${sync.tip.numberInt} peers=${sync.peerCount}');

final lock = CkbScript.secp256k1Blake160(
  '0x64257f00b6b63e987609fa9be2d0c86d351020fb',
);
await client.setScripts(
  [ScriptStatus.lock(lock)],
  command: SetScriptsCommand.partial,
);

final cells = await client.getCellsByLock(lock);
print('live cells: ${cells.objects.length}');

client.close();
```

## Run the example app

```bash
cd example
flutter pub get
flutter run -d macos   # or chrome / ios / android
```

The example loads header sync from the RPC URL, then can register a lock script and list live cells.

## Light client node

Follow [Run a Light Client Node](https://docs.nervos.org/docs/node/run-light-client-node). Once it is up:

```bash
curl http://127.0.0.1:9000/ -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"get_tip_header","params":[],"id":1}'
```
