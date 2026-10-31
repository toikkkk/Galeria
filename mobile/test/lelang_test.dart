import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria/models/lelang.dart';
import 'package:galeria/screens/kolektor/lelang/lelang_screen.dart';
import 'package:galeria/screens/kolektor/lelang/pasang_bid_sheet.dart';
import 'package:galeria/services/api_client.dart';
import 'package:galeria/services/lelang_service.dart';

Map<String, dynamic> _json({
  String id = 'l1',
  String status = 'berlangsung',
  int jumlahBid = 0,
  int saatIni = 1000000,
  int minimum = 1000000,
  bool tertinggi = false,
  int menitSisa = 30,
}) {
  final now = DateTime.now().toUtc();
  return {
    'id': id,
    'status': status,
    'karya': {'id': 'k1', 'title': 'Senja di Teluk', 'artist_name': 'Rani', 'style_name': 'Impressionism'},
    'seniman_nama': 'Rani',
    'harga_awal_idr': 1000000,
    'kelipatan_bid_idr': 100000,
    'harga_saat_ini_idr': saatIni,
    'jumlah_bid': jumlahBid,
    'bid_minimum_berikutnya_idr': minimum,
    'mulai_at': now.subtract(const Duration(minutes: 10)).toIso8601String(),
    'selesai_at': now.add(Duration(minutes: menitSisa)).toIso8601String(),
    'server_now': now.toIso8601String(),
    'saya_tertinggi': tertinggi,
    'saya_pemenang': false,
    'bisa_dibatalkan': false,
  };
}

class _FakeLelang extends LelangService {
  _FakeLelang(this.data, {this.tolak});
  final List<Lelang> data;
  final String? tolak;
  final bids = <int>[];
  String? statusDiminta;

  @override
  Future<List<Lelang>> daftar({String status = 'semua', bool ikut = false}) async {
    statusDiminta = ikut ? 'ikut' : status;
    return data;
  }

  @override
  Future<Lelang> bid(String id, int jumlahIdr) async {
    if (tolak != null) throw ApiException(tolak!);
    bids.add(jumlahIdr);
    return Lelang.fromJson(_json(jumlahBid: 1, saatIni: jumlahIdr, minimum: jumlahIdr + 100000, tertinggi: true));
  }
}

void main() {
  test('Lelang.fromJson: sisa waktu dihitung dari jam server, bukan jam HP', () {
    final now = DateTime.now().toUtc();
    final j = _json(menitSisa: 30);
    // jam server 2 jam lebih cepat dari jam HP, tetapi selesai_at juga relatif ke jam server -> sisa tetap ~30 menit
    j['server_now'] = now.add(const Duration(hours: 2)).toIso8601String();
    j['selesai_at'] = now.add(const Duration(hours: 2, minutes: 30)).toIso8601String();
    j['mulai_at'] = now.add(const Duration(hours: 1)).toIso8601String();
    final l = Lelang.fromJson(j);
    expect(l.sisa.inMinutes, inInclusiveRange(29, 30));
    expect(l.statusSekarang, 'berlangsung');
  });

  test('statusSekarang menyusul waktu: lewat selesai_at -> selesai; sebelum mulai -> akan_datang', () {
    final lewat = Lelang.fromJson(_json(menitSisa: -1));
    expect(lewat.statusSekarang, 'selesai');
    final j = _json();
    j['mulai_at'] = DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String();
    j['selesai_at'] = DateTime.now().toUtc().add(const Duration(hours: 2)).toIso8601String();
    expect(Lelang.fromJson(j).statusSekarang, 'akan_datang');
  });

  test('formatSisa', () {
    expect(formatSisa(const Duration(hours: 1, minutes: 2, seconds: 5)), '01:02:05');
    expect(formatSisa(const Duration(days: 2, hours: 3, minutes: 10)), '2h 03:10:00');
  });

  testWidgets('daftar lelang menampilkan lot dari server; kosong -> pesan jujur', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LelangScreen(onBack: () {}, service: _FakeLelang([Lelang.fromJson(_json(jumlahBid: 3, saatIni: 1300000))])),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Senja di Teluk'), findsOneWidget);
    expect(find.text('Rp1.300.000'), findsOneWidget);
    expect(find.text('Bid tertinggi'), findsOneWidget);
    expect(find.text('3 bid'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: LelangScreen(key: UniqueKey(), onBack: () {}, service: _FakeLelang([]))));
    await tester.pump();
    await tester.pump();
    expect(find.text('Belum ada lelang pada kategori ini.'), findsOneWidget);
  });

  Future<void> bukaSheet(WidgetTester tester, Lelang l, LelangService s) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(body: TextButton(onPressed: () => tampilkanPasangBid(context, l, service: s), child: const Text('buka'))),
      ),
    ));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  testWidgets('sheet bid: terisi bid minimum, bid di bawah minimum ditolak SEBELUM menghubungi server', (tester) async {
    final fake = _FakeLelang([]);
    await bukaSheet(tester, Lelang.fromJson(_json(jumlahBid: 1, saatIni: 1500000, minimum: 1600000)), fake);
    expect(find.widgetWithText(TextField, '1.600.000'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('jumlah_bid')), '1.550.000');
    await tester.tap(find.byKey(const Key('kirim_bid')));
    await tester.pump();
    expect(find.byKey(const Key('error_bid')), findsOneWidget);
    expect(fake.bids, isEmpty);
  });

  testWidgets('sheet bid: bid valid dikirim ke server dengan angka yang benar dan sheet menutup', (tester) async {
    final fake = _FakeLelang([]);
    await bukaSheet(tester, Lelang.fromJson(_json()), fake);
    await tester.enterText(find.byKey(const Key('jumlah_bid')), '1.200.000');
    await tester.tap(find.byKey(const Key('kirim_bid')));
    await tester.pumpAndSettle();
    expect(fake.bids, [1200000]);
    expect(find.text('Pasang Tawaran'), findsNothing);
  });

  testWidgets('sheet bid: ditolak server -> pesan server tampil, sheet tetap terbuka', (tester) async {
    final fake = _FakeLelang([], tolak: 'Tawaranmu sudah yang tertinggi.');
    await bukaSheet(tester, Lelang.fromJson(_json()), fake);
    await tester.tap(find.byKey(const Key('kirim_bid')));
    await tester.pumpAndSettle();
    expect(find.text('Tawaranmu sudah yang tertinggi.'), findsOneWidget);
    expect(find.text('Pasang Tawaran'), findsOneWidget);
  });
}
