import 'dart:convert';
import 'dart:typed_data';

import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'passkey_service.dart';
import 'vault_crypto.dart';

class WalletVault {
  const WalletVault({
    required this.network,
    required this.address,
    required this.rpcUrl,
    required this.credentialId,
    required this.prfSalt,
    required this.encryptedSecret,
    this.passkeyPublicKey,
    this.platformPasskey = false,
    this.prfWrapped = false,
    this.localWrapSecret,
  });

  final CkbNetwork network;
  final String address;
  final String rpcUrl;
  final String credentialId;
  final String prfSalt;
  final String encryptedSecret;
  final String? passkeyPublicKey;
  final bool platformPasskey;
  final bool prfWrapped;
  final String? localWrapSecret;

  static bool isLoopbackRpc(String url) {
    final host = Uri.tryParse(url)?.host;
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  static String rpcUrlFor(CkbNetwork network, {String? stored}) {
    final public = CkbLightClient.publicRpcUrlFor(network);
    if (stored == null || stored.isEmpty || isLoopbackRpc(stored)) {
      return public;
    }
    return stored;
  }

  WalletVault copyWith({
    CkbNetwork? network,
    String? address,
    String? rpcUrl,
    String? encryptedSecret,
  }) {
    return WalletVault(
      network: network ?? this.network,
      address: address ?? this.address,
      rpcUrl: rpcUrl ?? this.rpcUrl,
      credentialId: credentialId,
      prfSalt: prfSalt,
      encryptedSecret: encryptedSecret ?? this.encryptedSecret,
      passkeyPublicKey: passkeyPublicKey,
      platformPasskey: platformPasskey,
      prfWrapped: prfWrapped,
      localWrapSecret: localWrapSecret,
    );
  }

  WalletVault switchNetwork(CkbNetwork next, {required String mnemonic}) {
    if (next == network) return this;
    final account = CkbMnemonicWallet.fromMnemonic(
      mnemonic,
      network: next,
    ).deriveDefault();
    return copyWith(
      network: next,
      address: account.address,
      rpcUrl: CkbLightClient.publicRpcUrlFor(next),
    );
  }

  Map<String, dynamic> toJson() => {
    'network': network.name,
    'address': address,
    'rpcUrl': rpcUrl,
    'credentialId': credentialId,
    'prfSalt': prfSalt,
    'encryptedSecret': encryptedSecret,
    if (passkeyPublicKey != null) 'passkeyPublicKey': passkeyPublicKey,
    'platformPasskey': platformPasskey,
    'prfWrapped': prfWrapped,
    if (localWrapSecret != null) 'localWrapSecret': localWrapSecret,
  };

  static WalletVault fromJson(Map<String, dynamic> json) {
    final network = CkbNetwork.values.byName(json['network'] as String);
    return WalletVault(
      network: network,
      address: json['address'] as String,
      rpcUrl: rpcUrlFor(network, stored: json['rpcUrl'] as String?),
      credentialId: json['credentialId'] as String,
      prfSalt: json['prfSalt'] as String,
      encryptedSecret: json['encryptedSecret'] as String,
      passkeyPublicKey: json['passkeyPublicKey'] as String?,
      platformPasskey: json['platformPasskey'] == true,
      prfWrapped: json['prfWrapped'] == true,
      localWrapSecret: json['localWrapSecret'] as String?,
    );
  }

  static const _key = 'ckb_wallet_vault_v1';
  static const _legacyKey = 'ckb_wallet_session';

  static Future<WalletVault?> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyKey);
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);
    if (map['address'] is! String || map['encryptedSecret'] is! String) {
      return null;
    }
    final vault = WalletVault.fromJson(map);
    if (map['rpcUrl'] != vault.rpcUrl) {
      await vault.save();
    }
    return vault;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_legacyKey);
  }
}

/// In-memory unlocked wallet. The mnemonic only lives here after passkey auth.
class WalletSession {
  const WalletSession({required this.vault, required this.mnemonic});

  final WalletVault vault;
  final String mnemonic;

  CkbNetwork get network => vault.network;
  String get address => vault.address;
  String get rpcUrl => vault.rpcUrl;
  bool get platformPasskey => vault.platformPasskey;

  CkbScript get lock => CkbAddress.decode(address).script;

  CkbDerivedAccount get derivedAccount {
    return CkbMnemonicWallet.fromMnemonic(
      mnemonic,
      network: network,
    ).deriveDefault();
  }

  WalletSession withVault(WalletVault next) =>
      WalletSession(vault: next, mnemonic: mnemonic);

  static Future<WalletSession> authenticate(WalletVault vault) async {
    final assertion = await unlockWithPasskey(
      credentialId: vault.credentialId,
      prfSalt: Uint8List.fromList(base64Decode(vault.prfSalt)),
      localWrapSecret: vault.localWrapSecret,
    );
    return unlock(vault: vault, wrapKey: assertion.wrapKey);
  }

  static WalletSession unlock({
    required WalletVault vault,
    required List<int> wrapKey,
  }) {
    final packed = base64Decode(vault.encryptedSecret);
    final plaintext = decryptSecret(Uint8List.fromList(wrapKey), packed);
    final decoded = jsonDecode(plaintext);
    if (decoded is! Map<String, dynamic> || decoded['mnemonic'] is! String) {
      throw const FormatException('Vault is missing wallet keys');
    }
    final mnemonic = decoded['mnemonic'] as String;
    CkbMnemonicWallet.fromMnemonic(mnemonic, network: vault.network);
    return WalletSession(vault: vault, mnemonic: mnemonic);
  }

  static Future<WalletSession> enroll({
    required CkbNetwork network,
    required String mnemonic,
    required PasskeyEnrollment passkey,
  }) {
    final account = CkbMnemonicWallet.fromMnemonic(
      mnemonic,
      network: network,
    ).deriveDefault();
    final vault = WalletVault(
      network: network,
      address: account.address,
      rpcUrl: CkbLightClient.publicRpcUrlFor(network),
      credentialId: passkey.credentialId,
      prfSalt: base64Encode(passkey.prfSalt),
      encryptedSecret: '',
      passkeyPublicKey: passkey.publicKey == null
          ? null
          : bytesToHex(passkey.publicKey!),
      platformPasskey: passkey.platformPasskey,
      prfWrapped: passkey.prfWrapped,
      localWrapSecret: passkey.prfWrapped ? null : passkey.localWrapSecret,
    );
    return seal(
      vault: vault,
      mnemonic: mnemonic,
      wrapKey: passkey.wrapKey,
    );
  }

  static Future<WalletSession> seal({
    required WalletVault vault,
    required String mnemonic,
    required List<int> wrapKey,
  }) async {
    CkbMnemonicWallet.fromMnemonic(mnemonic, network: vault.network);
    final packed = encryptSecret(
      Uint8List.fromList(wrapKey),
      jsonEncode({'mnemonic': mnemonic}),
    );
    final stored = vault.copyWith(encryptedSecret: base64Encode(packed));
    await stored.save();
    return WalletSession(vault: stored, mnemonic: mnemonic);
  }
}
