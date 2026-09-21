import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:flutter/material.dart';

import '../widgets.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({
    super.key,
    required this.network,
    required this.onNetworkChanged,
    required this.onCreateWallet,
    required this.onImportMnemonic,
  });

  final CkbNetwork network;
  final ValueChanged<CkbNetwork> onNetworkChanged;
  final VoidCallback onCreateWallet;
  final VoidCallback onImportMnemonic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CKB Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Self-custodial wallet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Keys stay on this device. A passkey is the only way to unlock them — the app does not hold a hosted account.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Text('Network', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<CkbNetwork>(
            segments: const [
              ButtonSegment(
                value: CkbNetwork.testnet,
                label: Text('Testnet'),
                icon: Icon(Icons.science_outlined),
              ),
              ButtonSegment(
                value: CkbNetwork.mainnet,
                label: Text('Mainnet'),
                icon: Icon(Icons.public),
              ),
            ],
            selected: {network},
            onSelectionChanged: (selected) => onNetworkChanged(selected.first),
          ),
          const SizedBox(height: 24),
          ChoiceCard(
            icon: Icons.fingerprint,
            title: 'Create wallet',
            subtitle:
                'Generate keys on this device and protect them with a passkey.',
            onTap: onCreateWallet,
          ),
          const SizedBox(height: 12),
          ChoiceCard(
            icon: Icons.vpn_key_outlined,
            title: 'Import recovery phrase',
            subtitle:
                'Restore keys from a BIP-39 phrase, then lock them with a passkey.',
            onTap: onImportMnemonic,
          ),
        ],
      ),
    );
  }
}
