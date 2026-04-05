import 'package:flutter_test/flutter_test.dart';

import 'package:umkm/main.dart';

void main() {
  testWidgets('Kasirku app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KasirkuApp());

    expect(find.text('KASIRKU'), findsOneWidget);
  });
}
