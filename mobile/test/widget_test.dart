// Smoke test dasar: pastikan app bisa di-build dan splash screen tampil.

import 'package:flutter_test/flutter_test.dart';

import 'package:galeria/main.dart';

void main() {
  testWidgets('App builds and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const GaleriaApp());
    await tester.pump();

    expect(find.text('G A L E R I A'), findsOneWidget);
  });
}
