import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria/models/event.dart';
import 'package:galeria/models/karya.dart';
import 'package:galeria/models/komunitas.dart';
import 'package:galeria/screens/community/community_detail_screen.dart';
import 'package:galeria/screens/community/komunitas_seniman_screen.dart';
import 'package:galeria/services/komunitas_service.dart';

Map<String, dynamic> _k({String id = 'k1', bool terbuka = true, String? saya, int anggota = 3, int? permintaan}) => {
      'id': id,
      'nama': 'Perupa Realis Nusantara',
      'deskripsi': 'Komunitas pelukis realis',
      'aliran': ['Realisme'],
      'terbuka': terbuka,
      'aturan': 'Saling menghargai',
      'pemilik_nama': 'Rani',
      'jumlah_anggota': anggota,
      'dibuat_at': DateTime.now().toUtc().toIso8601String(),
      'saya': saya,
      'jumlah_permintaan': permintaan,
    };

Map<String, dynamic> _post({String id = 'p1', int like = 0, bool saya = false, bool hapus = false}) => {
      'id': id,
      'komunitas_id': 'k1',
      'penulis_id': 'u1',
      'penulis_nama': 'Budi Santoso',
      'penulis_pemilik': false,
      'teks': 'Karya terbaruku',
      'image_url': null,
      'disematkan': false,
      'jumlah_like': like,
      'jumlah_komentar': 1,
      'saya_like': saya,
      'waktu': DateTime.now().toUtc().toIso8601String(),
      'bisa_hapus': hapus,
      'bisa_sematkan': false,
    };

class _Fake extends KomunitasService {
  _Fake(this.komunitas, {this.daftarData = const [], this.posts = const []});
  Komunitas komunitas;
  final List<Komunitas> daftarData;
  final List<PostKomunitas> posts;
  final aksi = <String>[];
  bool? terakhirSaya;

  @override
  Future<List<Komunitas>> daftar({bool saya = false, String? q}) async {
    terakhirSaya = saya;
    return daftarData;
  }

  @override
  Future<Komunitas> detail(String id) async => komunitas;

  @override
  Future<HalamanPost> post(String id, {DateTime? sebelum}) async => HalamanPost(items: posts, adaLagi: false);

  @override
  Future<Komunitas> gabung(String id) async {
    aksi.add('gabung');
    return komunitas = Komunitas.fromJson(_k(saya: komunitas.terbuka ? 'anggota' : 'menunggu', terbuka: komunitas.terbuka));
  }

  @override
  Future<PostKomunitas> tulisPost(String id, String teks) async {
    aksi.add('post:$teks');
    return PostKomunitas.fromJson({..._post(id: 'baru'), 'teks': teks});
  }

  @override
  Future<(bool, int)> like(String postId) async {
    aksi.add('like:$postId');
    return (true, 1);
  }

  @override
  Future<List<KomentarKomunitas>> komentar(String postId) async => [
        KomentarKomunitas.fromJson({'id': 'c1', 'penulis_nama': 'Sari P.', 'teks': 'Bagus sekali!', 'waktu': DateTime.now().toUtc().toIso8601String(), 'bisa_hapus': false}),
      ];

  @override
  Future<List<Karya>> karya(String id) async => [];

  @override
  Future<List<EventInfo>> event(String id) async => [];
}

Future<void> _buka(WidgetTester tester, _Fake f) async {
  tester.view.physicalSize = const Size(800, 2400); // cukup tinggi agar semua tombol terlihat tanpa menggulir
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: CommunityDetailScreen(komunitasId: 'k1', onBack: () {}, service: f)));
  await tester.pumpAndSettle();
}

