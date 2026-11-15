import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendata/main.dart';

void main() {
  testWidgets('VenData app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: VenDataApp(),
      ),
    );

    expect(find.text('Ven'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Vendata'), findsOneWidget);
  });
}
