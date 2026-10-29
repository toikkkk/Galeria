import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria/screens/auth/login_screen.dart';
import 'package:galeria/screens/kolektor/auth/daftar_kolektor_screen.dart';
import 'package:galeria/screens/onboarding/role_selection_screen.dart';
import 'package:galeria/services/auth_service.dart';
import 'package:galeria/theme/app_theme.dart';
import 'package:galeria/utils/password_strength.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _MemStore implements TokenStore {
  final data = <String, String>{};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
}

Map<String, dynamic> _pair({String role = 'kolektor', String refresh = 'sid.rahasia1', int ttl = 900, String access = 'acc1'}) => {
      'access_token': access,
      'refresh_token': refresh,
      'token_type': 'bearer',
      'expires_in': ttl,
      'user': {
        'id': 'u1',
        'email': 'a@x.id',
        'display_name': 'Ayu',
        'role': role,
        'avatar_url': null,
        'email_verified': false,
      },
    };

http.Response _json(Object body, [int code = 200]) =>
    http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json'});

class _Req {
  _Req(this.path, this.body);
  final String path;
  final Map<String, dynamic> body;
}

(AuthService, _MemStore, List<_Req>) _buat(
  Future<http.Response> Function(_Req r) handler, {
  DateTime Function()? now,
}) {
  final store = _MemStore();
  final log = <_Req>[];
  final client = MockClient((req) async {
    final r = _Req(req.url.path, req.body.isEmpty ? {} : jsonDecode(req.body) as Map<String, dynamic>);
    log.add(r);
    return handler(r);
  });
  return (AuthService(client: client, store: store, baseUrl: 'http://t', sekarang: now), store, log);
}

