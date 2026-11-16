import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// Lupa password lewat kode 6 digit yang dikirim ke email (`POST /api/auth/lupa-password` lalu
/// `POST /api/auth/reset-password`).
///
/// Langkah 1: masukkan email -> server mengirim kode (jawabannya SELALU sama, terdaftar atau tidak, supaya layar ini
/// tidak bisa dipakai menebak email mana yang punya akun). Langkah 2: kode + password baru. Berhasil -> semua sesi login
/// lama dicabut di server, pengguna kembali ke layar masuk.
class LupaPasswordScreen extends StatefulWidget {
  const LupaPasswordScreen({super.key, required this.onBack, required this.onSelesai, AuthService? service})
      : _service = service;

  final VoidCallback onBack;

  /// Dipanggil setelah password berhasil diubah (biasanya: kembali ke layar masuk).
  final VoidCallback onSelesai;
  final AuthService? _service;

  @override
  State<LupaPasswordScreen> createState() => _LupaPasswordScreenState();
}

class _LupaPasswordScreenState extends State<LupaPasswordScreen> {
  static const _jedaKirimUlang = 60;
  static const _kopi = Color(0xFF3E251E);

  late final AuthService _auth = widget._service ?? AuthService.instance;
  final _email = TextEditingController();
  final _kode = TextEditingController();
  final _passwordBaru = TextEditingController();
  final _konfirmasi = TextEditingController();

  int _langkah = 0; // 0 = isi email, 1 = isi kode + password baru
  bool _kirim = false;
  bool _lihat = false;
  String? _error;
  String? _info;
  int _sisaJeda = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _kode.dispose();
    _passwordBaru.dispose();
    _konfirmasi.dispose();
    super.dispose();
  }

  bool get _emailValid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  void _mulaiJeda() {
    _timer?.cancel();
    setState(() => _sisaJeda = _jedaKirimUlang);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _sisaJeda = (_sisaJeda - 1).clamp(0, _jedaKirimUlang));
      if (_sisaJeda == 0) t.cancel();
    });
  }

  Future<void> _kirimKode({bool ulang = false}) async {
    if (!_emailValid) {
      setState(() => _error = 'Masukkan alamat email yang valid.');
      return;
    }
    setState(() {
      _kirim = true;
      _error = null;
      _info = null;
    });
    try {
      final pesan = await _auth.lupaPassword(_email.text);
      if (!mounted) return;
      setState(() {
        _langkah = 1;
        _info = ulang ? 'Kode baru dikirim. $pesan' : pesan;
      });
      _mulaiJeda();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _kirim = false);
    }
  }

  String? _validasiPassword() {
    final p = _passwordBaru.text;
    if (!RegExp(r'^\d{6}$').hasMatch(_kode.text.trim())) return 'Kode harus 6 digit angka.';
    if (p.length < 8) return 'Password minimal 8 karakter.';
    if (!(RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p))) return 'Password harus mengandung huruf dan angka.';
    if (p != _konfirmasi.text) return 'Konfirmasi password tidak sama.';
    return null;
  }

  Future<void> _ubah() async {
    final salah = _validasiPassword();
    if (salah != null) {
      setState(() => _error = salah);
      return;
    }
    setState(() {
      _kirim = true;
      _error = null;
    });
    try {
      final pesan = await _auth.resetPassword(email: _email.text, kode: _kode.text.trim(), passwordBaru: _passwordBaru.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
      widget.onSelesai();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _kirim = false);
    }
  }

  InputDecoration _dekor(String label, {String? hint, Widget? suffix, IconData? ikon}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: ikon == null ? null : Icon(ikon, size: 20, color: AppColors.outline),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: _kopi, width: 1.6)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Lupa Password', style: AppTextStyles.headlineSm),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFF7E7C1).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(children: [
                const Icon(Icons.lock_reset, size: 34, color: _kopi),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _langkah == 0
                        ? 'Masukkan email akunmu. Kami kirim kode 6 digit untuk membuat password baru.'
                        : 'Masukkan kode yang dikirim ke ${_email.text.trim()}, lalu buat password baru.',
                    style: AppTextStyles.bodySm.copyWith(color: _kopi),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('lupa_email'),
              controller: _email,
              enabled: !_kirim && _langkah == 0,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _langkah == 0 ? _kirimKode() : null,
              decoration: _dekor('Email', hint: 'nama@email.com', ikon: Icons.mail_outline),
            ),
            if (_langkah == 1) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('kode_reset'),
                controller: _kode,
                enabled: !_kirim,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w800),
                decoration: _dekor('Kode 6 digit', hint: '••••••', ikon: Icons.pin_outlined),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('password_baru'),
                controller: _passwordBaru,
                enabled: !_kirim,
                obscureText: !_lihat,
                decoration: _dekor(
                  'Password baru',
                  hint: 'Minimal 8 karakter, huruf dan angka',
                  ikon: Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(_lihat ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.outline),
                    onPressed: () => setState(() => _lihat = !_lihat),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('password_konfirmasi'),
                controller: _konfirmasi,
                enabled: !_kirim,
                obscureText: !_lihat,
                onSubmitted: (_) => _ubah(),
                decoration: _dekor('Ulangi password baru', ikon: Icons.lock_outline),
              ),
            ],
            if (_info != null && _error == null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_info!, key: const Key('lupa_info'), style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                key: const Key('lupa_error'),
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error))),
                ]),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 50,
              child: FilledButton(
                key: Key(_langkah == 0 ? 'kirim_kode' : 'ubah_password'),
                onPressed: _kirim ? null : (_langkah == 0 ? () => _kirimKode() : _ubah),
                style: FilledButton.styleFrom(backgroundColor: _kopi, foregroundColor: Colors.white),
                child: _kirim
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_langkah == 0 ? 'Kirim Kode' : 'Ubah Password', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            if (_langkah == 1) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(
                  onPressed: _kirim ? null : () => setState(() {
                        _langkah = 0;
                        _error = null;
                        _info = null;
                        _kode.clear();
                      }),
                  child: const Text('Ganti email'),
                ),
                TextButton(
                  key: const Key('kirim_ulang'),
                  onPressed: (_kirim || _sisaJeda > 0) ? null : () => _kirimKode(ulang: true),
                  child: Text(_sisaJeda > 0 ? 'Kirim ulang ($_sisaJeda dtk)' : 'Kirim ulang kode'),
                ),
              ]),
              Text(
                'Kode berlaku 15 menit. Tidak menerima email? Periksa folder spam.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
