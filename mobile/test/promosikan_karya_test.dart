import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria/screens/karya/promosikan_karya_screen.dart';
import 'package:galeria/theme/app_theme.dart';

void main() {
  testWidgets('promosikan karya: bilah total + tombol menempel di bawah, tanpa overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340); // 360 x 780 dp
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: PromosikanKaryaScreen(onBack: () {}, onLanjut: () {}),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Pilih Paket Promosi'), findsOneWidget);
    expect(find.text('TOTAL BIAYA PROMOSI'), findsOneWidget);
    expect(find.text('Aktifkan Promosi'), findsOneWidget);
    // bilah bawah ada di dasar layar dan tombol di sisi kanan
    expect(tester.getTopLeft(find.text('Aktifkan Promosi')).dy, greaterThan(650));
    expect(tester.getTopLeft(find.text('Aktifkan Promosi')).dx, greaterThan(100));
    expect(tester.getTopLeft(find.text('TOTAL BIAYA PROMOSI')).dx, lessThan(40));
  });
}
