import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../passkey_service.dart';
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
  CkbMnemonicWallet? _wallet;
  CkbDerivedAccount? _account;
  final _import = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _import.dispose();
    super.dispose();
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

  Future<void> _protectWithPasskey() async {
    final wallet = _wallet;
    final account = _account;
    if (wallet == null || account == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final passkey = await enrollPasskey();
      final session = await WalletSession.enroll(
        network: widget.network,
        mnemonic: wallet.mnemonic,
        passkey: passkey,
      );
      widget.onCreated(session);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;
    final account = _account;
    final words = wallet?.mnemonic.split(' ') ?? const <String>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Import recovery phrase')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Paste an existing 12- or 24-word BIP-39 phrase. A passkey then wraps those keys so later sign-in can unlock this self-custodial wallet.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _import,
            minLines: 2,
            maxLines: 4,
            enabled: !_busy,
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
              onPressed: _busy ? null : _restore,
              child: const Text('Restore phrase'),
            ),
          ),
          if (wallet != null && account != null) ...[
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
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
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
            FilledButton.icon(
              onPressed: _busy ? null : _protectWithPasskey,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Protect with passkey'),
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator(),
            ),
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
