import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria/models/karya.dart';
import 'package:galeria/models/langganan.dart';
import 'package:galeria/models/notifikasi.dart';
import 'package:galeria/screens/kolektor/koleksi/koleksi_saya_screen.dart';
import 'package:galeria/screens/notifikasi/notifikasi_screen.dart';
import 'package:galeria/services/favorit_service.dart';
import 'package:galeria/services/langganan_service.dart';
import 'package:galeria/services/notifikasi_service.dart';
import 'package:galeria/widgets/favorit_hati.dart';
import 'package:galeria/widgets/pro_gate.dart';

Map<String, dynamic> _karyaJson(String id, {String? artworkId, bool terjual = false}) => {
      'id': id,
      'title': 'Senja $id',
      'artist_name': 'Rani',
      'style_name': 'Impressionism',
      'gallery_name': 'Rani',
      'price_idr': 900000,
      'is_promoted': false,
      'image_filename': 'x.jpg',
      'artwork_id': artworkId,
      'terjual': terjual,
    };

// ------------------------------------------------------------------ langganan
class _FakeLangganan extends LanggananService {
  int panggilanSaya = 0;
  bool bayarBerhasil = true;
  final aksi = <String>[];

  @override
  Future<LanggananSaya> saya() async {
    panggilanSaya++;
    final aktif = aksi.contains('simulasi');
    return LanggananSaya(aktif: const [], pro: aktif, ar: false);
  }

  @override
  Future<KatalogPaket> paket() async => KatalogPaket.fromJson({
        'paket': [
          {'plan': 'komunitas_pro', 'nama': 'Seniman PRO', 'harga_idr': 149000, 'durasi_hari': 30, 'untuk': ['seniman'], 'manfaat': ['Membuat event pameran']},
        ],
        'promosi': [],
      });

  Map<String, dynamic> _t(String status, {String? metode}) => {
        'id': 't1', 'jenis': 'langganan', 'judul': 'Seniman PRO · 30 hari', 'jumlah_idr': 149000, 'status': status, 'status_label': 'x',
        'aksi': status == 'menunggu_pembayaran' ? ['bayar', 'batal'] : <String>[],
        if (metode != null) 'instruksi_bayar': {'metode': metode, 'nama_metode': 'QRIS', 'nomor': 'GALERIA.QRIS.1', 'jumlah_idr': 149000, 'mode': 'sandbox'},
      };

  @override
  Future<Tagihan> beli(String plan) async {
    aksi.add('beli:$plan');
    return Tagihan.fromJson(_t('menunggu_pembayaran'));
  }

  @override
  Future<Tagihan> pilihMetode(String id, String metode) async {
    aksi.add('metode:$metode');
    return Tagihan.fromJson(_t('menunggu_pembayaran', metode: metode));
  }

  @override
  Future<Tagihan> simulasiBayar(String id) async {
    aksi.add('simulasi');
    return Tagihan.fromJson(_t('dibayar'));
  }
}

Future<bool?> _jalankanGate(WidgetTester tester, _FakeLangganan f) async {
  bool? hasil;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(onPressed: () async => hasil = await ensurePro(context, fitur: 'Membuat event pameran', service: f), child: const Text('coba')),
      ),
    ),
  ));
  await tester.tap(find.text('coba'));
  await tester.pumpAndSettle();
  return hasil;
}

// ------------------------------------------------------------------ favorit
class _FakeFavorit extends FavoritService {
  final tersimpan = <String>{};
  bool gagal = false;

  @override
  Future<Set<String>> ids() async => {...tersimpan};

  @override
  Future<Set<String>> tambah(String karyaId) async {
    if (gagal) throw ApiExceptionTes('Karya tidak ditemukan');
    tersimpan.add(karyaId);
    return {...tersimpan};
  }

  @override
  Future<void> hapus(String karyaId) async => tersimpan.remove(karyaId);

  @override
  Future<List<Karya>> daftar() async => [for (final id in tersimpan) Karya.fromJson(_karyaJson(id))];

  @override
  Future<List<KoleksiItem>> koleksi() async => [
        KoleksiItem.fromJson({'karya': _karyaJson('m1', artworkId: 'GAL-ART-2026-000001', terjual: true), 'diperoleh_at': DateTime.now().toUtc().toIso8601String(), 'sumber': 'lelang', 'harga_idr': 1800000}),
      ];
}

class ApiExceptionTes implements Exception {
  ApiExceptionTes(this.pesan);
  final String pesan;
  @override
  String toString() => pesan;
}

// ------------------------------------------------------------------ notifikasi
class _FakeNotif extends NotifikasiService {
  _FakeNotif(this.data);
  final List<Notifikasi> data;
  final dibaca = <String>[];

  @override
  Future<HalamanNotifikasi> daftar({bool belum = false, DateTime? sebelum}) async =>
      HalamanNotifikasi(items: belum ? data.where((n) => !n.dibaca).toList() : data, belumDibaca: data.where((n) => !n.dibaca).length, adaLagi: false);

  @override
  Future<int> baca(String id) async {
    dibaca.add(id);
    return data.where((n) => !n.dibaca && n.id != id).length;
  }

  @override
  Future<int> bacaSemua() async => 0;
}

Notifikasi _n(String id, {bool dibaca = false, String tautan = 'pesanan:abc'}) => Notifikasi.fromJson({
      'id': id, 'tipe': 'transaksi', 'judul': 'Pesanan baru $id', 'isi': 'Isi $id', 'tautan': tautan, 'dibaca': dibaca,
      'waktu': DateTime.now().toUtc().toIso8601String(),
    });

