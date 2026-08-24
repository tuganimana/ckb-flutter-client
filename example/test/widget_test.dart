import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('example app loads', (tester) async {
    await tester.pumpWidget(const CkbLightClientExampleApp());
    expect(find.text('CKB Flutter Client'), findsOneWidget);
    expect(find.text('Load header sync'), findsOneWidget);
  });
}
