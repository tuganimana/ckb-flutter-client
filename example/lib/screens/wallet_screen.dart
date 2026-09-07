import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:flutter/material.dart';

import '../session.dart';
import '../widgets.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
    required this.session,
    required this.onSessionChanged,
    required this.onGenerateMnemonic,
    required this.onReset,
  });

  final WalletSession session;
  final ValueChanged<WalletSession> onSessionChanged;
  final VoidCallback onGenerateMnemonic;
  final VoidCallback onReset;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _rpcUrl;
  late final TextEditingController _sendTo;
  late final TextEditingController _sendAmount;
  late final TextEditingController _trackAddress;
  late final TabController _tabs;

  bool _busy = false;
  String? _error;
  String? _txHash;
  CellsCapacity? _capacity;
  List<IndexedCell> _cells = const [];
  String _trackedAddress = '';

  WalletSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _rpcUrl = TextEditingController(
      text: WalletSession.rpcUrlFor(session.network, stored: session.rpcUrl),
    );
    _sendTo = TextEditingController();
    _sendAmount = TextEditingController();
    _trackAddress = TextEditingController(text: session.address);
    _trackedAddress = session.address;
    if (_rpcUrl.text != session.rpcUrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSessionChanged(session.copyWith(rpcUrl: _rpcUrl.text));
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshWallet();
    });
  }

  @override
  void didUpdateWidget(covariant WalletScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.address != session.address ||
        oldWidget.session.network != session.network) {
      _rpcUrl.text = session.rpcUrl;
      _trackAddress.text = session.address;
      _trackedAddress = session.address;
      _capacity = null;
      _cells = const [];
      _txHash = null;
      _refreshWallet();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _rpcUrl.dispose();
    _sendTo.dispose();
    _sendAmount.dispose();
    _trackAddress.dispose();
    super.dispose();
  }

  CkbLightClient _client() => CkbLightClient(rpcUrl: _rpcUrl.text.trim());

  Future<void> _run(Future<void> Function(CkbLightClient client) action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final nextRpc = _rpcUrl.text.trim();
    if (nextRpc != session.rpcUrl) {
      widget.onSessionChanged(session.copyWith(rpcUrl: nextRpc));
    }
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

  Future<void> _refreshWallet() {
    return _run((client) async {
      await client.watchAddress(session.address);
      final capacity = await client.getCapacityByAddress(session.address);
      final cells = await client.getCellsByAddress(
        _trackedAddress.isEmpty ? session.address : _trackedAddress,
        limit: 20,
        withData: true,
      );
      setState(() {
        _capacity = capacity;
        _cells = cells.objects;
      });
    });
  }

  Future<void> _trackCells() {
    final address = _trackAddress.text.trim();
    CkbAddress.decode(address);
    setState(() => _trackedAddress = address);
    return _run((client) async {
      await client.watchAddress(address);
      final cells = await client.getCellsByAddress(
        address,
        limit: 20,
        withData: true,
      );
      setState(() => _cells = cells.objects);
    });
  }

  Future<void> _send() {
    final account = session.derivedAccount;
    if (account == null) {
      setState(() => _error = 'Sending requires a mnemonic wallet.');
      return Future.value();
    }
    final amount = double.tryParse(_sendAmount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a CKB amount greater than 0.');
      return Future.value();
    }
    return _run((client) async {
      final signed = await client.transferCkb(
        from: account,
        toAddress: _sendTo.text.trim(),
        amountShannons: ckbToShannons(amount),
      );
      setState(() {
        _txHash = signed.txHash;
        _sendAmount.clear();
      });
      final capacity = await client.getCapacityByAddress(session.address);
      final cells = await client.getCellsByAddress(session.address, limit: 20);
      setState(() {
        _capacity = capacity;
        _cells = cells.objects;
        _trackedAddress = session.address;
        _trackAddress.text = session.address;
      });
    });
  }

  String _describeError(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection timed out')) {
      return 'Could not reach ${_rpcUrl.text.trim()}.';
    }
    return text;
  }

  Future<void> _switchNetwork(CkbNetwork network) async {
    if (network == session.network) return;
    if (network == CkbNetwork.mainnet) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Switch to mainnet?'),
          content: const Text(
            'Mainnet uses real CKB. The receive address will change.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    widget.onSessionChanged(session.switchNetwork(network));
  }

  @override
  Widget build(BuildContext context) {
    final kindLabel = session.kind == WalletKind.mnemonic
        ? 'Mnemonic'
        : 'Passkey';
    return Scaffold(
      appBar: AppBar(
        title: const Text('CKB Wallet'),
        actions: [
          PopupMenuButton<CkbNetwork>(
            tooltip: 'Network',
            onSelected: _switchNetwork,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: CkbNetwork.testnet,
                child: Text('Testnet'),
              ),
              const PopupMenuItem(
                value: CkbNetwork.mainnet,
                child: Text('Mainnet'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Chip(
                label: Text(session.network.name),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Generate mnemonic',
            onPressed: widget.onGenerateMnemonic,
            icon: const Icon(Icons.auto_awesome),
          ),
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
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Receive'),
            Tab(text: 'Send'),
            Tab(text: 'Cells'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Chip(label: Text(kindLabel)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _capacity == null
                        ? 'Balance —'
                        : '${_capacity!.capacityCkb.toStringAsFixed(4)} CKB',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _busy ? null : _refreshWallet,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ReceiveTab(session: session),
                _SendTab(
                  session: session,
                  toController: _sendTo,
                  amountController: _sendAmount,
                  busy: _busy,
                  txHash: _txHash,
                  onSend: _send,
                  onGenerateMnemonic: widget.onGenerateMnemonic,
                ),
                _CellsTab(
                  session: session,
                  trackController: _trackAddress,
                  trackedAddress: _trackedAddress,
                  cells: _cells,
                  busy: _busy,
                  onTrack: _trackCells,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiveTab extends StatelessWidget {
  const _ReceiveTab({required this.session});

  final WalletSession session;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        InfoCard(
          title: 'Receive CKB',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CopyableText(value: session.address, label: 'Your address'),
              const SizedBox(height: 8),
              Text(
                session.network == CkbNetwork.testnet
                    ? 'Share this address to receive testnet CKB. Faucet: https://faucet.nervos.org/'
                    : 'Share this address to receive mainnet CKB.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SendTab extends StatelessWidget {
  const _SendTab({
    required this.session,
    required this.toController,
    required this.amountController,
    required this.busy,
    required this.txHash,
    required this.onSend,
    required this.onGenerateMnemonic,
  });

  final WalletSession session;
  final TextEditingController toController;
  final TextEditingController amountController;
  final bool busy;
  final String? txHash;
  final VoidCallback onSend;
  final VoidCallback onGenerateMnemonic;

  @override
  Widget build(BuildContext context) {
    final canSend = session.kind == WalletKind.mnemonic;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        InfoCard(
          title: 'Send CKB',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!canSend) ...[
                Text(
                  'Passkey / JoyID locks cannot send from this example. Generate a mnemonic wallet to transfer CKB.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onGenerateMnemonic,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate mnemonic'),
                ),
              ] else ...[
                TextField(
                  controller: toController,
                  decoration: const InputDecoration(
                    labelText: 'Recipient address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (CKB)',
                    helperText: 'Minimum 61 CKB for a new cell',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: busy ? null : onSend,
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                ),
              ],
              if (txHash != null) ...[
                const SizedBox(height: 16),
                CopyableText(value: txHash!, label: 'Transaction hash'),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CellsTab extends StatelessWidget {
  const _CellsTab({
    required this.session,
    required this.trackController,
    required this.trackedAddress,
    required this.cells,
    required this.busy,
    required this.onTrack,
  });

  final WalletSession session;
  final TextEditingController trackController;
  final String trackedAddress;
  final List<IndexedCell> cells;
  final bool busy;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        InfoCard(
          title: 'Track cells',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Watch live cells for your wallet or any CKB address.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: trackController,
                decoration: const InputDecoration(
                  labelText: 'Address to track',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : onTrack,
                icon: const Icon(Icons.search),
                label: const Text('Track cells'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          cells.isEmpty ? 'No live cells' : 'Live cells (${cells.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (trackedAddress.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(trackedAddress, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 8),
        for (final cell in cells)
          Card(
            child: ListTile(
              title: Text(
                '${shannonsToCkb(cell.output.capacityShannons).toStringAsFixed(4)} CKB',
              ),
              subtitle: Text(
                '${cell.outPoint.txHash}\nblock ${cell.blockNumber}'
                '${cell.output.type == null ? '' : ' · has type script'}',
              ),
              isThreeLine: true,
            ),
          ),
        if (session.rpcUrl.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'RPC ${session.rpcUrl}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
