import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'hex.dart';
import 'json_rpc_client.dart';
import 'models/models.dart';
import 'wallet/address.dart';
import 'wallet/hd_wallet.dart';
import 'wallet/network.dart';
import 'wallet/transfer.dart';

export 'exceptions.dart';
export 'hex.dart';
export 'models/models.dart';

/// Dart/Flutter client for CKB JSON-RPC (light client or public full node).
///
/// Defaults to the public testnet RPC. Use [publicRpcUrlFor] for mainnet, or
/// `http://127.0.0.1:9000` for a local `ckb-light-client`.
class CkbLightClient {
  CkbLightClient({
    this.rpcUrl = defaultRpcUrl,
    Duration timeout = const Duration(seconds: 15),
    http.Client? httpClient,
  }) : _ownsClient = httpClient == null,
       _httpClient = httpClient ?? http.Client() {
    _rpc = JsonRpcClient(
      rpcUrl: rpcUrl,
      httpClient: _httpClient,
      timeout: timeout,
    );
  }

  /// Public Nervos testnet full-node RPC (indexer included).
  static const publicTestnetRpcUrl = 'https://testnet.ckb.dev/rpc';

  /// Public Nervos mainnet full-node RPC (indexer included).
  static const publicMainnetRpcUrl = 'https://mainnet.ckb.dev/rpc';

  /// Public testnet RPC — the default so the client works without a local node.
  static const defaultRpcUrl = publicTestnetRpcUrl;

  /// Public node RPC for [network].
  static String publicRpcUrlFor(CkbNetwork network) {
    return network == CkbNetwork.mainnet
        ? publicMainnetRpcUrl
        : publicTestnetRpcUrl;
  }

  final String rpcUrl;
  final http.Client _httpClient;
  final bool _ownsClient;
  late final JsonRpcClient _rpc;

