import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria/models/karya.dart';
import 'package:galeria/models/pesanan.dart';
import 'package:galeria/screens/karya/ubah_karya_screen.dart';
import 'package:galeria/screens/kolektor/keranjang/keranjang_screen.dart';
import 'package:galeria/services/katalog_service.dart';
import 'package:galeria/services/keranjang_service.dart';
import 'package:galeria/services/pesanan_service.dart';
import 'package:galeria/widgets/keranjang_tombol.dart';

Map<String, dynamic> _karyaJson(String id, {int harga = 1000000, bool terjual = false, String? deskripsi}) => {
      'id': id,
      'title': 'Senja $id',
      'artist_name': 'Rani',
      'style_name': 'Impresionisme',
      'gallery_name': 'Sanggar Rani',
      'price_idr': harga,
      'is_promoted': false,
      'image_filename': 'x.jpg',
      'lebar_cm': 60.0,
      'tinggi_cm': 80.0,
      'terjual': terjual,
      'deskripsi': deskripsi,
    };

Pesanan _pesanan(String id) => Pesanan.fromJson({
      'id': id,
      'status': 'menunggu_pembayaran',
      'status_label': 'Menunggu pembayaran',
      'karya': {'id': 'k1', 'title': 'Senja k1', 'artist_name': 'Rani', 'style_name': 'Impresionisme'},
      'pembeli_nama': 'Budi',
      'penjual_nama': 'Rani',
      'harga_final_idr': 1000000,
      'komisi_platform_idr': 100000,
      'pendapatan_seniman_idr': 900000,
      'alamat': {'nama_penerima': 'Budi', 'telepon': '+62812', 'alamat_lengkap': 'Jl. Melati 5', 'kota': 'Surabaya', 'kode_pos': '60111'},
      'sudah_dikirim': false,
      'sudah_diulas': false,
      'created_at': '2026-11-01T01:00:00Z',
      'aksi': ['bayar', 'batal'],
    });

class _FakeKatalog extends KatalogService {
  Map<String, dynamic>? terkirim;
  String? error;

  @override
  Future<Karya> ubahKarya(String karyaId, Map<String, dynamic> perubahan) async {
    if (error != null) throw Exception(error);
    terkirim = perubahan;
    return Karya.fromJson({..._karyaJson(karyaId), ...perubahan});
  }
}

class _FakeKeranjang extends KeranjangService {
  _FakeKeranjang(this.items);
  List<Map<String, dynamic>> items;
  final aksi = <String>[];
  HasilCheckout? hasil;

  @override
  Future<Keranjang> lihat() async => Keranjang.fromJson({
        'items': items,
        'jumlah': items.length,
        'total_idr': items.where((i) => i['tersedia'] == true).fold<int>(0, (s, i) => s + ((i['karya'] as Map)['price_idr'] as int)),
      });

  @override
  Future<void> hapus(String karyaId) async {
    aksi.add('hapus:$karyaId');
    items = items.where((i) => (i['karya'] as Map)['id'] != karyaId).toList();
  }

  @override
  Future<HasilCheckout> checkout(String alamatId) async {
    aksi.add('checkout:$alamatId');
    return hasil!;
  }
}

class _FakeAlamat extends AlamatService {
  @override
  Future<List<Alamat>> daftar() async => [
        Alamat.fromJson({'id': 'a1', 'label': 'Rumah', 'nama_penerima': 'Budi', 'telepon': '+62812', 'alamat_lengkap': 'Jl. Melati 5', 'kota': 'Surabaya', 'kode_pos': '60111', 'is_utama': true}),
      ];
}

Map<String, dynamic> _item(String id, {bool tersedia = true, String? alasan, int harga = 1000000}) => {
      'karya': _karyaJson(id, harga: harga),
      'tersedia': tersedia,
      'alasan': alasan,
    };

