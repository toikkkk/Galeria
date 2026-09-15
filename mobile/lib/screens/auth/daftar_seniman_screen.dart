import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_1/.../galeria_daftar_sebagai_seniman/code.html
/// (Langkah 1/3 pendaftaran seniman -- lanjut ke VerifikasiIdentitasScreen)
///
/// TODO(backend): wire form ke endpoint registrasi asli + validasi kekuatan
/// password nyata (saat ini strength meter statis, bukan dihitung live).
class DaftarSenimanScreen extends StatefulWidget {
  const DaftarSenimanScreen({
    super.key,
    required this.onBack,
    required this.onContinue,
    required this.onLoginTap,
  });

  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onLoginTap;

  @override
  State<DaftarSenimanScreen> createState() => _DaftarSenimanScreenState();
}

class _DaftarSenimanScreenState extends State<DaftarSenimanScreen> {
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter,
                  AppSpacing.xs, AppSpacing.screenGutter, AppSpacing.xs),
              child: Row(
                children: [
                  IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(radius: 3, backgroundColor: AppColors.accent),
                        const SizedBox(width: 6),
                        Text('KOLEKTIF SENIMAN',
                            style: AppTextStyles.overline.copyWith(fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenGutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LANGKAH 1/3',
                                style: AppTextStyles.overline
                                    .copyWith(color: AppColors.accent)),
                            Text('Data Diri', style: AppTextStyles.labelMd),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          children: [
                            Text('LANGKAH 2',
                                style: AppTextStyles.overline
                                    .copyWith(color: AppColors.muted)),
                            Text('Verifikasi',
                                style: AppTextStyles.labelSm
                                    .copyWith(color: AppColors.muted)),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('LANGKAH 3',
                                style: AppTextStyles.overline
                                    .copyWith(color: AppColors.muted)),
                            Text('Galeri',
                                style: AppTextStyles.labelSm
                                    .copyWith(color: AppColors.muted)),
                          ],
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
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.full)))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                    color: AppColors.border,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.full)))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                    color: AppColors.border,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.full)))),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Daftar sebagai Seniman',
                        style: AppTextStyles.displayMd.copyWith(fontSize: 32)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Buka akses salon kurasi dan pamerkan portofolio karya seni Anda ke jaringan kolektor global.',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F4EA),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: Color(0xFFB89218)),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'Data identitas dipakai hanya untuk verifikasi dan tidak ditampilkan ke publik.',
                              style: AppTextStyles.bodySm.copyWith(
                                  fontSize: 11.5, color: const Color(0xFF635118)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FormField(
                      label: 'Nama Lengkap (sesuai KTP)',
                      hint: 'Masukkan nama lengkap',
                      trailingIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _FormField(
                      label: 'Nomor HP',
                      hint: '812 3456 7890',
                      prefix: '+62',
                      trailingIcon: Icons.check,
                      trailingColor: AppColors.accent,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _FormField(
                      label: 'Alamat Email',
                      hint: 'nama@domain.com',
                      trailingIcon: Icons.mail_outline,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PasswordField(
                      label: 'Password',
                      obscure: _obscurePassword,
                      onToggle: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      showStrength: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PasswordField(
                      label: 'Konfirmasi Password',
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      matched: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline,
                            size: 14, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text('Enkripsi 256-bit standar asosiasi kurasi seni',
                            style: AppTextStyles.bodySm
                                .copyWith(color: AppColors.muted)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter,
                  AppSpacing.sm, AppSpacing.screenGutter, AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: widget.onContinue,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('Lanjut'),
                        SizedBox(width: AppSpacing.xs),
                        Icon(Icons.arrow_forward, size: 16, color: AppColors.accent),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text('Sudah memiliki akun seniman? ',
                          style: AppTextStyles.bodySm
                              .copyWith(color: AppColors.muted)),
                      GestureDetector(
                        onTap: widget.onLoginTap,
                        child: Text('Masuk Salon',
                            style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.onSurface,
                                decoration: TextDecoration.underline)),
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
  });

  final String label;
  final String hint;
  final String? prefix;
  final IconData? trailingIcon;
  final Color trailingColor;

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
          Text(label.toUpperCase(),
              style: AppTextStyles.overline.copyWith(fontSize: 10.5)),
          const SizedBox(height: 4),
          Row(
            children: [
              if (prefix != null) ...[
                Text(prefix!,
                    style: AppTextStyles.bodyMd
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(width: 1, height: 16, color: AppColors.border),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
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
              Text(label.toUpperCase(),
                  style: AppTextStyles.overline.copyWith(fontSize: 10.5)),
              if (showStrength)
                Row(
                  children: [
                    const CircleAvatar(radius: 3, backgroundColor: Colors.green),
                    const SizedBox(width: 4),
                    Text('Kuat',
                        style: AppTextStyles.bodySm.copyWith(
                            fontSize: 11,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600)),
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
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
                        color: i < 3 ? AppColors.accent : Colors.green,
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
