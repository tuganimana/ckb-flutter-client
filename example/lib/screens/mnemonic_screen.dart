import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:flutter/material.dart';

import '../session.dart';
import '../widgets.dart';

class MnemonicScreen extends StatefulWidget {
  const MnemonicScreen({
    super.key,
    required this.network,
    required this.onCreated,
  });

  final CkbNetwork network;
  final ValueChanged<WalletSession> onCreated;

  @override
  State<MnemonicScreen> createState() => _MnemonicScreenState();
}

class _MnemonicScreenState extends State<MnemonicScreen> {
  late CkbMnemonicWallet _wallet;
  late CkbDerivedAccount _account;
  final _import = TextEditingController();
  String? _error;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _import.dispose();
    super.dispose();
  }

  void _generate() {
    final wallet = CkbMnemonicWallet.generate(network: widget.network);
    setState(() {
      _wallet = wallet;
      _account = wallet.deriveDefault();
      _error = null;
    });
  }

  void _restore() {
    try {
      final wallet = CkbMnemonicWallet.fromMnemonic(
        _import.text,
        network: widget.network,
      );
      setState(() {
        _wallet = wallet;
        _account = wallet.deriveDefault();
        _importing = false;
        _error = null;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _continue() async {
    final session = WalletSession(
      kind: WalletKind.mnemonic,
      network: widget.network,
      address: _account.address,
      rpcUrl: CkbLightClient.publicRpcUrlFor(widget.network),
      mnemonic: _wallet.mnemonic,
    );
    await session.save();
    widget.onCreated(session);
  }

  @override
  Widget build(BuildContext context) {
    final words = _wallet.mnemonic.split(' ');
    return Scaffold(
      appBar: AppBar(title: const Text('Mnemonic wallet')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Write down these 12 words. They restore this wallet. The address below is what you fund.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < words.length; i++)
                    Chip(label: Text('${i + 1}. ${words[i]}')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh),
                label: const Text('New phrase'),
              ),
              TextButton(
                onPressed: () => setState(() => _importing = !_importing),
                child: Text(_importing ? 'Hide import' : 'Import phrase'),
              ),
            ],
          ),
          if (_importing) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _import,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Recovery phrase',
                hintText: 'twelve words …',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: _restore,
                child: const Text('Restore'),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          InfoCard(
            title: 'Address to fund',
            child: CopyableText(value: _account.address),
          ),
          const SizedBox(height: 8),
          Text(
            'Path ${_account.path} · ${widget.network.name}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _continue,
            child: const Text("I've saved this phrase"),
          ),
        ],
      ),
    );
  }
}
