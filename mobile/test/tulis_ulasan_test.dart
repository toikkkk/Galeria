import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria/services/api_client.dart';
import 'package:galeria/services/ulasan_service.dart';
import 'package:galeria/widgets/kolektor/tulis_ulasan_sheet.dart';

class _FakeUlasan extends UlasanService {
  _FakeUlasan({this.gagal});

  final Object? gagal;
  final kiriman = <Map<String, Object>>[];

  @override
  Future<void> kirim({required String karyaId, required int rating, required String teks}) async {
    if (gagal != null) throw gagal!;
    kiriman.add({'karyaId': karyaId, 'rating': rating, 'teks': teks});
  }
}

Future<bool?> _buka(WidgetTester tester, _FakeUlasan service) async {
  bool? hasil;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => hasil = await tampilkanTulisUlasan(context, karyaId: 'k1', judulKarya: 'Judul', service: service),
          child: const Text('buka'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
  return hasil;
}

FilledButton _tombol(WidgetTester t) => t.widget<FilledButton>(find.byKey(const Key('kirim_ulasan')));

void main() {
  testWidgets('tombol kirim nonaktif sampai rating dipilih dan teks >= 10 karakter', (tester) async {
    await _buka(tester, _FakeUlasan());
    expect(_tombol(tester).onPressed, isNull);

    await tester.tap(find.byKey(const Key('bintang_4')));
    await tester.pump();
    expect(_tombol(tester).onPressed, isNull); // teks masih kosong

    await tester.enterText(find.byKey(const Key('isi_ulasan')), 'terlalu');
    await tester.pump();
    expect(_tombol(tester).onPressed, isNull); // < 10 karakter

    await tester.enterText(find.byKey(const Key('isi_ulasan')), 'Lukisannya bagus dan rapi');
    await tester.pump();
    expect(_tombol(tester).onPressed, isNotNull);
  });

  testWidgets('kirim sukses menutup formulir dan mengirim data yang benar', (tester) async {
    final service = _FakeUlasan();
    await _buka(tester, service);
    await tester.tap(find.byKey(const Key('bintang_5')));
    await tester.enterText(find.byKey(const Key('isi_ulasan')), '  Pengirimannya cepat sekali  ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('kirim_ulasan')));
    await tester.pumpAndSettle();

    expect(service.kiriman, [
      {'karyaId': 'k1', 'rating': 5, 'teks': 'Pengirimannya cepat sekali'},
    ]);
    expect(find.text('Tulis ulasan'), findsNothing); // sheet tertutup
  });

  testWidgets('409 -> pesan ramah, formulir tetap terbuka (tidak crash)', (tester) async {
    await _buka(tester, _FakeUlasan(gagal: ApiException('Server error 409: sudah')));
    await tester.tap(find.byKey(const Key('bintang_3')));
    await tester.enterText(find.byKey(const Key('isi_ulasan')), 'Biasa saja menurut saya');
    await tester.pump();
    await tester.tap(find.byKey(const Key('kirim_ulasan')));
    await tester.pumpAndSettle();

    expect(find.text('Kamu sudah pernah menulis ulasan untuk karya ini.'), findsOneWidget);
    expect(find.text('Tulis ulasan'), findsOneWidget);
    expect(_tombol(tester).onPressed, isNotNull); // bisa coba lagi
  });

  test('pesanGagalUlasan: backend mati -> pesan koneksi', () {
    expect(pesanGagalUlasan(ApiException('Gagal terhubung ke backend (/api/ulasan): x')), contains('koneksi'));
  });
}
