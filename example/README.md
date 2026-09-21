# CKB wallet example

Example app for [`ckb_flutter_client`](../). It is a **self-custodial** wallet: keys are generated or imported on the device, wrapped with a passkey, and only decrypted in memory after passkey sign-in.

To add the package to your own app, see **Installation** in the [package README](../README.md#installation).

## Run

```bash
flutter pub get
flutter run -d chrome   # WebAuthn passkeys
flutter run -d macos    # local key wrap (no platform passkey API)
```

RPCs (picked from the network toggle):

- Testnet: `https://testnet.ckb.dev/rpc`
- Mainnet: `https://mainnet.ckb.dev/rpc`

## Flow

1. Pick testnet or mainnet.
2. **Create wallet** — generate a BIP-39 seed (`m/44'/309'/0'/0/0`) and create a passkey that wraps it. On web this is WebAuthn (Touch ID / Face ID / security key). Other platforms use a local wrapping key.
3. **Import recovery phrase** — restore an existing seed, then bind a passkey to unlock it later.
4. **Sign in** — after the app is locked or restarted, authenticate with the passkey to load keys in memory. The encrypted vault stays on device; there is no hosted account.
5. **Receive** — share the address (testnet faucet: https://faucet.nervos.org/).
6. **Send** — transfers CKB with `CkbLightClient.transferCkb` while the session is unlocked.
7. **Lock** — drops in-memory keys and requires passkey sign-in again. **Delete** only removes the local vault.

On browsers that support the WebAuthn **PRF** extension, the wrap key comes from the authenticator. Otherwise the example still requires a passkey assertion (or an explicit local unlock) before decrypting keys for that session.
