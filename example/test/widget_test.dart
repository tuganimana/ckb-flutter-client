import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('setup screen offers a self-custodial passkey wallet', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CkbWalletExampleApp());
    await tester.pumpAndSettle();
    expect(find.text('CKB Wallet'), findsOneWidget);
    expect(find.text('Self-custodial wallet'), findsOneWidget);
    expect(find.text('Create wallet'), findsOneWidget);
    expect(find.text('Import recovery phrase'), findsOneWidget);
  });

  testWidgets('existing vault requires passkey sign-in', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ckb_wallet_vault_v1':
          '{"network":"testnet","address":"ckt1qtestaddress","rpcUrl":"https://testnet.ckb.dev/rpc","credentialId":"abc","prfSalt":"c2FsdA==","encryptedSecret":"AAAA","platformPasskey":true,"prfWrapped":true}',
    });
    await tester.pumpWidget(const CkbWalletExampleApp());
    await tester.pumpAndSettle();
    expect(find.text('Unlock your wallet'), findsOneWidget);
    expect(find.text('Sign in with passkey'), findsOneWidget);
    expect(find.text('Create wallet'), findsNothing);
  });
}
