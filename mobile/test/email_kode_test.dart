import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:galeria/screens/auth/lupa_password_screen.dart';
import 'package:galeria/screens/auth/verifikasi_email_screen.dart';
import 'package:galeria/services/auth_service.dart';

class _MemStore implements TokenStore {
  final data = <String, String>{};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
}

Map<String, dynamic> _pair({bool verified = false}) => {
      'access_token': 'acc1',
      'refresh_token': 'sid.rahasia1',
      'token_type': 'bearer',
      'expires_in': 900,
      'user': {'id': 'u1-aaaa-bbbb', 'email': 'budi@demo.test', 'display_name': 'Budi', 'role': 'kolektor', 'email_verified': verified},
    };

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

/// AuthService yang sudah "masuk" lewat login tiruan, lalu semua permintaan berikutnya ditangani [handler].
Future<AuthService> _service(Future<http.Response> Function(http.Request) handler, {bool verified = false}) async {
  final svc = AuthService(
    client: MockClient((req) async {
      if (req.url.path == '/api/auth/login') return _json(_pair(verified: verified));
      return handler(req);
    }),
    store: _MemStore(),
    baseUrl: 'http://test',
  );
  await svc.login('budi@demo.test', 'Rahasia1x');
  return svc;
}

void main() {
  group('AuthService: kode lewat email', () {
    test('lupaPassword mengirim email dan mengembalikan pesan server', () async {
      Map<String, dynamic>? terkirim;
      final svc = await _service((req) async {
        terkirim = jsonDecode(req.body) as Map<String, dynamic>;
        return _json({'pesan': 'Jika email itu terdaftar, kode reset sudah dikirim.'});
      });
      final pesan = await svc.lupaPassword('  Budi@Demo.Test ');
      expect(terkirim, {'email': 'Budi@Demo.Test'});
      expect(pesan, contains('kode reset'));
    });

    test('resetPassword mengirim kode + password baru; 400 jadi AuthException berpesan server', () async {
      final svc = await _service((req) async {
        final b = jsonDecode(req.body) as Map<String, dynamic>;
        return b['kode'] == '123456'
            ? _json({'pesan': 'Password berhasil diubah.'})
            : _json({'detail': 'Kode salah atau sudah kedaluwarsa.'}, 400);
      });
      expect(await svc.resetPassword(email: 'a@b.co', kode: '123456', passwordBaru: 'Baru12345'), contains('berhasil'));
      expect(
        () => svc.resetPassword(email: 'a@b.co', kode: '000000', passwordBaru: 'Baru12345'),
        throwsA(isA<AuthException>().having((e) => e.message, 'pesan', 'Kode salah atau sudah kedaluwarsa.')),
      );
    });

    test('verifikasiEmail memakai token akses dan memperbarui status pengguna', () async {
      String? header;
      final svc = await _service((req) async {
        header = req.headers['Authorization'];
        return _json({'id': 'u1-aaaa-bbbb', 'email': 'budi@demo.test', 'display_name': 'Budi', 'role': 'kolektor', 'email_verified': true});
      });
      expect(svc.user!.emailVerified, isFalse);
      final u = await svc.verifikasiEmail('654321');
      expect(header, 'Bearer acc1');
      expect(u.emailVerified, isTrue);
      expect(svc.user!.emailVerified, isTrue);
    });

    test('server tidak terjangkau -> pesan koneksi, bukan crash', () async {
      final svc = await _service((req) async => throw Exception('putus'));
      expect(() => svc.lupaPassword('a@b.co'), throwsA(isA<AuthException>().having((e) => e.message, 'pesan', contains('Tidak bisa terhubung'))));
    });
  });

  group('LupaPasswordScreen', () {
    testWidgets('alur: email -> kode + password baru -> selesai', (tester) async {
      var selesai = false;
      final dipanggil = <String>[];
      final svc = await _service((req) async {
        dipanggil.add(req.url.path);
        if (req.url.path == '/api/auth/lupa-password') return _json({'pesan': 'Jika email itu terdaftar, kode reset sudah dikirim.'});
        return _json({'pesan': 'Password berhasil diubah. Silakan masuk dengan password baru.'});
      });
      await tester.pumpWidget(MaterialApp(home: LupaPasswordScreen(onBack: () {}, onSelesai: () => selesai = true, service: svc)));

      // email tidak valid ditolak di sisi aplikasi (tanpa menghubungi server)
      await tester.enterText(find.byKey(const Key('lupa_email')), 'bukan-email');
      await tester.tap(find.byKey(const Key('kirim_kode')));
      await tester.pump();
      expect(find.byKey(const Key('lupa_error')), findsOneWidget);
      expect(dipanggil, isEmpty);

      await tester.enterText(find.byKey(const Key('lupa_email')), 'budi@demo.test');
      await tester.tap(find.byKey(const Key('kirim_kode')));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(dipanggil, ['/api/auth/lupa-password']);
      expect(find.byKey(const Key('kode_reset')), findsOneWidget);
      expect(find.text('Kirim ulang (60 dtk)'), findsOneWidget); // jeda kirim ulang berjalan

      // password lemah / tidak sama ditolak di sisi aplikasi
      await tester.enterText(find.byKey(const Key('kode_reset')), '123456');
      await tester.enterText(find.byKey(const Key('password_baru')), 'pendek');
      await tester.enterText(find.byKey(const Key('password_konfirmasi')), 'pendek');
      await tester.tap(find.byKey(const Key('ubah_password')));
      await tester.pump();
      expect(find.textContaining('minimal 8'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('password_baru')), 'Baru12345');
      await tester.enterText(find.byKey(const Key('password_konfirmasi')), 'Baru99999');
      await tester.tap(find.byKey(const Key('ubah_password')));
      await tester.pump();
      expect(find.textContaining('tidak sama'), findsOneWidget);
      expect(selesai, isFalse);

      await tester.enterText(find.byKey(const Key('password_konfirmasi')), 'Baru12345');
      await tester.tap(find.byKey(const Key('ubah_password')));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(dipanggil.last, '/api/auth/reset-password');
      expect(selesai, isTrue);
      // hentikan timer jeda supaya tes tidak menyisakan timer
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('kode salah dari server -> pesan ditampilkan, tetap di layar', (tester) async {
      var selesai = false;
      final svc = await _service((req) async {
        if (req.url.path == '/api/auth/lupa-password') return _json({'pesan': 'ok'});
        return _json({'detail': 'Kode salah atau sudah kedaluwarsa.'}, 400);
      });
      await tester.pumpWidget(MaterialApp(home: LupaPasswordScreen(onBack: () {}, onSelesai: () => selesai = true, service: svc)));
      await tester.enterText(find.byKey(const Key('lupa_email')), 'budi@demo.test');
      await tester.tap(find.byKey(const Key('kirim_kode')));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      await tester.enterText(find.byKey(const Key('kode_reset')), '111111');
      await tester.enterText(find.byKey(const Key('password_baru')), 'Baru12345');
      await tester.enterText(find.byKey(const Key('password_konfirmasi')), 'Baru12345');
      await tester.tap(find.byKey(const Key('ubah_password')));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.text('Kode salah atau sudah kedaluwarsa.'), findsOneWidget);
      expect(selesai, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('VerifikasiEmailScreen', () {
    testWidgets('kode benar -> email terverifikasi dan layar selesai', (tester) async {
      var selesai = false;
      final svc = await _service((req) async => _json(
          {'id': 'u1-aaaa-bbbb', 'email': 'budi@demo.test', 'display_name': 'Budi', 'role': 'kolektor', 'email_verified': true}));
      await tester.pumpWidget(MaterialApp(home: VerifikasiEmailScreen(onBack: () {}, onSelesai: () => selesai = true, service: svc)));
      expect(find.textContaining('budi@demo.test'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('kode_verifikasi')), '12');
      await tester.tap(find.byKey(const Key('verifikasi_tombol')));
      await tester.pump();
      expect(find.byKey(const Key('verif_error')), findsOneWidget); // < 6 digit

      await tester.enterText(find.byKey(const Key('kode_verifikasi')), '123456');
      await tester.tap(find.byKey(const Key('verifikasi_tombol')));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(selesai, isTrue);
      expect(svc.user!.emailVerified, isTrue);
    });

    testWidgets('kirim ulang menampilkan pesan dan menjalankan jeda 60 detik', (tester) async {
      final svc = await _service((req) async => _json({'sudah_terverifikasi': false, 'pesan': 'Kode dikirim ke budi@demo.test. Berlaku 15 menit.'}));
      await tester.pumpWidget(MaterialApp(home: VerifikasiEmailScreen(onBack: () {}, onSelesai: () {}, service: svc)));
      await tester.tap(find.byKey(const Key('kirim_ulang_verifikasi')));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('verif_info')), findsOneWidget);
      expect(find.text('Kirim ulang (60 dtk)'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
