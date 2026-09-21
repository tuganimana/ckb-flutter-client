import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:flutter/material.dart';

import '../passkey_service.dart';
import '../session.dart';
import '../widgets.dart';

class PasskeyScreen extends StatefulWidget {
  const PasskeyScreen({
    super.key,
    required this.network,
    required this.onCreated,
  });

  final CkbNetwork network;
  final ValueChanged<WalletSession> onCreated;

  @override
  State<PasskeyScreen> createState() => _PasskeyScreenState();
}

class _PasskeyScreenState extends State<PasskeyScreen> {
  bool _busy = false;
  String? _error;
  WalletSession? _session;
  bool _showPhrase = false;

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final passkey = await enrollPasskey();
      final wallet = CkbMnemonicWallet.generate(network: widget.network);
      final session = await WalletSession.enroll(
        network: widget.network,
        mnemonic: wallet.mnemonic,
        passkey: passkey,
      );
      setState(() => _session = session);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(title: const Text('Create wallet')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Create a self-custodial CKB wallet. A passkey wraps the keys on this device. After that, passkey sign-in is required to unlock them.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (session == null)
            FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Create passkey & wallet'),
            ),
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
          if (session != null) ...[
            const SizedBox(height: 20),
            InfoCard(
              title: 'Wallet ready',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CopyableText(value: session.address, label: 'Address to fund'),
                  const SizedBox(height: 8),
                  Text(
                    session.platformPasskey
                        ? 'Protected by a platform passkey. Sign in with that passkey the next time you open the app.'
                        : 'Platform passkeys are unavailable here, so a local key wraps the vault. Use Unlock on the sign-in screen.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _showPhrase = !_showPhrase),
              icon: Icon(
                _showPhrase ? Icons.visibility_off : Icons.visibility,
              ),
              label: Text(
                _showPhrase ? 'Hide recovery phrase' : 'Show recovery phrase',
              ),
            ),
            if (_showPhrase) ...[
              const SizedBox(height: 12),
              InfoCard(
                title: 'Recovery phrase',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Write these words down. They restore the keys if this device or passkey is lost.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    CopyableText(value: session.mnemonic),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => widget.onCreated(session),
              child: const Text('Enter wallet'),
            ),
          ],
        ],
      ),
    );
  }
}
