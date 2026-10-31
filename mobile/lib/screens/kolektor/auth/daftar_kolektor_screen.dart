import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/password_strength.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR UTAMA/.../galeria_buat_akun_kolektor/code.html
/// (Langkah 1 dari 2 -- lanjut ke PreferensiGenreScreen)
///
/// Daftar memakai `POST /api/auth/register` (nama, email, password); kekuatan password dihitung langsung.
/// Catatan: "Nomor Telepon" dan "Alamat Pengiriman" belum dikirim -- tabel `users` belum punya kolomnya
/// (alamat kelak milik alur checkout/pengiriman).
class DaftarKolektorScreen extends StatefulWidget {
  const DaftarKolektorScreen({
    super.key,
    required this.onBack,
    required this.onContinue,
    required this.onLoginTap,
  });

  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onLoginTap;

  @override
  State<DaftarKolektorScreen> createState() => _DaftarKolektorScreenState();
}

class _DaftarKolektorScreenState extends State<DaftarKolektorScreen> {
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agree = true;
  final _namaCtrl = TextEditingController();
  final _hpCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  bool _kirim = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_namaCtrl, _hpCtrl, _emailCtrl, _pwCtrl, _pw2Ctrl]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Daftar lewat `POST /api/auth/register` (peran dikirim sesuai layar ini). Berhasil = langsung masuk
  /// (server menerbitkan token), lalu lanjut ke langkah berikutnya.
  Future<void> _daftar() async {
    final nama = _namaCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;
    String? err;
    if (nama.length < 2) {
      err = 'Isi nama lengkapmu dulu.';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      err = 'Format email belum benar.';
    } else if (_hpCtrl.text.trim().isNotEmpty && !RegExp(r'^\d{8,13}$').hasMatch(_hpCtrl.text.replaceAll(RegExp(r'[\s\-+]'), ''))) {
      err = 'Nomor telepon belum benar (8-13 digit).';
    } else if (validasiPassword(pw) != null) {
      err = validasiPassword(pw);
    } else if (pw != _pw2Ctrl.text) {
      err = 'Konfirmasi kata sandi belum sama.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _kirim = true;
      _error = null;
    });
    try {
      await AuthService.instance.register(email: email, password: pw, displayName: nama, role: 'kolektor', nomorHp: _hpCtrl.text);
      if (!mounted) return;
      widget.onContinue();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _kirim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.xs,
                AppSpacing.screenGutter,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 3,
                          backgroundColor: AppColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AKSES TERKURASI',
                          style: AppTextStyles.overline.copyWith(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenGutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Text(
                          'LANGKAH 1 DARI 2',
                          style: AppTextStyles.overline.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Data Pribadi',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Buat Akun Kolektor',
                      style: AppTextStyles.displayMd.copyWith(fontSize: 32),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Lengkapi data diri Anda untuk mengakses lelang karya seni eksklusif dan arsip kurasi salon.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _FormField(
                      controller: _namaCtrl,
                      label: 'Nama Lengkap Sesuai Identitas',
                      hint: 'Nama lengkap',
                      trailingIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _FormField(
                      controller: _hpCtrl,
                      keyboardType: TextInputType.phone,
                      label: 'Nomor Telepon Seluler',
                      hint: '812 3456 7890',
                      prefix: '+62',
                      trailingIcon: Icons.check,
                      trailingColor: AppColors.accent,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _FormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      label: 'Alamat Surel Kolektor',
                      hint: 'kolektor@galeria.art',
                      trailingIcon: Icons.mail_outline,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PasswordField(
                      controller: _pwCtrl,
                      label: 'Kata Sandi Akun',
                      obscure: _obscurePassword,
                      onToggle: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      showStrength: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PasswordField(
                      controller: _pw2Ctrl,
                      konfirmasiDari: _pwCtrl,
                      label: 'Konfirmasi Kata Sandi',
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _FormField(
                      label: 'Alamat Pengiriman & Korespondensi',
                      hint: 'Jl. ... , Kota, Provinsi',
                      trailingIcon: Icons.my_location,
                      trailingColor: AppColors.accent,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agree,
                          activeColor: AppColors.primary,
                          onChanged: (v) => setState(() => _agree = v ?? true),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text.rich(
                              TextSpan(
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.muted,
                                ),
                                children: const [
                                  TextSpan(text: 'Saya menyetujui '),
                                  TextSpan(
                                    text: 'Syarat & Ketentuan',
                                    style: TextStyle(
                                      color: AppColors.onSurface,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  TextSpan(text: ' dan '),
                                  TextSpan(
                                    text: 'Kebijakan Privasi',
                                    style: TextStyle(
                                      color: AppColors.onSurface,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  TextSpan(text: ' GALERIA.'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.sm,
                AppSpacing.screenGutter,
                AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null) ...[
                    Container(
                      key: const Key('daftar_error'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  ElevatedButton(
                    onPressed: (_agree && !_kirim) ? _daftar : null,
                    child: _kirim ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ) : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('Lanjutkan Pendaftaran'),
                        SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        'Sudah punya akun kolektor? ',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onLoginTap,
                        child: Text(
                          'Masuk',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.onSurface,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.hint,
    this.prefix,
    this.trailingIcon,
    this.trailingColor = AppColors.muted,
    this.maxLines = 1,
    this.controller,
    this.keyboardType,
  });

  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String label;
  final String hint;
  final String? prefix;
  final IconData? trailingIcon;
  final Color trailingColor;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.overline.copyWith(fontSize: 10.5),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (prefix != null) ...[
                Text(
                  prefix!,
                  style: AppTextStyles.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 16, color: AppColors.border),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: AppTextStyles.bodyMd,
                ),
              ),
              if (trailingIcon != null)
                Icon(trailingIcon, size: 16, color: trailingColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.showStrength = false,
    this.konfirmasiDari,
  });

  final TextEditingController controller;
  final TextEditingController? konfirmasiDari;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final bool showStrength;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.overline.copyWith(fontSize: 10.5),
              ),
              if (showStrength)
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final k = kekuatanPassword(controller.text);
                    if (k == 0) return const SizedBox.shrink();
                    final warna = _warnaKekuatan(k);
                    return Row(
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: warna),
                        const SizedBox(width: 4),
                        Text(
                          labelKekuatan[k],
                          style: AppTextStyles.bodySm.copyWith(
                            fontSize: 11,
                            color: warna,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  decoration: const InputDecoration(
                    hintText: '••••••••••••',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: AppTextStyles.bodyMd,
                ),
              ),
              if (konfirmasiDari != null)
                ListenableBuilder(
                  listenable: Listenable.merge([controller, konfirmasiDari!]),
                  builder: (context, _) {
                    final cocok = controller.text.isNotEmpty && controller.text == konfirmasiDari!.text;
                    return cocok
                        ? const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.check, size: 16, color: AppColors.accent),
                          )
                        : const SizedBox.shrink();
                  },
                ),
              GestureDetector(
                onTap: onToggle,
                child: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 16,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          if (showStrength) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final k = kekuatanPassword(controller.text);
                return Row(
                  children: [
                    for (int i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: i < k ? _warnaKekuatan(k) : AppColors.border,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

Color _warnaKekuatan(int k) => switch (k) {
      1 => AppColors.error,
      2 => Colors.orange.shade700,
      3 => AppColors.accent,
      _ => Colors.green.shade700,
    };