void main() {
  testWidgets('gerbang PRO: belum berlangganan -> penawaran harga dari server -> bayar sandbox -> true', (tester) async {
    final f = _FakeLangganan();
    bool? hasil;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () async => hasil = await ensurePro(context, fitur: 'Membuat event pameran', service: f), child: const Text('coba')),
        ),
      ),
    ));
    await tester.tap(find.text('coba'));
    await tester.pumpAndSettle();
    expect(find.text('Berlangganan Seniman PRO'), findsOneWidget);
    expect(find.text('Rp149.000'), findsOneWidget); // harga datang dari server
    expect(find.text('Membuat event pameran'), findsWidgets);

    await tester.tap(find.byKey(const Key('lanjut_langganan')));
    await tester.pumpAndSettle();
    expect(find.text('Pilih metode pembayaran dulu'), findsOneWidget);
    await tester.tap(find.text('QRIS'));
    await tester.pumpAndSettle();
    expect(find.text('GALERIA.QRIS.1'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('simulasi_tagihan')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('simulasi_tagihan')));
    await tester.pumpAndSettle();

    expect(f.aksi, ['beli:komunitas_pro', 'metode:qris', 'simulasi']);
    expect(hasil, isTrue);
  });

  testWidgets('gerbang PRO: sudah PRO -> langsung true tanpa penawaran', (tester) async {
    final f = _FakeLangganan()..aksi.add('simulasi'); // saya() melapor pro
    final hasil = await _jalankanGate(tester, f);
    expect(hasil, isTrue);
    expect(find.text('Berlangganan Seniman PRO'), findsNothing);
  });

  testWidgets('gerbang PRO: "Nanti Saja" -> false dan tidak membuat tagihan', (tester) async {
    final f = _FakeLangganan();
    bool? hasil;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () async => hasil = await ensurePro(context, fitur: 'X', service: f), child: const Text('coba')),
        ),
      ),
    ));
    await tester.tap(find.text('coba'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nanti Saja'));
    await tester.pumpAndSettle();
    expect(hasil, isFalse);
    expect(f.aksi, isEmpty);
  });

  testWidgets('hati favorit: tamu diminta masuk; setelah masuk ikon berubah dan server dipanggil', (tester) async {
    final f = _FakeFavorit();
    FavoritStore.instance.service = f;
    final karya = Karya.fromJson(_karyaJson('k1'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FavoritHati(karya: karya))));
    await tester.tap(find.byKey(const Key('hati_favorit')).evaluate().isEmpty ? find.byType(InkWell) : find.byKey(const Key('hati_favorit')));
    await tester.pump();
    // tamu (AuthService belum masuk) -> snackbar, tidak memanggil server
    expect(find.text('Masuk dulu untuk menyimpan favorit.'), findsOneWidget);
    expect(f.tersimpan, isEmpty);

    // pemanggilan langsung store (mewakili pengguna yang sudah masuk)
    final err = await FavoritStore.instance.ubah('k1');
    expect(err, isNull);
    expect(f.tersimpan, {'k1'});
    expect(FavoritStore.instance.punya('k1'), isTrue);
    await FavoritStore.instance.ubah('k1');
    expect(FavoritStore.instance.punya('k1'), isFalse);
  });

  test('FavoritStore: gagal di server -> state dikembalikan dan pesan error dikirim balik', () async {
    final f = _FakeFavorit()..gagal = true;
    FavoritStore.instance.service = f;
    FavoritStore.instance.kosongkan();
    final err = await FavoritStore.instance.ubah('k9');
    expect(err, 'Karya tidak ditemukan');
    expect(FavoritStore.instance.punya('k9'), isFalse);
  });

  testWidgets('koleksi: tab Dimiliki menampilkan karya, harga bayar, sumber lelang, dan ID sertifikat; tab Favorit kosong -> pesan', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: KoleksiSayaScreen(service: _FakeFavorit())));
    await tester.pumpAndSettle();
    expect(find.text('Senja m1'), findsOneWidget);
    expect(find.textContaining('Menang lelang'), findsOneWidget);
    expect(find.text('ID Sertifikat: GAL-ART-2026-000001'), findsOneWidget);
    expect(find.text('Periksa sertifikat'), findsOneWidget);
    expect(find.text('Dimiliki (1)'), findsOneWidget);

    await tester.tap(find.text('Favorit (0)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Belum ada favorit'), findsOneWidget);
  });

  testWidgets('notifikasi: daftar dari server; ketuk menandai dibaca dan membuka tujuan', (tester) async {
    final f = _FakeNotif([_n('a'), _n('b', dibaca: true)]);
    Notifikasi? dibuka;
    await tester.pumpWidget(MaterialApp(home: NotifikasiScreen(onBack: () {}, onBuka: (n) => dibuka = n, service: f)));
    await tester.pumpAndSettle();
    expect(find.text('Pesanan baru a'), findsOneWidget);
    expect(find.textContaining('Belum dibaca (1)'), findsOneWidget);

    await tester.tap(find.text('Pesanan baru a'));
    await tester.pumpAndSettle();
    expect(f.dibaca, ['a']);
    expect(dibuka?.id, 'a');
    expect(dibuka?.jenisTautan, 'pesanan');
    expect(dibuka?.idTautan, 'abc');
  });

  testWidgets('notifikasi kosong -> pesan jujur', (tester) async {
    await tester.pumpWidget(MaterialApp(home: NotifikasiScreen(onBack: () {}, onBuka: (_) {}, service: _FakeNotif([]))));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada notifikasi.'), findsOneWidget);
  });
}
