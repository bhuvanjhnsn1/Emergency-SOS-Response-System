
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('SOS Guardian app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SOSGuardianApp());
    expect(find.text('SOS Guardian'), findsOneWidget);
  });
}
