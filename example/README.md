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

1. Pick testnet or mainnet (you can switch later in the wallet).
2. **Generate mnemonic** — create a new 12-word BIP-39 phrase (`CkbMnemonicWallet.generate`). **Import mnemonic** restores an existing phrase. Both derive `m/44'/309'/0'/0/0`.
3. **Passkey** — create a WebAuthn passkey on web, or a local secp256r1 key on other platforms, then encode a JoyID lock address.
4. **Receive** — share the address (testnet faucet: https://faucet.nervos.org/).
5. **Send** — mnemonic wallets transfer CKB through `CkbLightClient.transferCkb`.
6. **Cells** — track live cells for your wallet or any address.
