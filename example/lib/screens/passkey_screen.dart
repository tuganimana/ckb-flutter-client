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
  PasskeyResult? _passkey;
  CkbPasskeyAccount? _account;

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final passkey = await createPasskey();
      final account = accountFromPasskey(passkey, network: widget.network);
      setState(() {
        _passkey = passkey;
        _account = account;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continue() async {
    final account = _account;
    final passkey = _passkey;
    if (account == null || passkey == null) return;
    final session = WalletSession(
      kind: WalletKind.passkey,
      network: widget.network,
      address: account.address,
      rpcUrl: CkbLightClient.publicRpcUrlFor(widget.network),
      passkeyPublicKey: account.publicKeyHex,
      platformPasskey: passkey.platformPasskey,
    );
    await session.save();
    widget.onCreated(session);
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    return Scaffold(
      appBar: AppBar(title: const Text('Passkey wallet')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'A passkey wallet uses secp256r1 (WebAuthn) and a JoyID lock. The resulting CKB address is what you fund.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.fingerprint),
            label: Text(
              account == null ? 'Create passkey' : 'Create another passkey',
            ),
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
          if (account != null && _passkey != null) ...[
            const SizedBox(height: 20),
            InfoCard(
              title: 'Address to fund',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CopyableText(value: account.address),
                  const SizedBox(height: 8),
                  Text(
                    _passkey!.platformPasskey
                        ? 'Stored as a platform passkey (WebAuthn).'
                        : 'Platform passkeys are unavailable here, so a local secp256r1 key was used. The address is still a real JoyID lock.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _continue,
              child: const Text('Use this wallet'),
            ),
          ],
        ],
      ),
    );
  }
}
