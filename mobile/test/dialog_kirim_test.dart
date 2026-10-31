import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria/widgets/pesanan_widgets.dart';

void main() {
  testWidgets('dialog resi: isi lalu tutup tidak memicu error, hasilnya (kurir, resi)', (tester) async {
    (String, String)? hasil;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(onPressed: () async => hasil = await tampilkanDialogKirim(context), child: const Text('buka')),
      ),
    ));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('resi')), 'JNE12345678');
    await tester.tap(find.byKey(const Key('tandai_dikirim')));
    await tester.pump(); // tepat saat animasi tutup berjalan
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(hasil, ('JNE', 'JNE12345678'));
  });

  testWidgets('dialog resi: Batal -> null', (tester) async {
    (String, String)? hasil = ('x', 'y');
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(onPressed: () async => hasil = await tampilkanDialogKirim(context), child: const Text('buka')),
      ),
    ));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(hasil, isNull);
  });
}
