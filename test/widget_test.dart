import 'package:flutter_test/flutter_test.dart';
import 'package:gondola_label_flutter/main.dart';

void main() {
  testWidgets('App smoke test and title verification', (WidgetTester tester) async {
    await tester.pumpWidget(const GondolaLabelApp());
    expect(find.text('Gôndola K329 (Flutter)'), findsOneWidget);
    expect(find.text('IMPRIMIR ETIQUETA K329'), findsOneWidget);
  });
}
