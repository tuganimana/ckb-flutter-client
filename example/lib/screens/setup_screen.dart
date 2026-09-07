import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:flutter/material.dart';

import '../widgets.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({
    super.key,
    required this.network,
    required this.onNetworkChanged,
    required this.onGenerateMnemonic,
    required this.onImportMnemonic,
    required this.onChoosePasskey,
  });

  final CkbNetwork network;
  final ValueChanged<CkbNetwork> onNetworkChanged;
  final VoidCallback onGenerateMnemonic;
  final VoidCallback onImportMnemonic;
  final VoidCallback onChoosePasskey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CKB Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Set up a wallet, fund the address, then watch it with the light client.',
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
            icon: Icons.auto_awesome,
            title: 'Generate mnemonic',
            subtitle:
                'Create a new 12-word BIP-39 phrase and a secp256k1 CKB address.',
            onTap: onGenerateMnemonic,
          ),
          const SizedBox(height: 12),
          ChoiceCard(
            icon: Icons.vpn_key_outlined,
            title: 'Import mnemonic',
            subtitle: 'Restore a wallet from an existing recovery phrase.',
            onTap: onImportMnemonic,
          ),
          const SizedBox(height: 12),
          ChoiceCard(
            icon: Icons.fingerprint,
            title: 'Create with passkey',
            subtitle:
                'Create a JoyID lock from a passkey (WebAuthn / secp256r1).',
            onTap: onChoosePasskey,
          ),
        ],
      ),
    );
  }
}