void main() {
  test('Komunitas.fromJson: hubungan pengguna menentukan akses isi', () {
    expect(Komunitas.fromJson(_k(terbuka: true)).bisaLihatIsi, isTrue);
    expect(Komunitas.fromJson(_k(terbuka: false)).bisaLihatIsi, isFalse);
    expect(Komunitas.fromJson(_k(terbuka: false, saya: 'menunggu')).bisaLihatIsi, isFalse);
    expect(Komunitas.fromJson(_k(terbuka: false, saya: 'anggota')).bisaLihatIsi, isTrue);
    expect(Komunitas.fromJson(_k(saya: 'pemilik')).pemilik, isTrue);
    expect(Komunitas.fromJson(_k()).inisial, 'PN');
  });

  test('waktuRelatif', () {
    final n = DateTime(2026, 10, 31, 12);
    expect(waktuRelatif(n.subtract(const Duration(seconds: 20)), n), 'baru saja');
    expect(waktuRelatif(n.subtract(const Duration(minutes: 5)), n), '5 mnt lalu');
    expect(waktuRelatif(n.subtract(const Duration(hours: 3)), n), '3 jam lalu');
    expect(waktuRelatif(n.subtract(const Duration(days: 2)), n), '2 hari lalu');
  });

  testWidgets('daftar komunitas: tab Saya meminta saya=true; kosong -> pesan jujur', (tester) async {
    final f = _Fake(Komunitas.fromJson(_k()), daftarData: [Komunitas.fromJson(_k(saya: 'pemilik', permintaan: 2))]);
    await tester.pumpWidget(MaterialApp(home: KomunitasSenimanScreen(onBack: () {}, onBuka: (_) {}, service: f)));
    await tester.pumpAndSettle();
    expect(f.terakhirSaya, isTrue);
    expect(find.text('Perupa Realis Nusantara'), findsOneWidget);
    expect(find.text('PEMILIK'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // lencana permintaan bergabung

    await tester.pumpWidget(MaterialApp(home: KomunitasSenimanScreen(key: UniqueKey(), onBack: () {}, onBuka: (_) {}, service: _Fake(Komunitas.fromJson(_k())))));
    await tester.pumpAndSettle();
    expect(find.textContaining('belum bergabung di komunitas mana pun'), findsOneWidget);
  });

  testWidgets('buat komunitas: nama terlalu pendek ditolak sebelum menghubungi server', (tester) async {
    final f = _Fake(Komunitas.fromJson(_k()));
    await tester.pumpWidget(MaterialApp(home: KomunitasSenimanScreen(onBack: () {}, onBuka: (_) {}, service: f)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('buat_komunitas')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nama_komunitas')), 'ab');
    await tester.ensureVisible(find.byKey(const Key('simpan_komunitas')));
    await tester.tap(find.byKey(const Key('simpan_komunitas')));
    await tester.pump();
    expect(find.text('Nama komunitas minimal 3 karakter.'), findsOneWidget);
  });

  testWidgets('detail terbuka (belum anggota): ada tombol Bergabung, tidak ada kotak posting, postingan terbaca', (tester) async {
    final f = _Fake(Komunitas.fromJson(_k()), posts: [PostKomunitas.fromJson(_post())]);
    await _buka(tester, f);
    expect(find.text('Karya terbaruku'), findsOneWidget);
    expect(find.byKey(const Key('gabung_komunitas')), findsOneWidget);
    expect(find.byKey(const Key('teks_post')), findsNothing);
    expect(find.text('Bergabunglah untuk ikut berdiskusi.'), findsOneWidget);
  });

  testWidgets('detail tertutup (bukan anggota): isi terkunci, tidak ada postingan', (tester) async {
    final f = _Fake(Komunitas.fromJson(_k(terbuka: false)), posts: [PostKomunitas.fromJson(_post())]);
    await _buka(tester, f);
    expect(find.textContaining('Komunitas ini tertutup'), findsOneWidget);
    expect(find.text('Karya terbaruku'), findsNothing);
    expect(find.text('Ajukan bergabung'), findsOneWidget);
  });

  testWidgets('anggota bisa memposting dan menyukai; kiriman memakai teks yang benar', (tester) async {
    final f = _Fake(Komunitas.fromJson(_k(saya: 'anggota')), posts: [PostKomunitas.fromJson(_post())]);
    await _buka(tester, f);
    expect(find.byKey(const Key('teks_post')), findsOneWidget);
    expect(find.byKey(const Key('keluar_komunitas')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('teks_post')), 'Halo semuanya');
    await tester.tap(find.byKey(const Key('kirim_post')));
    await tester.pumpAndSettle();
    expect(f.aksi, contains('post:Halo semuanya'));
    expect(find.text('Halo semuanya'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border).last);
    await tester.pumpAndSettle();
    expect(f.aksi, contains('like:p1'));
  });

  testWidgets('komentar: sheet menampilkan komentar dan kotak tulis hanya untuk anggota', (tester) async {
    final f = _Fake(Komunitas.fromJson(_k(saya: 'anggota')), posts: [PostKomunitas.fromJson(_post())]);
    await _buka(tester, f);
    await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Bagus sekali!'), findsOneWidget);
    expect(find.byKey(const Key('teks_komentar')), findsOneWidget);
  });

  testWidgets('klik Bergabung memanggil server dan berubah menjadi anggota', (tester) async {
    final f = _Fake(Komunitas.fromJson(_k()));
    await _buka(tester, f);
    await tester.tap(find.byKey(const Key('gabung_komunitas')));
    await tester.pumpAndSettle();
    expect(f.aksi, ['gabung']);
  });
}
