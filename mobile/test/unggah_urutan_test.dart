import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria/models/picked_image.dart';
import 'package:galeria/screens/karya/unggah_karya_screen.dart';
import 'package:galeria/services/digital_art_identity_service.dart';
import 'package:galeria/theme/app_theme.dart';

// PNG 1x1 yang valid supaya Image.memory tidak error.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
PickedImage _foto([String nama = 'lukisan.png']) => PickedImage(bytes: _png, name: nama);

VerificationResult _hasil({
  String artToArt = 'lolos',
  String ai = 'lolos',
  String status = 'terverifikasi',
  double pAi = 0.05,
  List<DuplicateMatch> mirip = const [],
}) =>
    VerificationResult(
      artToArtResult: artToArt,
      aiDetectionResult: ai,
      rekomendasiStatus: status,
      aiGeneratedProbability: pAi,
      phash: 'abc',
      duplicateMatches: mirip,
      modelVersionArtToArt: 'a2a',
      modelVersionArtToAi: 'a2ai',
      persisted: false,
    );

/// Font bawaan mode tes lebarnya tidak realistis sehingga baris teks "overflow" di tes saja; abaikan
/// khusus error itu supaya kegagalan lain tetap terlihat.
void _abaikanOverflow() {
  final asli = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('RenderFlex overflowed')) return;
    asli?.call(d);
  };
  addTearDown(() => FlutterError.onError = asli);
}

Future<void> _buka(
  WidgetTester tester, {
  required Future<VerificationResult> Function(PickedImage) periksa,
}) async {
  _abaikanOverflow();
  tester.view.physicalSize = const Size(1080, 4200); // layar tinggi supaya seluruh form terlihat
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: UnggahKaryaScreen(
      onBack: () {},
      onSubmitted: (_) {},
      pilihFoto: () async => _foto(),
      periksaKeaslian: periksa,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _pilihFoto(WidgetTester tester) async {
  await tester.tap(find.text('+ Pilih Foto Utama'));
  await tester.pump(); // mulai memeriksa
  await tester.pump(const Duration(milliseconds: 300)); // hasil masuk
}

void main() {
  testWidgets('awal: form detail TERKUNCI, hanya ada langkah periksa foto', (tester) async {
    await _buka(tester, periksa: (_) async => _hasil());
    expect(find.text('Langkah 1 dari 2'), findsOneWidget);
    expect(find.text('Periksa Keaslian Foto'), findsOneWidget);
    expect(find.byKey(const Key('cek_info_awal')), findsOneWidget);
    expect(find.text('Judul Karya'), findsNothing);
    expect(find.text('Verifikasi & Daftarkan Karya'), findsNothing);
  });

  testWidgets('foto LOLOS: hasil ditampilkan lalu form judul dst terbuka', (tester) async {
    await _buka(tester, periksa: (_) async => _hasil());
    await _pilihFoto(tester);

    expect(find.text('Lolos pemeriksaan. Lengkapi detail karya di bawah ini.'), findsOneWidget);
    expect(find.text('Langkah 2 dari 2'), findsOneWidget);
    expect(find.text('Detail Karya'), findsOneWidget);
    expect(find.textContaining('Judul Karya'), findsOneWidget);
    expect(find.text('Verifikasi & Daftarkan Karya'), findsOneWidget);
  });

  testWidgets('duplikat sangat mirip (ditolak): form TETAP terkunci, tampil karya yang mirip + pilih foto lain', (tester) async {
    await _buka(
      tester,
      periksa: (_) async => _hasil(
        artToArt: 'duplikat_terdeteksi',
        status: 'ditolak',
        mirip: const [DuplicateMatch(karyaId: 'k1', distance: 0.1, title: 'Senja di Teluk', artistName: 'Aria Wijaya', imageFilename: 'x.jpg')],
      ),
    );
    await _pilihFoto(tester);

    expect(find.textContaining('Mirip dengan "Senja di Teluk" oleh Aria Wijaya'), findsOneWidget);
    expect(find.textContaining('sangat mirip dengan karya yang sudah terdaftar'), findsOneWidget);
    expect(find.byKey(const Key('pilih_foto_lain')), findsOneWidget);
    expect(find.text('Judul Karya'), findsNothing);
    expect(find.text('Verifikasi & Daftarkan Karya'), findsNothing);
  });

  testWidgets('kemungkinan buatan AI (perlu ditinjau): form terkunci, bahasa tidak memastikan', (tester) async {
    await _buka(
      tester,
      periksa: (_) async => _hasil(ai: 'ai_generated_terdeteksi', status: 'perlu_ditinjau', pAi: 0.91),
    );
    await _pilihFoto(tester);

    expect(find.textContaining('perkiraan 91%'), findsOneWidget);
    expect(find.textContaining('perkiraan model, bukan kepastian'), findsWidgets);
    expect(find.text('Judul Karya'), findsNothing);
    expect(find.byKey(const Key('pilih_foto_lain')), findsOneWidget);
  });

  testWidgets('ganti foto setelah ditolak mengulang pemeriksaan dan bisa lolos', (tester) async {
    var panggilan = 0;
    await _buka(
      tester,
      periksa: (_) async {
        panggilan++;
        return panggilan == 1
            ? _hasil(ai: 'ai_generated_terdeteksi', status: 'perlu_ditinjau', pAi: 0.9)
            : _hasil();
      },
    );
    await _pilihFoto(tester);
    expect(find.text('Judul Karya'), findsNothing);

    await tester.tap(find.byKey(const Key('pilih_foto_lain')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(panggilan, 2);
    expect(find.textContaining('Judul Karya'), findsOneWidget);
  });

  testWidgets('pemeriksaan gagal (server mati): pesan + Coba Lagi, form tetap terkunci', (tester) async {
    var panggilan = 0;
    await _buka(
      tester,
      periksa: (_) async {
        panggilan++;
        if (panggilan == 1) throw Exception('server tidak terjangkau');
        return _hasil();
      },
    );
    await _pilihFoto(tester);

    expect(find.textContaining('Pemeriksaan gagal'), findsOneWidget);
    expect(find.text('Judul Karya'), findsNothing);

    await tester.tap(find.byKey(const Key('coba_lagi_cek')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Judul Karya'), findsOneWidget);
  });
}
