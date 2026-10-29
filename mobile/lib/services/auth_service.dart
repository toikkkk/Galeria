import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

/// Pengguna yang sedang masuk (cermin `UserOut` di `backend/schemas/auth.py`).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    this.emailVerified = false,
  });

  final String id, email, displayName, role;
  final String? avatarUrl;
  final bool emailVerified;

  bool get isSeniman => role == 'seniman';

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as String,
        email: j['email'] as String,
        displayName: j['display_name'] as String,
        role: j['role'] as String,
        avatarUrl: j['avatar_url'] as String?,
        emailVerified: j['email_verified'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'role': role,
        'avatar_url': avatarUrl,
        'email_verified': emailVerified,
      };
}

/// Error auth yang aman ditampilkan langsung ke pengguna (pesan sudah Bahasa Indonesia).
class AuthException implements Exception {
  AuthException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Penyimpanan token. Produksi = [SecureTokenStore] (Android Keystore); tes memakai versi memori.
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Token WAJIB di penyimpanan aman -- bukan SharedPreferences biasa (lihat root CLAUDE.md "Aturan Kejujuran Auth").
class SecureTokenStore implements TokenStore {
  const SecureTokenStore();
  static const _s = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

/// Sesi login: token disimpan aman, access token diperbarui otomatis memakai refresh token.
///
/// Refresh DIJALANKAN SATU-SATU: server memutar (rotasi) refresh token di setiap pemakaian dan menganggap pemakaian
/// token lama sebagai tanda pencurian (sesi dicabut). Dua refresh bersamaan dari satu aplikasi akan memicu itu, jadi
/// semua pemanggil berbagi satu proses refresh yang sedang berjalan.
class AuthService extends ChangeNotifier {
  AuthService({http.Client? client, TokenStore? store, String? baseUrl, DateTime Function()? sekarang})
      : _client = client ?? http.Client(),
        _store = store ?? const SecureTokenStore(),
        _base = baseUrl ?? kApiBaseUrl,
        _now = sekarang ?? DateTime.now;

  /// Instans bersama aplikasi. Dibuat bisa diganti (bukan `final`) hanya supaya tes bisa menyuntikkan HTTP/penyimpanan palsu.
  static AuthService instance = AuthService();

  static const _kRefresh = 'galeria_refresh_token';
  static const _kUser = 'galeria_user';
  static const _batasAman = Duration(seconds: 30);

  final http.Client _client;
  final TokenStore _store;
  final String _base;
  final DateTime Function() _now;

  AuthUser? _user;
  String? _access;
  DateTime? _accessExp;
  String? _refresh;
  Future<bool>? _sedangRefresh;

  /// `true` setelah server MENOLAK sesi tersimpan (dicabut/berakhir) -- UI memakainya untuk mengarahkan ke layar masuk.
  /// Kembali `false` begitu login/daftar berhasil. Tidak menyala saat offline atau logout biasa.
  final ValueNotifier<bool> sesiBerakhir = ValueNotifier(false);

  AuthUser? get user => _user;
  bool get loggedIn => _user != null && _refresh != null;

  /// Muat sesi tersimpan (cepat, tanpa jaringan). Validasi ke server terjadi lazily / lewat [validasiSesi].
  Future<void> restore() async {
    try {
      final refresh = await _store.read(_kRefresh);
      final userJson = await _store.read(_kUser);
      if (refresh == null || userJson == null) return;
      _user = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      _refresh = refresh;
    } catch (_) {
      await _bersihkan(); // data tersimpan rusak -> anggap belum login
    }
    notifyListeners();
  }

  /// Cek ke server bahwa sesi tersimpan masih berlaku. Tanpa koneksi, pengguna TETAP dianggap masuk
  /// (tidak ditendang hanya karena offline); sesi yang ditolak server (401) membersihkan login.
  Future<void> validasiSesi() async {
    if (!loggedIn) return;
    await _perbarui();
  }

