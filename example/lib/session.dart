import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WalletKind { mnemonic, passkey }

class WalletSession {
  const WalletSession({
    required this.kind,
    required this.network,
    required this.address,
    required this.rpcUrl,
    this.mnemonic,
    this.passkeyPublicKey,
    this.platformPasskey = false,
  });

  final WalletKind kind;
  final CkbNetwork network;
  final String address;
  final String rpcUrl;
  final String? mnemonic;
  final String? passkeyPublicKey;
  final bool platformPasskey;

  CkbScript get lock => CkbAddress.decode(address).script;

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

  WalletSession copyWith({String? rpcUrl}) {
    return WalletSession(
      kind: kind,
      network: network,
      address: address,
      rpcUrl: rpcUrl ?? this.rpcUrl,
      mnemonic: mnemonic,
      passkeyPublicKey: passkeyPublicKey,
      platformPasskey: platformPasskey,
    );
  }

  Map<String, String> toMap() => {
    'kind': kind.name,
    'network': network.name,
    'address': address,
    'rpcUrl': rpcUrl,
    'mnemonic': ?mnemonic,
    'passkeyPublicKey': ?passkeyPublicKey,
    'platformPasskey': platformPasskey.toString(),
  };

  static WalletSession fromMap(Map<String, String> map) {
    final network = CkbNetwork.values.byName(map['network']!);
    return WalletSession(
      kind: WalletKind.values.byName(map['kind']!),
      network: network,
      address: map['address']!,
      rpcUrl: rpcUrlFor(network, stored: map['rpcUrl']),
      mnemonic: map['mnemonic'],
      passkeyPublicKey: map['passkeyPublicKey'],
      platformPasskey: map['platformPasskey'] == 'true',
    );
  }

  static const _key = 'ckb_wallet_session';

  static Future<WalletSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_key);
    if (values == null || values.isEmpty) return null;
    final map = <String, String>{};
    for (final entry in values) {
      final split = entry.indexOf('=');
      if (split <= 0) continue;
      map[entry.substring(0, split)] = entry.substring(split + 1);
    }
    if (!map.containsKey('kind') || !map.containsKey('address')) return null;
    final session = WalletSession.fromMap(map);
    if (map['rpcUrl'] != session.rpcUrl) {
      await session.save();
    }
    return session;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      toMap().entries.map((e) => '${e.key}=${e.value}').toList(),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
