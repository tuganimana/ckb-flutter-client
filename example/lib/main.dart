import 'package:ckb_flutter_client/ckb_flutter_client.dart';
import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
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
  WalletVault? _vault;
  WalletSession? _session;
  CkbNetwork _network = CkbNetwork.testnet;
  bool _loading = true;
  bool _unlocking = false;
  String? _unlockError;

  @override
  void initState() {
    super.initState();
    _restoreVault();
  }

  Future<void> _restoreVault() async {
    final vault = await WalletVault.load();
    if (!mounted) return;
    setState(() {
      _vault = vault;
      _network = vault?.network ?? CkbNetwork.testnet;
      _loading = false;
    });
  }

  void _openCreate() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PasskeyScreen(
          network: _network,
          onCreated: _onUnlocked,
        ),
      ),
    );
  }

  void _openImport() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MnemonicScreen(
          network: _network,
          onCreated: _onUnlocked,
        ),
      ),
    );
  }

  void _onUnlocked(WalletSession session) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _session = session;
      _vault = session.vault;
      _network = session.network;
      _unlockError = null;
    });
  }

  Future<void> _signIn() async {
    final vault = _vault;
    if (vault == null) return;
    setState(() {
      _unlocking = true;
      _unlockError = null;
    });
    try {
      final session = await WalletSession.authenticate(vault);
      if (!mounted) return;
      setState(() {
        _session = session;
        _vault = session.vault;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _unlockError = error.toString());
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  void _lock() {
    setState(() {
      _session = null;
      _unlockError = null;
    });
  }

  Future<void> _deleteWallet() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete wallet?'),
        content: const Text(
          'This removes the encrypted vault from this device. It does not delete funds on chain. You will need the recovery phrase to import again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await WalletVault.clear();
    if (!mounted) return;
    setState(() {
      _vault = null;
      _session = null;
      _unlockError = null;
    });
  }

  Future<void> _updateSession(WalletSession session) async {
    await session.vault.save();
    if (!mounted) return;
    setState(() {
      _session = session;
      _vault = session.vault;
      _network = session.network;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = _session;
    if (session != null) {
      return WalletScreen(
        session: session,
        onSessionChanged: _updateSession,
        onLock: _lock,
        onDeleteWallet: _deleteWallet,
      );
    }
    final vault = _vault;
    if (vault != null) {
      return LoginScreen(
        vault: vault,
        busy: _unlocking,
        error: _unlockError,
        onSignIn: _signIn,
        onDeleteWallet: _deleteWallet,
      );
    }
    return SetupScreen(
      network: _network,
      onNetworkChanged: (network) => setState(() => _network = network),
      onCreateWallet: _openCreate,
      onImportMnemonic: _openImport,
    );
  }
}
