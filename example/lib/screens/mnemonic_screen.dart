import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../session.dart';
import '../widgets.dart';

enum MnemonicSetupMode { generate, import }

class MnemonicScreen extends StatefulWidget {
  const MnemonicScreen({
    super.key,
    required this.network,
    required this.onCreated,
    this.mode = MnemonicSetupMode.generate,
  });

  final CkbNetwork network;
  final ValueChanged<WalletSession> onCreated;
  final MnemonicSetupMode mode;

  @override
  State<MnemonicScreen> createState() => _MnemonicScreenState();
}

class _MnemonicScreenState extends State<MnemonicScreen> {
  CkbMnemonicWallet? _wallet;
  CkbDerivedAccount? _account;
  final _import = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.mode == MnemonicSetupMode.generate) {
      _generate();
    }
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
        _error = null;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _continue() async {
    final wallet = _wallet;
    final account = _account;
    if (wallet == null || account == null) return;
    final session = WalletSession(
      kind: WalletKind.mnemonic,
      network: widget.network,
      address: account.address,
      rpcUrl: CkbLightClient.publicRpcUrlFor(widget.network),
      mnemonic: wallet.mnemonic,
    );
    await session.save();
    widget.onCreated(session);
  }

  @override
  Widget build(BuildContext context) {
    final generating = widget.mode == MnemonicSetupMode.generate;
    final wallet = _wallet;
    final account = _account;
    final words = wallet?.mnemonic.split(' ') ?? const <String>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(generating ? 'Generate mnemonic' : 'Import mnemonic'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            generating
                ? 'A new 12-word BIP-39 phrase is generated with ckb_flutter_client. Write it down — it restores this wallet.'
                : 'Paste an existing 12- or 24-word BIP-39 phrase to restore a secp256k1 CKB address.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (!generating) ...[
            TextField(
              controller: _import,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Recovery phrase',
                hintText: 'word1 word2 … word12',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: _restore,
                child: const Text('Restore phrase'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (wallet != null && account != null) ...[
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
                if (generating)
                  OutlinedButton.icon(
                    onPressed: _generate,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Generate another'),
                  ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: wallet.mnemonic),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Phrase copied')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy phrase'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InfoCard(
              title: 'Address to fund',
              child: CopyableText(value: account.address),
            ),
            const SizedBox(height: 8),
            Text(
              'Path ${account.path} · ${widget.network.name}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _continue,
              child: Text(
                generating ? "I've saved this phrase" : 'Use this wallet',
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
        ],
      ),
    );
  }
}
