import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria/models/event.dart';
import 'package:galeria/screens/event/event_kelola_screen.dart';
import 'package:galeria/screens/kolektor/event/e_tiket_screen.dart';
import 'package:galeria/screens/kolektor/event/event_screen.dart';
import 'package:galeria/screens/kolektor/event/tiket_checkout_screen.dart';
import 'package:galeria/services/event_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

Map<String, dynamic> _ev({String id = 'e1', int sisaReg = 3, int sisaVip = 1, String status = 'akan_datang', bool penyelenggara = false}) {
  final now = DateTime.now().toUtc();
  return {
    'id': id,
    'judul': 'Pameran Cahaya',
    'deskripsi': 'Pameran uji',
    'tema': 'Pameran Tunggal',
    'format': 'offline',
    'nama_lokasi': 'Galeri Nusantara',
    'alamat': 'Jl. Tunjungan 1',
    'kota': 'Surabaya',
    'link_online': null,
    'mulai_at': now.add(const Duration(days: 3)).toIso8601String(),
    'selesai_at': now.add(const Duration(days: 3, hours: 4)).toIso8601String(),
    'status': status,
    'penyelenggara_nama': 'Rani',
    'gratis': false,
    'harga_mulai_idr': 50000,
    'total_kuota': 4,
    'total_sisa': sisaReg + sisaVip,
    'tiket': [
      {'id': 't1', 'nama': 'Reguler', 'harga_idr': 50000, 'kuota': 3, 'sisa': sisaReg},
      {'id': 't2', 'nama': 'VIP', 'harga_idr': 150000, 'kuota': 1, 'sisa': sisaVip, 'keterangan': 'Kursi depan'},
    ],
    'karya': [],
    'server_now': now.toIso8601String(),
    'saya_punya_tiket': false,
    'saya_penyelenggara': penyelenggara,
    'bisa_dibatalkan': false,
    'tiket_terjual': penyelenggara ? 2 : null,
    'pendapatan_idr': penyelenggara ? 100000 : null,
    'sudah_checkin': penyelenggara ? 1 : null,
  };
}

Map<String, dynamic> _pesanan({String status = 'menunggu_pembayaran'}) => {
      'id': 'p1',
      'event': {
        'id': 'e1', 'judul': 'Pameran Cahaya', 'format': 'offline', 'kota': 'Surabaya', 'nama_lokasi': 'Galeri Nusantara',
        'mulai_at': DateTime.now().toUtc().add(const Duration(days: 3)).toIso8601String(),
        'selesai_at': DateTime.now().toUtc().add(const Duration(days: 3, hours: 4)).toIso8601String(),
        'status': 'akan_datang',
      },
      'tiket_nama': 'Reguler',
      'jumlah': 2,
      'harga_satuan_idr': 50000,
      'total_idr': 100000,
      'status': status,
      'status_label': 'x',
      'nama_pemegang': 'Budi',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'etiket': [],
      'aksi': <String>[],
    };

class _FakeEvent extends EventService {
  _FakeEvent({this.daftarData = const [], this.tolak, this.hasilCheckin});
  final List<EventInfo> daftarData;
  final String? tolak;
  final HasilCheckin? hasilCheckin;
  final dipesan = <Map<String, Object>>[];
  final kodeCheckin = <String>[];

  @override
  Future<List<EventInfo>> daftar({String waktu = 'mendatang', String? q}) async => daftarData;

  @override
  Future<EventInfo> detail(String id) async => EventInfo.fromJson(_ev(penyelenggara: true));

  @override
  Future<List<Peserta>> peserta(String id) async => [
        Peserta.fromJson({'kode': 'GAL-AAAAAAAAAA', 'nama_pemegang': 'Budi', 'tiket_nama': 'Reguler', 'status': 'terpakai', 'akun_pembeli': 'Budi S.'}),
        Peserta.fromJson({'kode': 'GAL-BBBBBBBBBB', 'nama_pemegang': 'Sari', 'tiket_nama': 'VIP', 'status': 'aktif', 'akun_pembeli': 'Sari P.'}),
      ];

  @override
  Future<HasilCheckin> checkin(String kode) async {
    kodeCheckin.add(kode);
    return hasilCheckin ?? const HasilCheckin(berhasil: true, pesan: 'Check-in berhasil. Silakan masuk.');
  }

  @override
  Future<PesananTiket> pesan(String eventId, {required String tiketId, required int jumlah, required String namaPemegang}) async {
    if (tolak != null) throw Exception(tolak);
    dipesan.add({'event': eventId, 'tiket': tiketId, 'jumlah': jumlah, 'nama': namaPemegang});
    return PesananTiket.fromJson(_pesanan());
  }
}

