import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:galeria/models/dashboard_seniman.dart';
import 'package:galeria/screens/dashboard/dashboard_screen.dart';
import 'package:galeria/services/api_client.dart';
import 'package:galeria/services/dashboard_service.dart';

class _FakeService extends DashboardService {
  _FakeService({this.gagal = false, this.segmenTersedia = true});

  bool gagal;
  final bool segmenTersedia;

  @override
  Future<List<SenimanDemo>> fetchSenimanDemo() async {
    if (gagal) throw ApiException('Gagal terhubung ke backend');
    return const [SenimanDemo(id: 's1', displayName: 'Claude Monet', levelReputasi: 'mapan', nTerjual: 10)];
  }

  @override
  Future<RingkasanSeniman> fetchRingkasan(String senimanId, {int periode = 30}) async => RingkasanSeniman(
        id: senimanId,
        displayName: 'Claude Monet',
        levelReputasi: 'mapan',
        periodeHari: periode,
        nTerjual: 18,
        omzetIdr: 1140000000,
        komisiPlatformIdr: 114000000,
        pendapatanBersihIdr: 1026000000,
        hargaRata2Idr: 63300000,
        nPembeliUnik: 15,
        karyaTersedia: 41,
        karyaTerjualTotal: 220,
        perubahanNTerjualPct: 12.5,
        perubahanOmzetPct: -3.0,
      );

  @override
  Future<List<PenjualanBulan>> fetchPenjualanBulanan(String senimanId, {int bulan = 12}) async => [
        for (var m = 1; m <= bulan; m++)
          PenjualanBulan(bulan: '2026-${m.toString().padLeft(2, '0')}-01', nTerjual: m % 3, omzetIdr: (m % 3) * 1000000),
      ];

  @override
  Future<List<AliranSeniman>> fetchAliran(String senimanId) async => const [
        AliranSeniman(
          styleName: 'Impressionism',
          nTerjual: 9,
          omzetIdr: 500000000,
          hargaRata2Idr: 55000000,
          hargaPasarRata2Idr: 50000000,
          selisihPct: 10,
        ),
      ];

  @override
  Future<SegmenPembeliHasil> fetchSegmenPembeli(String senimanId) async => segmenTersedia
      ? const SegmenPembeliHasil(
          tersedia: true,
          items: [SegmenPembeli(segmenId: 2, segmenNama: 'Kolektor Menengah Aktif', nPembeli: 7, porsiPct: 46.7)],
        )
      : const SegmenPembeliHasil(tersedia: false, items: []);

  @override
  Future<TrenPasar> fetchTrenPasar() async => const TrenPasar(
        senimanRamai: [
          SenimanRamai(senimanId: 's2', displayName: 'Vincent Van Gogh', nTerjual30Hari: 12, lonjakan: 2.1, hargaRata2Idr: 85000000),
        ],
        aliranRamai: [
          AliranRamai(styleName: 'Impressionism', nTerjual30Hari: 55, porsiPct: 31.0, hargaRata2Idr: 48000000),
        ],
      );
}

Future<void> _pump(WidgetTester tester, _FakeService service, {double lebar = 800}) async {
  tester.view.physicalSize = Size(lebar, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: DashboardScreen(service: service)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan data seniman dari service', (tester) async {
    await _pump(tester, _FakeService());

    expect(find.text('Rp1.026.000.000'), findsOneWidget);
    expect(find.text('Claude Monet'), findsNothing); // baris profil dihapus
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    expect(find.text('Analitik Penjualan'), findsOneWidget);
    expect(find.text('Pembeli'), findsOneWidget); // tab segmen tersedia
    expect(find.text('Pasar'), findsOneWidget);
    expect(find.textContaining('Kunjungan'), findsNothing);
  });

  testWidgets('toggle Karya/Omzet mengganti grafik, tab Analitik berpindah', (tester) async {
    await _pump(tester, _FakeService());

    expect(find.text('Jumlah karya terjual per bulan'), findsOneWidget);
    await tester.tap(find.text('Omzet (Rp)'));
    await tester.pumpAndSettle();
    expect(find.text('Omzet (Rp) per bulan'), findsOneWidget);
    expect(find.text('Jumlah karya terjual per bulan'), findsNothing);

    // tab Aliran (default) -> Pasar
    expect(find.text('Harga rata-rata Rp55 jt'), findsOneWidget);
    await tester.ensureVisible(find.text('Pasar'));
    await tester.tap(find.text('Pasar'));
    await tester.pumpAndSettle();
    expect(find.text('Vincent Van Gogh'), findsOneWidget);
    expect(find.text('PELUKIS RAMAI'), findsOneWidget);
  });

  testWidgets('tidak overflow di layar sempit (360 dp, mis. Infinix)', (tester) async {
    await _pump(tester, _FakeService(), lebar: 360);

    // Overflow RenderFlex dilaporkan sebagai exception -> test gagal bila ada.
    expect(tester.takeException(), isNull);
    expect(find.text('Rp1.026.000.000'), findsOneWidget);
  });

  testWidgets('segmen disembunyikan bila belum tersedia', (tester) async {
    await _pump(tester, _FakeService(segmenTersedia: false));

    expect(find.text('Analitik Penjualan'), findsOneWidget);
    expect(find.text('Aliran'), findsOneWidget);
    expect(find.text('Pembeli'), findsNothing); // tab disembunyikan
  });

  testWidgets('backend gagal -> pesan error + Coba lagi, bukan angka palsu', (tester) async {
    final service = _FakeService(gagal: true);
    await _pump(tester, service);

    expect(find.text('Dashboard tidak dapat dimuat'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.textContaining('Rp184.750.000'), findsNothing);

    service.gagal = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Rp1.026.000.000'), findsOneWidget);
  });
}
