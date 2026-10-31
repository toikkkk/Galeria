import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria/models/karya.dart';
import 'package:galeria/models/pesanan.dart';
import 'package:galeria/screens/kolektor/pesanan/daftar_pesanan_screen.dart';
import 'package:galeria/screens/kolektor/pesanan/konfirmasi_pesanan_screen.dart';
import 'package:galeria/screens/pesanan/detail_pesanan_screen.dart';
import 'package:galeria/services/api_client.dart';
import 'package:galeria/services/pesanan_service.dart';

Pesanan _pesanan({String status = 'menunggu_pembayaran', List<String> aksi = const ['bayar', 'batal'], bool dikirim = false}) =>
    Pesanan.fromJson({
      'id': '3f9a21c4-0000-4000-8000-000000000001',
      'status': status,
      'status_label': 'label',
      'karya': {'id': 'k1', 'title': 'Senja di Teluk', 'artist_name': 'Rani', 'style_name': 'Impressionism'},
      'pembeli_nama': 'Budi',
      'penjual_nama': 'Rani',
      'harga_final_idr': 2000000,
      'komisi_platform_idr': 200000,
      'pendapatan_seniman_idr': 1800000,
      'alamat': {'nama_penerima': 'Budi', 'telepon': '+62812', 'alamat_lengkap': 'Jl. Melati 5', 'kota': 'Surabaya', 'kode_pos': '60111'},
      'sudah_dikirim': dikirim,
      'created_at': '2026-10-31T01:00:00Z',
      'aksi': aksi,
    });

class _FakePesanan extends PesananService {
  _FakePesanan(this.data);
  final List<Pesanan> data;
  final dipanggil = <String>[];

  @override
  Future<List<Pesanan>> daftar({bool penjual = false}) async => data;

  @override
  Future<Pesanan> detail(String id) async => data.first;

  @override
  Future<Pesanan> terima(String id) async {
    dipanggil.add('terima');
    return _pesanan(status: 'selesai', aksi: const []);
  }

  @override
  Future<Pesanan> buat({required String karyaId, required String alamatId}) async {
    dipanggil.add('buat:$karyaId:$alamatId');
    return _pesanan();
  }
}

class _FakeAlamat extends AlamatService {
  _FakeAlamat(this.data);
  final List<Alamat> data;

  @override
  Future<List<Alamat>> daftar() async => data;
}

const _alamat = Alamat(
  id: 'a1', label: 'Rumah', namaPenerima: 'Budi', telepon: '+62812', alamatLengkap: 'Jl. Melati 5',
  kota: 'Surabaya', kodePos: '60111', isUtama: true,
);

void main() {
  testWidgets('daftar pesanan menampilkan pesanan dari server dengan tombol Bayar', (tester) async {
    Pesanan? dibayar;
    await tester.pumpWidget(MaterialApp(
      home: DaftarPesananScreen(service: _FakePesanan([_pesanan()]), onBayarTap: (p) => dibayar = p),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Senja di Teluk'), findsOneWidget);
    expect(find.text('Rp2.000.000'), findsOneWidget);
    await tester.tap(find.text('Bayar sekarang'));
    expect(dibayar?.id, '3f9a21c4-0000-4000-8000-000000000001');
  });

  testWidgets('daftar pesanan kosong menjelaskan cara membeli, bukan data palsu', (tester) async {
    await tester.pumpWidget(MaterialApp(home: DaftarPesananScreen(service: _FakePesanan([]))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Belum ada pesanan'), findsOneWidget);
    expect(find.text('Senja di Teluk'), findsNothing);
  });

  testWidgets('detail pesanan: tombol terima hanya muncul bila server mengizinkan, lalu pesanan selesai', (tester) async {
    final fake = _FakePesanan([_pesanan(status: 'dikonfirmasi', aksi: const ['terima'], dikirim: true)]);
    await tester.pumpWidget(MaterialApp(home: DetailPesananScreen(pesananId: 'x', onBack: () {}, service: fake)));
    await tester.pumpAndSettle();
    expect(find.text('Bayar sekarang'), findsNothing);
    await tester.scrollUntilVisible(find.text('Karya sudah saya terima'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Karya sudah saya terima'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, sudah diterima'));
    await tester.pumpAndSettle();
    expect(fake.dipanggil, ['terima']);
    expect(find.text('Karya sudah saya terima'), findsNothing);
  });

  testWidgets('konfirmasi pesanan: alamat utama terpilih otomatis dan pesanan dibuat dengan karya + alamat itu', (tester) async {
    final fake = _FakePesanan([]);
    Pesanan? dibuat;
    const karya = Karya(
      id: 'k1', assetPath: 'x', title: 'Senja di Teluk', artistName: 'Rani', styleName: 'Impressionism',
      priceIdr: 2000000, galleryName: 'Rani',
    );
    await tester.pumpWidget(MaterialApp(
      home: KonfirmasiPesananScreen(
        karya: karya,
        onBack: () {},
        onDibuat: (p) => dibuat = p,
        alamatService: _FakeAlamat([_alamat]),
        pesananService: fake,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Rumah'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Buat Pesanan & Lanjut Bayar'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Buat Pesanan & Lanjut Bayar'));
    await tester.pump(); // spinner tak pernah 'settle' selama layar belum berpindah
    await tester.pump();
    expect(fake.dipanggil, ['buat:k1:a1']);
    expect(dibuat, isNotNull);
  });

  testWidgets('konfirmasi pesanan tanpa alamat: tidak bisa lanjut, ada ajakan menambah alamat', (tester) async {
    final fake = _FakePesanan([]);
    const karya = Karya(id: 'k1', assetPath: 'x', title: 'T', artistName: 'A', styleName: 'S', priceIdr: 1000000, galleryName: 'A');
    await tester.pumpWidget(MaterialApp(
      home: KonfirmasiPesananScreen(karya: karya, onBack: () {}, onDibuat: (_) {}, alamatService: _FakeAlamat([]), pesananService: fake),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Kamu belum punya alamat pengiriman.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Buat Pesanan & Lanjut Bayar'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Buat Pesanan & Lanjut Bayar'));
    await tester.pump();
    expect(fake.dipanggil, isEmpty);
    expect(find.text('Pilih atau tambahkan alamat pengiriman dulu.'), findsOneWidget);
  });

  test('pesan error server memakai detail berbahasa Indonesia', () {
    expect(ApiException('x').toString(), 'x');
  });
}
