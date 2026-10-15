import 'package:flutter_test/flutter_test.dart';
import 'package:app_starter/app.dart';

void main() {
  testWidgets('App boots', (tester) async {
    await tester.pumpWidget(const AppStarterApp());
    expect(find.byType(AppStarterApp), findsOneWidget);
  });
}