void main() {
  test('EventInfo.fromJson: lokasi, gratis, dan sisa tiket terbaca benar', () {
    final e = EventInfo.fromJson(_ev(sisaReg: 0, sisaVip: 0));
    expect(e.lokasi, 'Galeri Nusantara, Surabaya');
    expect(e.totalSisa, 0);
    expect(e.tiket.first.habis, isTrue);
    expect(e.bisaBeli, isTrue);
    expect(EventInfo.fromJson(_ev(status: 'selesai')).bisaBeli, isFalse);
  });

  testWidgets('daftar event menampilkan event dari server; kosong -> pesan jujur', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EventScreen(onBack: () {}, onDetail: (_) {}, service: _FakeEvent(daftarData: [EventInfo.fromJson(_ev())])),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Pameran Cahaya'), findsOneWidget);
    expect(find.text('Mulai Rp50.000'), findsOneWidget);
    expect(find.text('Sisa 4 tiket'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: EventScreen(key: UniqueKey(), onBack: () {}, onDetail: (_) {}, service: _FakeEvent())));
    await tester.pump();
    await tester.pump();
    expect(find.text('Belum ada event mendatang.'), findsOneWidget);
  });

  testWidgets('checkout: jenis tiket habis tidak bisa dipilih; pesanan dikirim dengan jenis, jumlah, dan nama yang benar', (tester) async {
    final fake = _FakeEvent();
    PesananTiket? dibuat;
    await tester.pumpWidget(MaterialApp(
      home: TiketCheckoutScreen(
        event: EventInfo.fromJson(_ev(sisaReg: 0)), // Reguler habis -> otomatis memilih VIP
        onBack: () {},
        onDipesan: (p) => dibuat = p,
        service: fake,
      ),
    ));
    await tester.pump();
    expect(find.text('Habis'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Budi Santoso');
    await tester.scrollUntilVisible(find.byKey(const Key('pesan_tiket')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('pesan_tiket')));
    await tester.pump();
    await tester.pump();
    expect(fake.dipesan, [
      {'event': 'e1', 'tiket': 't2', 'jumlah': 1, 'nama': 'Budi Santoso'},
    ]);
    expect(dibuat, isNotNull);
  });

  testWidgets('checkout: ditolak server (kuota habis) -> pesan server tampil', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TiketCheckoutScreen(event: EventInfo.fromJson(_ev()), onBack: () {}, onDipesan: (_) {}, service: _FakeEvent(tolak: 'Sisa tiket hanya 1.')),
    ));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Budi Santoso');
    await tester.scrollUntilVisible(find.byKey(const Key('pesan_tiket')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('pesan_tiket')));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Sisa tiket hanya 1.'), findsOneWidget);
  });

  testWidgets('e-tiket menampilkan QR sungguhan berisi kode; tiket terpakai ditandai', (tester) async {
    final p = PesananTiket.fromJson({
      ..._pesanan(status: 'dibayar'),
      'etiket': [
        {'id': 'x1', 'kode': 'GAL-ABCDE12345', 'nama_pemegang': 'Budi', 'status': 'aktif'},
        {'id': 'x2', 'kode': 'GAL-ZZZZZ99999', 'nama_pemegang': 'Budi', 'status': 'terpakai'},
      ],
    });
    await tester.pumpWidget(MaterialApp(home: ETiketScreen(event: p.event, tiketNama: p.tiketNama, etiket: p.etiket, onDone: () {})));
    await tester.pump();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('GAL-ABCDE12345'), findsOneWidget);
    expect(find.textContaining('Tiket 1 dari 2'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('SUDAH DIGUNAKAN'), findsOneWidget);
  });

  testWidgets('kelola event: statistik, daftar peserta, dan hasil check-in', (tester) async {
    final fake = _FakeEvent(hasilCheckin: const HasilCheckin(berhasil: false, pesan: 'Tiket sudah digunakan (check-in pukul 10:00).'));
    await tester.pumpWidget(MaterialApp(home: EventKelolaScreen(eventId: 'e1', onBack: () {}, service: fake)));
    await tester.pumpAndSettle();
    expect(find.text('Peserta (2)'), findsOneWidget);
    expect(find.text('Rp100.000'), findsOneWidget);
    expect(find.text('Hadir'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('kode_checkin')), 'gal-aaaaaaaaaa');
    await tester.tap(find.byKey(const Key('tombol_checkin')));
    await tester.pumpAndSettle();
    expect(fake.kodeCheckin, ['gal-aaaaaaaaaa']);
    expect(find.byKey(const Key('hasil_checkin')), findsOneWidget);
    expect(find.textContaining('sudah digunakan'), findsOneWidget);
  });

  testWidgets('kelola event: kode terlalu pendek ditolak tanpa menghubungi server', (tester) async {
    final fake = _FakeEvent();
    await tester.pumpWidget(MaterialApp(home: EventKelolaScreen(eventId: 'e1', onBack: () {}, service: fake)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('kode_checkin')), 'abc');
    await tester.tap(find.byKey(const Key('tombol_checkin')));
    await tester.pump();
    expect(fake.kodeCheckin, isEmpty);
    expect(find.textContaining('Isi kode tiket'), findsOneWidget);
  });
}
