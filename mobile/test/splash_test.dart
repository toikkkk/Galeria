import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria/screens/onboarding/splash_screen.dart';

void main() {
  testWidgets('splash menampilkan GALERIA lalu memanggil onFinished tepat sekali', (tester) async {
    var selesai = 0;
    await tester.pumpWidget(MaterialApp(home: SplashScreen(onFinished: () => selesai++)));
    expect(selesai, 0);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('G'), findsOneWidget); // huruf pertama sudah tampil
    expect(selesai, 0);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(selesai, 1);
  });
}
