import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('setup screen offers mnemonic and passkey wallets', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CkbWalletExampleApp());
    await tester.pumpAndSettle();
    expect(find.text('CKB Wallet'), findsOneWidget);
    expect(find.text('Create with mnemonic'), findsOneWidget);
    expect(find.text('Create with passkey'), findsOneWidget);
  });
}
