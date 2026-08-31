# CKB wallet example

Example app for [`ckb_flutter_client`](../). It sets up a wallet, shows a CKB address to fund, and watches that lock on a public CKB RPC.

## Run

```bash
flutter pub get
flutter run -d macos   # or chrome / ios / android
```

RPCs (picked from the network toggle):

- Testnet: `https://testnet.ckb.dev/rpc`
- Mainnet: `https://mainnet.ckb.dev/rpc`

## Flow

1. Pick testnet or mainnet.
2. **Mnemonic** — generate or import a 12-word BIP-39 phrase. The app derives `m/44'/309'/0'/0/0` and a secp256k1-blake160 address.
3. **Passkey** — create a WebAuthn passkey on web, or a local secp256r1 key on other platforms, then encode a JoyID lock address.
4. Fund the address (testnet faucet: https://faucet.nervos.org/).
5. **Watch address** queries live cells on the public RPC.
