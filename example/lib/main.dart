import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const CkbLightClientExampleApp());
}

class CkbLightClientExampleApp extends StatelessWidget {
  const CkbLightClientExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ckb_flutter_client',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3CC68A)),
        useMaterial3: true,
      ),
      home: const LightClientHomePage(),
    );
  }
}

class LightClientHomePage extends StatefulWidget {
  const LightClientHomePage({super.key});

  @override
  State<LightClientHomePage> createState() => _LightClientHomePageState();
}

class _LightClientHomePageState extends State<LightClientHomePage> {
  final _rpcUrl = TextEditingController(text: CkbLightClient.defaultRpcUrl);
  final _lockArgs = TextEditingController(
    text: '0x64257f00b6b63e987609fa9be2d0c86d351020fb',
  );

  bool _busy = false;
  String? _error;
  HeaderSyncStatus? _sync;
  CellsCapacity? _capacity;
  List<IndexedCell> _cells = const [];

  @override
  void dispose() {
    _rpcUrl.dispose();
    _lockArgs.dispose();
    super.dispose();
  }

  CkbLightClient _client() => CkbLightClient(rpcUrl: _rpcUrl.text.trim());

  Future<void> _run(Future<void> Function(CkbLightClient client) action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = _client();
    try {
      await action(client);
    } catch (error) {
      setState(() => _error = error.toString());
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

  Future<void> _queryLock() {
    return _run((client) async {
      final lock = CkbScript.secp256k1Blake160(_lockArgs.text.trim());
      await client.setScripts([
        ScriptStatus.lock(lock),
      ], command: SetScriptsCommand.partial);
      final capacity = await client.getCapacityByLock(lock);
      final cells = await client.getCellsByLock(lock, limit: 10);
      setState(() {
        _capacity = capacity;
        _cells = cells.objects;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = _sync;
    return Scaffold(
      appBar: AppBar(title: const Text('CKB Flutter Client')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _rpcUrl,
            decoration: const InputDecoration(
              labelText: 'Light client RPC URL',
              helperText: 'Default is http://127.0.0.1:9000',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _loadSync,
            icon: const Icon(Icons.sync),
            label: const Text('Load header sync'),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (sync != null) ...[
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Header sync',
              lines: [
                'Tip #${sync.tip.numberInt}',
                'Hash ${sync.tip.hash}',
                'Node ${sync.node.version} (${sync.node.active ? 'active' : 'inactive'})',
                'Peers ${sync.peerCount}',
              ],
            ),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: _lockArgs,
            decoration: const InputDecoration(
              labelText: 'Lock args (blake160)',
              helperText: 'Queries live cells for a secp256k1-blake160 lock',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _queryLock,
            icon: const Icon(Icons.search),
            label: const Text('Set script + query cells'),
          ),
          if (_capacity != null) ...[
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Lock capacity',
              lines: [
                '${_capacity!.capacityCkb.toStringAsFixed(4)} CKB',
                'Block ${_capacity!.blockNumber}',
              ],
            ),
          ],
          if (_cells.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Live cells (${_cells.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final cell in _cells)
              ListTile(
                dense: true,
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(line),
              ),
          ],
        ),
      ),
    );
  }
}
