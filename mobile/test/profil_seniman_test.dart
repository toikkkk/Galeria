import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria/models/dashboard_seniman.dart';
import 'package:galeria/models/langganan.dart';
import 'package:galeria/models/sentimen_seniman.dart';
import 'package:galeria/screens/profile/profil_screen.dart';
import 'package:galeria/services/dashboard_service.dart';
import 'package:galeria/services/langganan_service.dart';
import 'package:galeria/services/sentimen_service.dart';

class _Dashboard extends DashboardService {
  _Dashboard(this.hasil);
  final RingkasanSeniman? hasil;
  @override
  Future<RingkasanSeniman> fetchRingkasan({int periode = 30}) async => hasil ?? (throw Exception('offline'));
}

class _Sentimen extends SentimenService {
  _Sentimen(this.rating, {this.gagal = false});
  final double? rating;
  final bool gagal;
  @override
  Future<SentimenSeniman> fetchSentimen() async => gagal
      ? throw Exception('offline')
      : SentimenSeniman(senimanId: 's', nUlasan: 3, hitung: const [], trenBulanan: const [], ulasanTerbaru: const [], ratingRata2: rating);
}

class _Langganan extends LanggananService {
  _Langganan(this.pro);
  final bool pro;
  @override
  Future<LanggananSaya> saya() async => LanggananSaya(aktif: const [], pro: pro, ar: false);
}

RingkasanSeniman _ringkasan({required int tersedia, required int terjual, required int bersih}) => RingkasanSeniman(
      id: 's',
      displayName: 'Seniman',
      levelReputasi: 'pemula',
      periodeHari: 365,
      nTerjual: terjual,
      omzetIdr: bersih,
      komisiPlatformIdr: 0,
      pendapatanBersihIdr: bersih,
      hargaRata2Idr: 0,
      nPembeliUnik: 0,
      karyaTersedia: tersedia,
      karyaTerjualTotal: terjual,
      perubahanNTerjualPct: null,
      perubahanOmzetPct: null,
    );

Future<void> _tampil(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: w));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('KPI profil memakai angka dari backend, bukan angka contoh lama', (tester) async {
    await _tampil(
      tester,
      ProfilScreen(
        dashboard: _Dashboard(_ringkasan(tersedia: 6, terjual: 15, bersih: 61_650_000)),
        sentimen: _Sentimen(4.25),
        langganan: _Langganan(true),
      ),
    );
    expect(find.text('6'), findsOneWidget); // karya aktif
    expect(find.text('15'), findsOneWidget); // terjual
    expect(find.text('4,3'), findsOneWidget); // rating (dibulatkan 1 desimal, koma)
    expect(find.text('PRO'), findsOneWidget);
    expect(find.textContaining('61.650.000'), findsOneWidget);
    // angka karangan lama tidak boleh muncul lagi
    for (final lama in ['12', '1.240', '4.9', 'Rp 184.750.000']) {
      expect(find.text(lama), findsNothing, reason: lama);
    }
    expect(find.text('Pengikut'), findsNothing);
  });

  testWidgets('akun baru: tanpa penjualan/ulasan/langganan tidak menampilkan angka karangan', (tester) async {
    await _tampil(
      tester,
      ProfilScreen(
        dashboard: _Dashboard(_ringkasan(tersedia: 0, terjual: 0, bersih: 0)),
        sentimen: _Sentimen(null),
        langganan: _Langganan(false),
      ),
    );
    expect(find.text('0'), findsNWidgets(2)); // karya aktif + terjual
    expect(find.text('-'), findsOneWidget); // rating belum ada
    expect(find.text('PRO'), findsNothing);
    expect(find.textContaining('Rp'), findsNothing);
  });

  testWidgets('backend tak terjangkau: tampil "-" dan layar tetap jalan', (tester) async {
    await _tampil(
      tester,
      ProfilScreen(dashboard: _Dashboard(null), sentimen: _Sentimen(null, gagal: true), langganan: _Langganan(false)),
    );
    expect(find.text('-'), findsNWidgets(3));
    expect(find.text('Karya Aktif'), findsOneWidget);
  });
}
