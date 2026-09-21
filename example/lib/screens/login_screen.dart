import 'package:flutter/material.dart';

import '../session.dart';
import '../widgets.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.vault,
    required this.busy,
    required this.error,
    required this.onSignIn,
    required this.onDeleteWallet,
  });

  final WalletVault vault;
  final bool busy;
  final String? error;
  final VoidCallback onSignIn;
  final VoidCallback onDeleteWallet;

  @override
  Widget build(BuildContext context) {
    final address = vault.address;
    final preview = address.length <= 20
        ? address
        : '${address.substring(0, 10)}…${address.substring(address.length - 8)}';
    return Scaffold(
      appBar: AppBar(title: const Text('CKB Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Unlock your wallet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            vault.platformPasskey
                ? 'Sign in with the passkey that protects this self-custodial wallet. Your keys stay on this device.'
                : 'This device has no platform passkey, so a local key wraps the vault. Confirm to unlock keys in memory.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          InfoCard(
            title: 'Saved wallet',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CopyableText(value: vault.address, label: 'Address'),
                const SizedBox(height: 8),
                Text(
                  '${vault.network.name} · $preview',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: busy ? null : onSignIn,
            icon: const Icon(Icons.fingerprint),
            label: Text(
              vault.platformPasskey
                  ? 'Sign in with passkey'
                  : 'Unlock local wallet',
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator(),
            ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          TextButton(
            onPressed: busy ? null : onDeleteWallet,
            child: const Text('Delete wallet from this device'),
          ),
        ],
      ),
    );
  }
}