void main() {
  group('AuthService', () {
    test('login berhasil: menyimpan token + pengguna, status masuk', () async {
      final (svc, store, log) = _buat((r) async => _json(_pair(role: 'seniman')));
      final u = await svc.login(' a@x.id ', 'Rahasia123');
      expect(u.isSeniman, isTrue);
      expect(svc.loggedIn, isTrue);
      expect(log.single.path, '/api/auth/login');
      expect(log.single.body['email'], 'a@x.id'); // dirapikan
      expect(store.data['galeria_refresh_token'], 'sid.rahasia1');
      expect(jsonDecode(store.data['galeria_user']!)['display_name'], 'Ayu');
    });

    test('login gagal: pesan server ditampilkan, tidak masuk', () async {
      final (svc, store, _) = _buat((r) async => _json({'detail': 'Email atau password salah.'}, 401));
      await expectLater(
        svc.login('a@x.id', 'salah'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'Email atau password salah.').having((e) => e.statusCode, 'status', 401)),
      );
      expect(svc.loggedIn, isFalse);
      expect(store.data, isEmpty);
    });

    test('galat validasi 422 (daftar) dijadikan satu kalimat Indonesia', () async {
      final (svc, _, _) = _buat((r) async => _json({
            'detail': [
              {'msg': 'Value error, password harus mengandung huruf dan angka', 'loc': ['body', 'password']}
            ]
          }, 422));
      await expectLater(
        svc.register(email: 'a@x.id', password: 'x', displayName: 'Ayu', role: 'kolektor'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'Password harus mengandung huruf dan angka')),
      );
    });

    test('tanpa koneksi: pesan ramah, bukan stack trace', () async {
      final (svc, _, _) = _buat((r) async => throw http.ClientException('putus'));
      await expectLater(
        svc.login('a@x.id', 'Rahasia123'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('Tidak bisa terhubung'))),
      );
    });

    test('server 500 tanpa detail: pesan umum', () async {
      final (svc, _, _) = _buat((r) async => http.Response('<html>boom</html>', 500));
      await expectLater(
        svc.login('a@x.id', 'Rahasia123'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('Server sedang bermasalah'))),
      );
    });

    test('register mengirim nama, peran, dan email yang dirapikan', () async {
      final (svc, _, log) = _buat((r) async => _json(_pair(), 201));
      await svc.register(email: ' A@X.id ', password: 'Rahasia123', displayName: ' Ayu ', role: 'kolektor');
      expect(log.single.path, '/api/auth/register');
      expect(log.single.body, {'email': 'A@X.id', 'password': 'Rahasia123', 'display_name': 'Ayu', 'role': 'kolektor'});
      expect(svc.loggedIn, isTrue);
    });

    test('restore: sesi tersimpan dipulihkan tanpa jaringan', () async {
      final (svc, store, log) = _buat((r) async => _json({}));
      store.data['galeria_refresh_token'] = 'sid.abc';
      store.data['galeria_user'] = jsonEncode(AuthUser.fromJson(_pair(role: 'seniman')['user'] as Map<String, dynamic>).toJson());
      await svc.restore();
      expect(svc.loggedIn, isTrue);
      expect(svc.user!.role, 'seniman');
      expect(log, isEmpty);
    });

    test('restore: data tersimpan rusak dianggap belum login (bukan crash)', () async {
      final (svc, store, _) = _buat((r) async => _json({}));
      store.data['galeria_refresh_token'] = 'sid.abc';
      store.data['galeria_user'] = '{bukan json';
      await svc.restore();
      expect(svc.loggedIn, isFalse);
      expect(store.data, isEmpty);
    });

    test('accessToken: dipakai ulang selagi masih lama, diperbarui saat hampir habis', () async {
      var jam = DateTime(2026, 1, 1, 10);
      var n = 0;
      final (svc, store, log) = _buat((r) async {
        n++;
        return _json(_pair(access: 'acc$n', refresh: 'sid.r$n'));
      }, now: () => jam);
      await svc.login('a@x.id', 'Rahasia123'); // acc1, ttl 15 menit
      expect(await svc.accessToken(), 'acc1');
      expect(log.length, 1); // tidak ada refresh
      jam = jam.add(const Duration(minutes: 14, seconds: 45)); // sisa < 30 dtk
      expect(await svc.accessToken(), 'acc2');
      expect(log.last.path, '/api/auth/refresh');
      expect(log.last.body['refresh_token'], 'sid.r1'); // memakai token terbaru
      expect(store.data['galeria_refresh_token'], 'sid.r2'); // rotasi tersimpan
    });

    test('refresh BERSAMAAN hanya mengirim SATU permintaan (rotasi server)', () async {
      var jam = DateTime(2026, 1, 1, 10);
      var refresh = 0;
      final (svc, _, log) = _buat((r) async {
        if (r.path == '/api/auth/refresh') {
          refresh++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _json(_pair(access: 'baru', refresh: 'sid.r$refresh'));
        }
        return _json(_pair());
      }, now: () => jam);
      await svc.login('a@x.id', 'Rahasia123');
      jam = jam.add(const Duration(minutes: 20)); // access sudah kedaluwarsa
      final hasil = await Future.wait([svc.accessToken(), svc.accessToken(), svc.accessToken()]);
      expect(hasil, ['baru', 'baru', 'baru']);
      expect(log.where((r) => r.path == '/api/auth/refresh').length, 1);
    });

    test('refresh ditolak server (401): keluar otomatis + sinyal sesi berakhir', () async {
      var jam = DateTime(2026, 1, 1, 10);
      final (svc, store, _) = _buat((r) async {
        return r.path == '/api/auth/refresh' ? _json({'detail': 'Sesi tidak valid'}, 401) : _json(_pair());
      }, now: () => jam);
      await svc.login('a@x.id', 'Rahasia123');
      jam = jam.add(const Duration(minutes: 20));
      expect(await svc.accessToken(), isNull);
      expect(svc.loggedIn, isFalse);
      expect(svc.sesiBerakhir.value, isTrue);
      expect(store.data, isEmpty);
    });

    test('refresh gagal karena OFFLINE: tetap masuk, tapi tidak mengembalikan token kedaluwarsa', () async {
      var jam = DateTime(2026, 1, 1, 10);
      final (svc, store, _) = _buat((r) async {
        if (r.path == '/api/auth/refresh') throw http.ClientException('offline');
        return _json(_pair());
      }, now: () => jam);
      await svc.login('a@x.id', 'Rahasia123');
      jam = jam.add(const Duration(minutes: 20));
      expect(await svc.accessToken(), isNull);
      expect(svc.loggedIn, isTrue); // tidak ditendang hanya karena offline
      expect(svc.sesiBerakhir.value, isFalse);
      expect(store.data['galeria_refresh_token'], isNotNull);
    });

    test('validasiSesi saat startup: sesi sudah dicabut -> logout', () async {
      final (svc, store, _) = _buat((r) async => _json({'detail': 'x'}, 401));
      store.data['galeria_refresh_token'] = 'sid.abc';
      store.data['galeria_user'] = jsonEncode(AuthUser.fromJson(_pair()['user'] as Map<String, dynamic>).toJson());
      await svc.restore();
      await svc.validasiSesi();
      expect(svc.loggedIn, isFalse);
      expect(svc.sesiBerakhir.value, isTrue);
    });

    test('login berhasil mereset sinyal sesi berakhir', () async {
      final (svc, _, _) = _buat((r) async => _json(_pair()));
      svc.sesiBerakhir.value = true;
      await svc.login('a@x.id', 'Rahasia123');
      expect(svc.sesiBerakhir.value, isFalse);
    });

    test('logout: membersihkan lokal DAN memberi tahu server dengan refresh token', () async {
      final (svc, store, log) = _buat((r) async => r.path == '/api/auth/logout' ? http.Response('', 204) : _json(_pair()));
      await svc.login('a@x.id', 'Rahasia123');
      await svc.logout();
      expect(svc.loggedIn, isFalse);
      expect(store.data, isEmpty);
      expect(log.last.path, '/api/auth/logout');
      expect(log.last.body['refresh_token'], 'sid.rahasia1');
    });

    test('logout tetap membersihkan lokal walau server tak terjangkau', () async {
      final (svc, store, _) = _buat((r) async {
        if (r.path == '/api/auth/logout') throw http.ClientException('offline');
        return _json(_pair());
      });
      await svc.login('a@x.id', 'Rahasia123');
      await svc.logout();
      expect(svc.loggedIn, isFalse);
      expect(store.data, isEmpty);
    });

    test('accessToken null bila belum masuk (tidak memanggil server)', () async {
      final (svc, _, log) = _buat((r) async => _json(_pair()));
      expect(await svc.accessToken(), isNull);
      expect(log, isEmpty);
    });
  });

  group('aturan password (sejalan dengan server)', () {
    test('syarat minimal', () {
      expect(validasiPassword('pendek1'), isNotNull); // < 8
      expect(validasiPassword('hurufsajaaaa'), isNotNull); // tanpa angka
      expect(validasiPassword('12345678'), isNotNull); // tanpa huruf
      expect(validasiPassword('Rahasia123'), isNull);
      expect(validasiPassword('a1' * 40), isNotNull); // > 72 byte
    });

    test('kekuatan hidup: di bawah syarat tidak pernah lebih dari Lemah', () {
      expect(kekuatanPassword(''), 0);
      expect(kekuatanPassword('abc'), 1);
      expect(kekuatanPassword('hurufsajaaaaaaaaaa'), 1);
      expect(kekuatanPassword('Rahasia123'), greaterThanOrEqualTo(2));
      expect(kekuatanPassword('Rahasia-Panjang-123!'), 4);
    });
  });

  group('layar', () {
    Widget app(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

    testWidgets('login: password salah menampilkan pesan server dan TIDAK melanjutkan', (tester) async {
      final (svc, _, _) = _buat((r) async => _json({'detail': 'Email atau password salah.'}, 401));
      AuthService.instance = svc;
      UserRole? masuk;
      await tester.pumpWidget(app(LoginScreen(onBack: () {}, onLoginSuccess: (r) => masuk = r, onRegisterTap: () {})));
      await tester.enterText(find.byType(TextField).at(0), 'a@x.id');
      await tester.enterText(find.byType(TextField).at(1), 'salah');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();
      expect(find.text('Email atau password salah.'), findsOneWidget);
      expect(masuk, isNull);
    });

    testWidgets('login: kolom kosong ditolak di aplikasi (tanpa memanggil server)', (tester) async {
      final (svc, _, log) = _buat((r) async => _json(_pair()));
      AuthService.instance = svc;
      await tester.pumpWidget(app(LoginScreen(onBack: () {}, onLoginSuccess: (_) {}, onRegisterTap: () {})));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pump();
      expect(find.byKey(const Key('login_error')), findsOneWidget);
      expect(log, isEmpty);
    });

    testWidgets('login: tujuan ditentukan PERAN AKUN dari server, bukan pilihan layar', (tester) async {
      final (svc, _, _) = _buat((r) async => _json(_pair(role: 'seniman')));
      AuthService.instance = svc;
      UserRole? masuk;
      await tester.pumpWidget(app(LoginScreen(onBack: () {}, onLoginSuccess: (r) => masuk = r, onRegisterTap: () {})));
      await tester.enterText(find.byType(TextField).at(0), 'a@x.id');
      await tester.enterText(find.byType(TextField).at(1), 'Rahasia123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();
      expect(masuk, UserRole.seniman);
    });

    testWidgets('login: tombol Google tidak lagi melewati login', (tester) async {
      final (svc, _, _) = _buat((r) async => _json(_pair()));
      AuthService.instance = svc;
      UserRole? masuk;
      await tester.pumpWidget(app(LoginScreen(onBack: () {}, onLoginSuccess: (r) => masuk = r, onRegisterTap: () {})));
      await tester.ensureVisible(find.text('Masuk dengan Google'));
      await tester.tap(find.text('Masuk dengan Google'));
      await tester.pump();
      expect(masuk, isNull);
    });

    Future<void> isiDaftar(WidgetTester tester, {required String pw, String pw2 = ''}) async {
      final f = find.byType(TextField);
      await tester.enterText(f.at(0), 'Ayu Lestari');
      await tester.enterText(f.at(2), 'ayu@x.id');
      await tester.enterText(f.at(3), pw);
      await tester.enterText(f.at(4), pw2.isEmpty ? pw : pw2);
      await tester.ensureVisible(find.text('Lanjutkan Pendaftaran'));
    }

    testWidgets('daftar kolektor: password lemah ditolak SEBELUM menghubungi server', (tester) async {
      final (svc, _, log) = _buat((r) async => _json(_pair(), 201));
      AuthService.instance = svc;
      var lanjut = false;
      await tester.pumpWidget(app(DaftarKolektorScreen(onBack: () {}, onContinue: () => lanjut = true, onLoginTap: () {})));
      await isiDaftar(tester, pw: 'pendek');
      await tester.tap(find.text('Lanjutkan Pendaftaran'));
      await tester.pump();
      expect(find.byKey(const Key('daftar_error')), findsOneWidget);
      expect(log, isEmpty);
      expect(lanjut, isFalse);
    });

    testWidgets('daftar kolektor: konfirmasi tidak sama ditolak', (tester) async {
      final (svc, _, log) = _buat((r) async => _json(_pair(), 201));
      AuthService.instance = svc;
      await tester.pumpWidget(app(DaftarKolektorScreen(onBack: () {}, onContinue: () {}, onLoginTap: () {})));
      await isiDaftar(tester, pw: 'Rahasia123', pw2: 'Rahasia124');
      await tester.tap(find.text('Lanjutkan Pendaftaran'));
      await tester.pump();
      expect(find.text('Konfirmasi kata sandi belum sama.'), findsOneWidget);
      expect(log, isEmpty);
    });

    testWidgets('daftar kolektor: data benar -> mendaftar sebagai kolektor lalu lanjut', (tester) async {
      final (svc, _, log) = _buat((r) async => _json(_pair(), 201));
      AuthService.instance = svc;
      var lanjut = false;
      await tester.pumpWidget(app(DaftarKolektorScreen(onBack: () {}, onContinue: () => lanjut = true, onLoginTap: () {})));
      await isiDaftar(tester, pw: 'Rahasia123');
      await tester.tap(find.text('Lanjutkan Pendaftaran'));
      await tester.pumpAndSettle();
      expect(log.single.path, '/api/auth/register');
      expect(log.single.body['role'], 'kolektor');
      expect(log.single.body['display_name'], 'Ayu Lestari');
      expect(lanjut, isTrue);
    });

    testWidgets('daftar kolektor: email sudah terdaftar -> pesan server, tidak lanjut', (tester) async {
      final (svc, _, _) = _buat((r) async => _json({'detail': 'Email ini sudah terdaftar. Coba masuk, atau pakai email lain.'}, 409));
      AuthService.instance = svc;
      var lanjut = false;
      await tester.pumpWidget(app(DaftarKolektorScreen(onBack: () {}, onContinue: () => lanjut = true, onLoginTap: () {})));
      await isiDaftar(tester, pw: 'Rahasia123');
      await tester.tap(find.text('Lanjutkan Pendaftaran'));
      await tester.pumpAndSettle();
      expect(find.textContaining('sudah terdaftar'), findsOneWidget);
      expect(lanjut, isFalse);
    });
  });
}
