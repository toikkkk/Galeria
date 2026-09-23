import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR UTAMA/.../galeria_buat_akun_kolektor/code.html
/// (Langkah 1 dari 2 -- lanjut ke PreferensiGenreScreen)
///
/// TODO(backend): wire form ke endpoint registrasi asli -- saat ini submit
/// cuma memanggil [onContinue] tanpa validasi kredensial nyata.
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
                      label: 'Nama Lengkap Sesuai Identitas',
                      hint: 'Nama lengkap',
                      trailingIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _FormField(
                      label: 'Nomor Telepon Seluler',
                      hint: '812 3456 7890',
                      prefix: '+62',
                      trailingIcon: Icons.check,
                      trailingColor: AppColors.accent,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _FormField(
                      label: 'Alamat Surel Kolektor',
                      hint: 'kolektor@galeria.art',
                      trailingIcon: Icons.mail_outline,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PasswordField(
                      label: 'Kata Sandi Akun',
                      obscure: _obscurePassword,
                      onToggle: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      showStrength: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PasswordField(
                      label: 'Konfirmasi Kata Sandi',
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      matched: true,
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
                  ElevatedButton(
                    onPressed: _agree ? widget.onContinue : null,
                    child: Row(
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
  });

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
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.showStrength = false,
    this.matched = false,
  });

  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final bool showStrength;
  final bool matched;

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
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 3,
                      backgroundColor: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sangat Kuat',
                      style: AppTextStyles.bodySm.copyWith(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
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
              if (matched)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.check, size: 16, color: AppColors.accent),
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
            Row(
              children: [
                for (int i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
