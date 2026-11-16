import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// Verifikasi email dengan kode 6 digit (`POST /api/auth/kirim-verifikasi` dan `POST /api/auth/verifikasi-email`).
/// Kode pertama sudah dikirim saat pendaftaran; layar ini juga bisa meminta kode baru.
class VerifikasiEmailScreen extends StatefulWidget {
  const VerifikasiEmailScreen({super.key, required this.onBack, required this.onSelesai, AuthService? service})
      : _service = service;

  final VoidCallback onBack;

  /// Dipanggil setelah email berhasil diverifikasi.
  final VoidCallback onSelesai;
  final AuthService? _service;

  @override
  State<VerifikasiEmailScreen> createState() => _VerifikasiEmailScreenState();
}

class _VerifikasiEmailScreenState extends State<VerifikasiEmailScreen> {
  static const _kopi = Color(0xFF3E251E);
  static const _jeda = 60;

  late final AuthService _auth = widget._service ?? AuthService.instance;
  final _kode = TextEditingController();
  bool _kirim = false;
  bool _meminta = false;
  String? _error;
  String? _info;
  int _sisaJeda = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _kode.dispose();
    super.dispose();
  }

  void _mulaiJeda() {
    _timer?.cancel();
    setState(() => _sisaJeda = _jeda);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _sisaJeda = (_sisaJeda - 1).clamp(0, _jeda));
      if (_sisaJeda == 0) t.cancel();
    });
  }

  Future<void> _mintaKode() async {
    setState(() {
      _meminta = true;
      _error = null;
      _info = null;
    });
    try {
      final hasil = await _auth.kirimVerifikasi();
      if (!mounted) return;
      if (hasil.sudah) {
        widget.onSelesai();
        return;
      }
      setState(() => _info = hasil.pesan);
      _mulaiJeda();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _meminta = false);
    }
  }

  Future<void> _verifikasi() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_kode.text.trim())) {
      setState(() => _error = 'Kode harus 6 digit angka.');
      return;
    }
    setState(() {
      _kirim = true;
      _error = null;
    });
    try {
      await _auth.verifikasiEmail(_kode.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email berhasil diverifikasi.')));
      widget.onSelesai();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _kirim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.user?.email ?? '';
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Verifikasi Email', style: AppTextStyles.headlineSm),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: const Color(0xFFF7E7C1).withValues(alpha: 0.6), borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Row(children: [
                const Icon(Icons.mark_email_read_outlined, size: 34, color: _kopi),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Masukkan kode 6 digit yang dikirim ke $email. Ini membuktikan email itu milikmu dan membantumu memulihkan akun.',
                    style: AppTextStyles.bodySm.copyWith(color: _kopi),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('kode_verifikasi'),
              controller: _kode,
              enabled: !_kirim,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              onSubmitted: (_) => _verifikasi(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: '••••••',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: _kopi, width: 1.6)),
              ),
            ),
            if (_info != null && _error == null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_info!, key: const Key('verif_info'), style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                key: const Key('verif_error'),
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
                key: const Key('verifikasi_tombol'),
                onPressed: _kirim ? null : _verifikasi,
                style: FilledButton.styleFrom(backgroundColor: _kopi, foregroundColor: Colors.white),
                child: _kirim
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Verifikasi', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Center(
              child: TextButton(
                key: const Key('kirim_ulang_verifikasi'),
                onPressed: (_meminta || _kirim || _sisaJeda > 0) ? null : _mintaKode,
                child: Text(_sisaJeda > 0 ? 'Kirim ulang ($_sisaJeda dtk)' : 'Kirim ulang kode'),
              ),
            ),
            Text(
              'Kode berlaku 15 menit. Tidak menerima email? Periksa folder spam.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