  Future<AuthUser> login(String email, String password) =>
      _masuk('/api/auth/login', {'email': email.trim(), 'password': password});

  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) =>
      _masuk('/api/auth/register', {
        'email': email.trim(),
        'password': password,
        'display_name': displayName.trim(),
        'role': role,
      });

  /// Keluar. Pembersihan lokal SELALU terjadi, walau server tak terjangkau.
  Future<void> logout() async {
    final refresh = _refresh;
    await _bersihkan();
    notifyListeners();
    if (refresh == null) return;
    try {
      await _client
          .post(Uri.parse('$_base/api/auth/logout'),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode({'refresh_token': refresh}))
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // best-effort: sesi di server tetap kedaluwarsa sendiri (30 hari)
    }
  }

  /// Access token yang valid (diperbarui bila hampir habis). null = belum masuk / sesi sudah tidak berlaku.
  Future<String?> accessToken({bool paksaPerbarui = false}) async {
    if (!loggedIn) return null;
    final exp = _accessExp;
    final masihBaik = !paksaPerbarui && _access != null && exp != null && exp.difference(_now()) > _batasAman;
    if (masihBaik) return _access;
    await _perbarui();
    if (!loggedIn) return null;
    // refresh gagal karena offline: jangan kembalikan token yang sudah kedaluwarsa
    final habis = _accessExp;
    return (_access != null && habis != null && habis.isAfter(_now())) ? _access : null;
  }

  // ------------------------------------------------------------------ internal
  Future<AuthUser> _masuk(String path, Map<String, dynamic> body) async {
    final http.Response res;
    try {
      res = await _client
          .post(Uri.parse('$_base$path'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw AuthException('Tidak bisa terhubung ke server. Periksa koneksi internetmu lalu coba lagi.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthException(_pesanError(res), statusCode: res.statusCode);
    }
    await _terapkan(jsonDecode(res.body) as Map<String, dynamic>);
    return _user!;
  }

  Future<void> _terapkan(Map<String, dynamic> j) async {
    _user = AuthUser.fromJson(j['user'] as Map<String, dynamic>);
    _access = j['access_token'] as String;
    _accessExp = _now().add(Duration(seconds: j['expires_in'] as int));
    _refresh = j['refresh_token'] as String;
    await _store.write(_kRefresh, _refresh!);
    await _store.write(_kUser, jsonEncode(_user!.toJson()));
    sesiBerakhir.value = false;
    notifyListeners();
  }

  Future<bool> _perbarui() => _sedangRefresh ??= _jalankanPerbarui().whenComplete(() => _sedangRefresh = null);

  Future<bool> _jalankanPerbarui() async {
    final refresh = _refresh;
    if (refresh == null) return false;
    final http.Response res;
    try {
      res = await _client
          .post(Uri.parse('$_base/api/auth/refresh'),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode({'refresh_token': refresh}))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      return false; // offline/timeout: pertahankan login, coba lagi nanti
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await _terapkan(jsonDecode(res.body) as Map<String, dynamic>);
      return true;
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      await _bersihkan(); // sesi dicabut/berakhir -> keluar
      sesiBerakhir.value = true;
      notifyListeners();
    }
    return false;
  }

  Future<void> _bersihkan() async {
    _user = null;
    _access = null;
    _accessExp = null;
    _refresh = null;
    try {
      await _store.delete(_kRefresh);
      await _store.delete(_kUser);
    } catch (_) {}
  }

  /// Ambil pesan `detail` dari backend (string, atau daftar galat validasi 422) menjadi satu kalimat.
  static String _pesanError(http.Response res) {
    try {
      final d = (jsonDecode(res.body) as Map<String, dynamic>)['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty) {
        final msg = (d.first as Map)['msg']?.toString() ?? '';
        final bersih = msg.replaceFirst(RegExp(r'^Value error,\s*'), '');
        if (bersih.isNotEmpty) return bersih[0].toUpperCase() + bersih.substring(1);
      }
    } catch (_) {}
    if (res.statusCode >= 500) return 'Server sedang bermasalah. Coba lagi sebentar lagi.';
    return 'Permintaan ditolak (${res.statusCode}).';
  }
}
