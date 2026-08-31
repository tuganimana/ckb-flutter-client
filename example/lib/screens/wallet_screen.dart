import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:flutter/material.dart';

import '../session.dart';
import '../widgets.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
    required this.session,
    required this.onRpcUrlChanged,
    required this.onReset,
  });

  final WalletSession session;
  final ValueChanged<String> onRpcUrlChanged;
  final VoidCallback onReset;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late final TextEditingController _rpcUrl;
  bool _busy = false;
  bool _showMnemonic = false;
  String? _error;
  HeaderSyncStatus? _sync;
  CellsCapacity? _capacity;
  List<IndexedCell> _cells = const [];

  @override
  void initState() {
    super.initState();
    _rpcUrl = TextEditingController(
      text: WalletSession.rpcUrlFor(
        widget.session.network,
        stored: widget.session.rpcUrl,
      ),
    );
    if (_rpcUrl.text != widget.session.rpcUrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onRpcUrlChanged(_rpcUrl.text);
      });
    }
  }

  @override
  void dispose() {
    _rpcUrl.dispose();
    super.dispose();
  }

  CkbLightClient _client() => CkbLightClient(rpcUrl: _rpcUrl.text.trim());

  Future<void> _run(Future<void> Function(CkbLightClient client) action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onRpcUrlChanged(_rpcUrl.text.trim());
    final client = _client();
    try {
      await action(client);
    } catch (error) {
      setState(() => _error = _describeError(error));
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadSync() {
    return _run((client) async {
      final sync = await client.getHeaderSyncStatus();
      setState(() => _sync = sync);
    });
  }

  Future<void> _watchAndRefresh() {
    return _run((client) async {
      await client.watchAddress(widget.session.address);
      final capacity = await client.getCapacityByAddress(
        widget.session.address,
      );
      final cells = await client.getCellsByAddress(
        widget.session.address,
        limit: 10,
      );
      setState(() {
        _capacity = capacity;
        _cells = cells.objects;
      });
    });
  }

  String _describeError(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection timed out')) {
      return 'Nothing is listening at ${_rpcUrl.text.trim()}. '
          'Start a local ckb-light-client, or use the public '
          '${widget.session.network.name} RPC.';
    }
    return text;
  }

  bool get _canSwitchToPublicRpc {
    final error = _error?.toLowerCase() ?? '';
    return error.contains('nothing is listening') ||
        error.contains('connection refused') ||
        error.contains('clientexception');
  }

  Future<void> _usePublicRpc() {
    final url = CkbLightClient.publicRpcUrlFor(widget.session.network);
    _rpcUrl.text = url;
    widget.onRpcUrlChanged(url);
    return _loadSync();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final sync = _sync;
    final kindLabel = session.kind == WalletKind.mnemonic
        ? 'Mnemonic'
        : 'Passkey';
    return Scaffold(
      appBar: AppBar(
        title: const Text('CKB Wallet'),
        actions: [
          IconButton(
            tooltip: 'Reset wallet',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset wallet?'),
                  content: const Text(
                    'This removes the local wallet from this example app.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) widget.onReset();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(kindLabel)),
              Chip(label: Text(session.network.name)),
            ],
          ),
          const SizedBox(height: 16),
          InfoCard(
            title: 'Address to fund',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CopyableText(value: session.address),
                const SizedBox(height: 8),
                Text(
                  session.network == CkbNetwork.testnet
                      ? 'Send testnet CKB to this address, then watch it below. Faucet: https://faucet.nervos.org/'
                      : 'Send CKB to this address, then watch it with the light client below.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (session.kind == WalletKind.mnemonic &&
              session.mnemonic != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() => _showMnemonic = !_showMnemonic),
              icon: Icon(
                _showMnemonic ? Icons.visibility_off : Icons.visibility,
              ),
              label: Text(
                _showMnemonic ? 'Hide recovery phrase' : 'Show recovery phrase',
              ),
            ),
            if (_showMnemonic)
              InfoCard(
                title: 'Recovery phrase',
                child: CopyableText(value: session.mnemonic!),
              ),
          ],
          const SizedBox(height: 24),
          Text('RPC', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _rpcUrl,
            decoration: InputDecoration(
              labelText: 'RPC URL',
              helperText: session.network == CkbNetwork.mainnet
                  ? CkbLightClient.publicMainnetRpcUrl
                  : CkbLightClient.publicTestnetRpcUrl,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _loadSync,
                icon: const Icon(Icons.sync),
                label: const Text('Load header sync'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _watchAndRefresh,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Watch address'),
              ),
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  if (_canSwitchToPublicRpc) ...[
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: _busy ? null : _usePublicRpc,
                      child: Text(
                        'Use public ${widget.session.network.name} RPC',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (sync != null) ...[
            const SizedBox(height: 16),
            InfoCard(
              title: 'Header sync',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText('Tip #${sync.tip.numberInt}'),
                  SelectableText('Hash ${sync.tip.hash}'),
                  SelectableText(
                    'Node ${sync.node.version} (${sync.node.active ? 'active' : 'inactive'})',
                  ),
                  SelectableText('Peers ${sync.peerCount}'),
                ],
              ),
            ),
          ],
          if (_capacity != null) ...[
            const SizedBox(height: 16),
            InfoCard(
              title: 'Balance',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_capacity!.capacityCkb.toStringAsFixed(4)} CKB',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SelectableText('Block ${_capacity!.blockNumber}'),
                ],
              ),
            ),
          ],
          if (_cells.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Live cells (${_cells.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final cell in _cells)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${cell.output.capacityShannons / 100000000} CKB'),
                subtitle: Text(
                  '${cell.outPoint.txHash}\nblock ${cell.blockNumber}',
                ),
                isThreeLine: true,
              ),
          ],
        ],
      ),
    );
  }
}