void _besar(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('Ubah karya', () {
    testWidgets('hanya field yang berubah yang dikirim, lalu mengembalikan karya baru', (tester) async {
      _besar(tester);
      final f = _FakeKatalog();
      Karya? hasil;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => hasil = await Navigator.of(context).push<Karya>(MaterialPageRoute(builder: (_) => UbahKaryaScreen(karya: Karya.fromJson(_karyaJson('k1')), service: f))),
            child: const Text('buka'),
          ),
        ),
      ));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(find.text('Ubah Karya'), findsOneWidget);
      // belum ada perubahan -> pesan, tidak memanggil server
      await tester.tap(find.byKey(const Key('simpan_karya')));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada yang diubah.'), findsOneWidget);
      expect(f.terkirim, isNull);

      await tester.enterText(find.byKey(const Key('f_judul')), '  Senja Baru ');
      await tester.enterText(find.byKey(const Key('f_harga')), '1250000');
      await tester.enterText(find.byKey(const Key('f_deskripsi')), 'Cat minyak di atas kanvas.');
      await tester.pump();
      expect(find.textContaining('Rp1.250.000'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('simpan_karya')));
      await tester.tap(find.byKey(const Key('simpan_karya')));
      await tester.pumpAndSettle();

      expect(f.terkirim, {'title': 'Senja Baru', 'price_idr': 1250000, 'deskripsi': 'Cat minyak di atas kanvas.'});
      expect(hasil?.title, 'Senja Baru');
      expect(hasil?.priceIdr, 1250000);
    });

    testWidgets('validasi: judul kosong dan harga 0 ditolak sebelum ke server', (tester) async {
      _besar(tester);
      final f = _FakeKatalog();
      await tester.pumpWidget(MaterialApp(home: UbahKaryaScreen(karya: Karya.fromJson(_karyaJson('k1')), service: f)));
      await tester.enterText(find.byKey(const Key('f_judul')), '   ');
      await tester.enterText(find.byKey(const Key('f_harga')), '0');
      await tester.ensureVisible(find.byKey(const Key('simpan_karya')));
      await tester.tap(find.byKey(const Key('simpan_karya')));
      await tester.pumpAndSettle();
      expect(find.text('Wajib diisi'), findsWidgets);
      expect(find.text('Harga harus lebih dari 0'), findsOneWidget);
      expect(f.terkirim, isNull);
    });

    testWidgets('pesan error server ditampilkan dan layar tetap terbuka', (tester) async {
      _besar(tester);
      final f = _FakeKatalog()..error = 'Karya sedang dilelang, harga tidak bisa diubah.';
      await tester.pumpWidget(MaterialApp(home: UbahKaryaScreen(karya: Karya.fromJson(_karyaJson('k1')), service: f)));
      await tester.enterText(find.byKey(const Key('f_harga')), '900000');
      await tester.ensureVisible(find.byKey(const Key('simpan_karya')));
      await tester.tap(find.byKey(const Key('simpan_karya')));
      await tester.pumpAndSettle();
      expect(find.textContaining('sedang dilelang'), findsOneWidget);
      expect(find.text('Ubah Karya'), findsOneWidget);
    });

    testWidgets('karya terjual: form terkunci dan tombol simpan mati', (tester) async {
      _besar(tester);
      await tester.pumpWidget(MaterialApp(home: UbahKaryaScreen(karya: Karya.fromJson(_karyaJson('k1', terjual: true)), service: _FakeKatalog())));
      expect(find.textContaining('tidak bisa diubah'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('simpan_karya'), skipOffstage: false));
      final tombol = tester.widget<ElevatedButton>(find.byKey(const Key('simpan_karya'), skipOffstage: false));
      expect(tombol.onPressed, isNull);
    });
  });

  group('Keranjang', () {
    testWidgets('daftar, total hanya karya tersedia, karya tak tersedia diberi alasan', (tester) async {
      _besar(tester);
      final f = _FakeKeranjang([_item('a', harga: 1000000), _item('b', harga: 2000000), _item('c', tersedia: false, alasan: 'Sudah terjual atau sedang dipesan orang lain.', harga: 3000000)]);
      await tester.pumpWidget(MaterialApp(
        home: KeranjangScreen(onBack: () {}, onKaryaTap: (_) {}, onSelesai: (_) {}, service: f, alamatService: _FakeAlamat()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Senja a'), findsOneWidget);
      expect(find.text('Senja c'), findsOneWidget);
      expect(find.textContaining('Sudah terjual'), findsOneWidget);
      expect(find.text('TOTAL (2 karya)'), findsOneWidget);
      expect(find.text('Rp3.000.000'), findsWidgets); // total = a + b
      expect(KeranjangStore.instance.jumlah, 3);
    });

    testWidgets('hapus item memanggil server dan memuat ulang', (tester) async {
      _besar(tester);
      final f = _FakeKeranjang([_item('a'), _item('b')]);
      await tester.pumpWidget(MaterialApp(
        home: KeranjangScreen(onBack: () {}, onKaryaTap: (_) {}, onSelesai: (_) {}, service: f, alamatService: _FakeAlamat()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hapus_a')));
      await tester.pumpAndSettle();
      expect(f.aksi, ['hapus:a']);
      expect(find.text('Senja a'), findsNothing);
      expect(find.text('Senja b'), findsOneWidget);
    });

    testWidgets('checkout memakai alamat terpilih, lalu onSelesai menerima pesanan', (tester) async {
      _besar(tester);
      final f = _FakeKeranjang([_item('a')])..hasil = HasilCheckout(pesanan: [_pesanan('p1')], gagal: const []);
      HasilCheckout? selesai;
      await tester.pumpWidget(MaterialApp(
        home: KeranjangScreen(onBack: () {}, onKaryaTap: (_) {}, onSelesai: (h) => selesai = h, service: f, alamatService: _FakeAlamat()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkout_keranjang')));
      await tester.pumpAndSettle();
      expect(f.aksi, ['checkout:a1']);
      expect(selesai?.pesanan.length, 1);
    });

    testWidgets('checkout sebagian gagal: dialog menjelaskan alasan, onSelesai tetap dipanggil', (tester) async {
      _besar(tester);
      final f = _FakeKeranjang([_item('a'), _item('b')])
        ..hasil = HasilCheckout(pesanan: [_pesanan('p1')], gagal: const [CheckoutGagal(karyaId: 'b', judul: 'Senja b', alasan: 'Sudah terjual atau sedang dipesan orang lain.')]);
      HasilCheckout? selesai;
      await tester.pumpWidget(MaterialApp(
        home: KeranjangScreen(onBack: () {}, onKaryaTap: (_) {}, onSelesai: (h) => selesai = h, service: f, alamatService: _FakeAlamat()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkout_keranjang')));
      await tester.pumpAndSettle();
      expect(find.text('1 pesanan dibuat'), findsOneWidget);
      expect(find.textContaining('Senja b: Sudah terjual'), findsOneWidget);
      expect(selesai, isNull); // menunggu dialog ditutup
      await tester.tap(find.text('Mengerti'));
      await tester.pumpAndSettle();
      expect(selesai?.pesanan.length, 1);
    });

    testWidgets('keranjang kosong menampilkan pesan, tanpa tombol pesan', (tester) async {
      _besar(tester);
      await tester.pumpWidget(MaterialApp(
        home: KeranjangScreen(onBack: () {}, onKaryaTap: (_) {}, onSelesai: (_) {}, service: _FakeKeranjang([]), alamatService: _FakeAlamat()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Keranjangmu masih kosong.'), findsOneWidget);
      expect(find.byKey(const Key('checkout_keranjang')), findsNothing);
    });

    testWidgets('tombol keranjang di detail: tamu diminta masuk dan server tidak dipanggil', (tester) async {
      final f = _FakeKeranjang([]);
      KeranjangStore.instance.service = f;
      KeranjangStore.instance.kosongkan();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: KeranjangTombol(karya: Karya.fromJson(_karyaJson('k1'))))));
      await tester.tap(find.byKey(const Key('tombol_keranjang')));
      await tester.pump();
      expect(find.text('Masuk dulu untuk memakai keranjang.'), findsOneWidget);
      expect(f.aksi, isEmpty);
    });

    testWidgets('tombol keranjang mati untuk karya yang sudah terjual', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: KeranjangTombol(karya: Karya.fromJson(_karyaJson('k1', terjual: true))))));
      final b = tester.widget<IconButton>(find.byKey(const Key('tombol_keranjang')));
      expect(b.onPressed, isNull);
    });

    testWidgets('lencana ikon keranjang menampilkan jumlah', (tester) async {
      KeranjangStore.instance.setelahPerubahan(['a', 'b', 'c']);
      await tester.pumpWidget(MaterialApp(home: Scaffold(appBar: AppBar(actions: [KeranjangIkon(onTap: () {})]))));
      expect(find.text('3'), findsOneWidget);
      KeranjangStore.instance.setelahPerubahan([]);
      await tester.pump();
      expect(find.text('3'), findsNothing);
    });
  });
}
