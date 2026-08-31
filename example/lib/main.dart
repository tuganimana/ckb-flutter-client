import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:flutter/material.dart';

import 'screens/mnemonic_screen.dart';
import 'screens/passkey_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/wallet_screen.dart';
import 'session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CkbWalletExampleApp());
}

class CkbWalletExampleApp extends StatelessWidget {
  const CkbWalletExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CKB Wallet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3CC68A)),
        useMaterial3: true,
      ),
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  WalletSession? _session;
  CkbNetwork _network = CkbNetwork.testnet;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final session = await WalletSession.load();
    if (!mounted) return;
    setState(() {
      _session = session;
      _network = session?.network ?? CkbNetwork.testnet;
      _loading = false;
    });
  }

  void _openMnemonic() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            MnemonicScreen(network: _network, onCreated: _onCreated),
      ),
    );
  }

  void _openPasskey() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            PasskeyScreen(network: _network, onCreated: _onCreated),
      ),
    );
  }

  void _onCreated(WalletSession session) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _session = session);
  }

  Future<void> _reset() async {
    await WalletSession.clear();
    if (!mounted) return;
    setState(() => _session = null);
  }

  Future<void> _updateRpc(String rpcUrl) async {
    final session = _session;
    if (session == null || session.rpcUrl == rpcUrl) return;
    final updated = session.copyWith(rpcUrl: rpcUrl);
    await updated.save();
    if (!mounted) return;
    setState(() => _session = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = _session;
    if (session == null) {
      return SetupScreen(
        network: _network,
        onNetworkChanged: (network) => setState(() => _network = network),
        onChooseMnemonic: _openMnemonic,
        onChoosePasskey: _openPasskey,
      );
    }
    return WalletScreen(
      session: session,
      onRpcUrlChanged: _updateRpc,
      onReset: _reset,
    );
  }
}
