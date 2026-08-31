/// CKB network used for address prefixes and known script hashes.
enum CkbNetwork {
  mainnet,
  testnet;

  /// Bech32 human-readable part (`ckb` / `ckt`).
  String get hrp => this == CkbNetwork.mainnet ? 'ckb' : 'ckt';

  /// JoyID (WebAuthn / passkey) lock `code_hash`.
  String get joyIdCodeHash => this == CkbNetwork.mainnet
      ? '0xd00c84f0ec8fd441c38bc3f87a371f547190f2fcff88e642bc5bf54b9e318323'
      : '0xd23761b364210735c19c60561d213fb3beae2fd6172743719eff6920e020baac';

  static CkbNetwork fromHrp(String hrp) {
    switch (hrp.toLowerCase()) {
      case 'ckb':
        return CkbNetwork.mainnet;
      case 'ckt':
        return CkbNetwork.testnet;
      default:
        throw FormatException('Unknown CKB address prefix: $hrp');
    }
  }
}