  void close() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }

  // --- Chain / header sync -------------------------------------------------

  /// Highest canonical header the light client currently knows.
  Future<HeaderView> getTipHeader() async {
    final result = await _rpc.call('get_tip_header');
    return HeaderView.fromJson(result as Map<String, dynamic>);
  }

  /// Local header by hash, or `null` if it is not stored yet.
  Future<HeaderView?> getHeader(String blockHash) async {
    final result = await _rpc.call('get_header', [blockHash]);
    if (result == null) return null;
    return HeaderView.fromJson(result as Map<String, dynamic>);
  }

  /// Ask peers for a header. May return `fetching` / `not_found` before data is ready.
  Future<FetchStatus<HeaderView>> fetchHeader(String blockHash) async {
    final result = await _rpc.call('fetch_header', [blockHash]);
    return FetchStatus.fromJson(
      result as Map<String, dynamic>,
      HeaderView.fromJson,
    );
  }

  /// Genesis block JSON as returned by the light client.
  Future<Map<String, dynamic>> getGenesisBlock() async {
    final result = await _rpc.call('get_genesis_block');
    return result as Map<String, dynamic>;
  }

  /// Tip header plus local node / peer info — a compact sync snapshot.
  Future<HeaderSyncStatus> getHeaderSyncStatus() async {
    final tip = await getTipHeader();
    final node = await localNodeInfo();
    final peers = await getPeers();
    return HeaderSyncStatus(tip: tip, node: node, peers: peers);
  }

  // --- Script filters ------------------------------------------------------

  /// Register lock/type scripts the light client should index.
  Future<void> setScripts(
    List<ScriptStatus> scripts, {
    SetScriptsCommand command = SetScriptsCommand.all,
  }) async {
    await _rpc.call('set_scripts', [
      scripts.map((script) => script.toJson()).toList(),
      command.wireName,
    ]);
  }

  Future<List<ScriptStatus>> getScripts() async {
    final result = await _rpc.call('get_scripts');
    return (result as List<dynamic>)
        .map((item) => ScriptStatus.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // --- Cells ---------------------------------------------------------------

  Future<Pagination<IndexedCell>> getCells({
    required SearchKey searchKey,
    Order order = Order.asc,
    int limit = 50,
    String? afterCursor,
  }) async {
    final params = <dynamic>[
      searchKey.toJson(),
      order.wireName,
      toHexUint(limit),
    ];
    if (afterCursor != null) {
      params.add(afterCursor);
    }
    final result = await _rpc.call('get_cells', params);
    return Pagination.fromJson(
      result as Map<String, dynamic>,
      IndexedCell.fromJson,
    );
  }

  /// Live cells whose lock script matches [lock].
  Future<Pagination<IndexedCell>> getCellsByLock(
    CkbScript lock, {
    Order order = Order.asc,
    int limit = 50,
    String? afterCursor,
    bool withData = false,
  }) {
    return getCells(
      searchKey: SearchKey.byLock(lock, withData: withData),
      order: order,
      limit: limit,
      afterCursor: afterCursor,
    );
  }

  Future<CellsCapacity> getCellsCapacity(SearchKey searchKey) async {
    final result = await _rpc.call('get_cells_capacity', [searchKey.toJson()]);
    return CellsCapacity.fromJson(result as Map<String, dynamic>);
  }

  Future<CellsCapacity> getCapacityByLock(CkbScript lock) {
    return getCellsCapacity(SearchKey.byLock(lock));
  }

  /// Decode [address], register its lock on a light client, and return it.
  ///
  /// Full nodes (for example `testnet.ckb.dev`) do not implement `set_scripts`.
  /// In that case the lock is still returned so [getCapacityByAddress] can run.
  Future<CkbAddress> watchAddress(
    String address, {
    SetScriptsCommand command = SetScriptsCommand.partial,
  }) async {
    final decoded = CkbAddress.decode(address);
    try {
      await setScripts([ScriptStatus.lock(decoded.script)], command: command);
    } on CkbRpcException catch (error) {
      if (!error.isMethodNotFound) rethrow;
    }
    return decoded;
  }

  Future<CellsCapacity> getCapacityByAddress(String address) {
    return getCapacityByLock(CkbAddress.decode(address).script);
  }

  Future<Pagination<IndexedCell>> getCellsByAddress(
    String address, {
    Order order = Order.asc,
    int limit = 50,
    String? afterCursor,
    bool withData = false,
  }) {
    return getCellsByLock(
      CkbAddress.decode(address).script,
      order: order,
      limit: limit,
      afterCursor: afterCursor,
      withData: withData,
    );
  }

  // --- Transactions --------------------------------------------------------

  Future<Pagination<Map<String, dynamic>>> getTransactions({
    required SearchKey searchKey,
    Order order = Order.asc,
    int limit = 50,
    String? afterCursor,
  }) async {
    final params = <dynamic>[
      searchKey.toJson(),
      order.wireName,
      toHexUint(limit),
    ];
    if (afterCursor != null) {
      params.add(afterCursor);
    }
    final result = await _rpc.call('get_transactions', params);
    return Pagination.fromJson(result as Map<String, dynamic>, (json) => json);
  }

  Future<Map<String, dynamic>?> getTransaction(String txHash) async {
    final result = await _rpc.call('get_transaction', [txHash]);
    if (result == null) return null;
    return result as Map<String, dynamic>;
  }

  Future<FetchStatus<Map<String, dynamic>>> fetchTransaction(
    String txHash,
  ) async {
    final result = await _rpc.call('fetch_transaction', [txHash]);
    return FetchStatus.fromJson(result as Map<String, dynamic>, (json) => json);
  }

  Future<String> sendTransaction(Map<String, dynamic> tx) async {
    final result = await _rpc.call('send_transaction', [tx]);
    return result as String;
  }

  /// Collect live CKB cells, sign a secp256k1 transfer, and broadcast it.
  Future<CkbSignedTransaction> transferCkb({
    required CkbDerivedAccount from,
    required String toAddress,
    required int amountShannons,
    int feeShannons = 0,
    int cellLimit = 50,
  }) async {
    await watchAddress(from.address);
    final page = await getCellsByLock(
      from.lock,
      limit: cellLimit,
      withData: true,
    );
    final signed = CkbSecp256k1Transfer.build(
      from: from,
      toAddress: toAddress,
      amountShannons: amountShannons,
      cells: page.objects,
      feeShannons: feeShannons,
    );
    final hash = await sendTransaction(signed.toJson());
    return CkbSignedTransaction(raw: signed.raw, txHash: hash);
  }

  Future<Pagination<Map<String, dynamic>>> getTransactionsByAddress(
    String address, {
    Order order = Order.desc,
    int limit = 20,
    String? afterCursor,
  }) {
    return getTransactions(
      searchKey: SearchKey.byLock(CkbAddress.decode(address).script),
      order: order,
      limit: limit,
      afterCursor: afterCursor,
    );
  }

  Future<Map<String, dynamic>> estimateCycles(Map<String, dynamic> tx) async {
    final result = await _rpc.call('estimate_cycles', [tx]);
    return result as Map<String, dynamic>;
  }

  // --- Network -------------------------------------------------------------

  Future<LocalNode> localNodeInfo() async {
    final result = await _rpc.call('local_node_info');
    return LocalNode.fromJson(result as Map<String, dynamic>);
  }

  Future<List<RemoteNode>> getPeers() async {
    final result = await _rpc.call('get_peers');
    return (result as List<dynamic>)
        .map((item) => RemoteNode.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
