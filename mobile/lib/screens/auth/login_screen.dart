import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/galeria_logo.dart';
import '../onboarding/role_selection_screen.dart';
import '../../utils/coming_soon.dart';

/// Konversi dari
/// docs/design/role_seniman_1/.../galeria_layar_masuk_login_screen/code.html
///
/// Masuk memakai `POST /api/auth/login` (lihat [AuthService]). Peran (seniman/kolektor) ditentukan oleh AKUN di server,
/// bukan pilihan di layar ini -- toggle "Masuk sebagai" yang dulu dipakai saat belum ada auth sudah dihapus.
///
/// "Masuk dengan Google": backend sudah siap (`POST /api/auth/google`), tapi sisi aplikasi butuh `google_sign_in` +
/// Client ID + SHA-1 (lihat root CLAUDE.md), jadi tombolnya sementara "segera hadir" -- BUKAN lagi melewati login.
/// "Lupa password?" membuka [LupaPasswordScreen] (kode 6 digit lewat email) bila [onLupaPasswordTap] diisi.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onBack,
    required this.onLoginSuccess,
    required this.onRegisterTap,
    this.onLupaPasswordTap,
  });

  final VoidCallback onBack;
  final ValueChanged<UserRole> onLoginSuccess;
  final VoidCallback onRegisterTap;

  /// Membuka alur lupa password (kode lewat email). Tanpa ini tombolnya menampilkan "belum tersedia".
  final VoidCallback? onLupaPasswordTap;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _kirim = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Isi email dan kata sandi dulu.');
      return;
    }
    setState(() {
      _kirim = true;
      _error = null;
    });
    try {
      final user = await AuthService.instance.login(email, password);
      if (!mounted) return;
      widget.onLoginSuccess(user.isSeniman ? UserRole.seniman : UserRole.kolektor);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // Brand emblem
              Center(
                child: Column(
                  children: [
                    const GaleriaLogo(size: 88),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 1,
                          color: AppColors.border,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text('FINE ART AUCTION', style: AppTextStyles.overline),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          width: 24,
                          height: 1,
                          color: AppColors.border,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Masuk ke GALERIA',
                textAlign: TextAlign.center,
                style: AppTextStyles.displayMd,
              ),
              const SizedBox(height: 4),
              Text(
                'Masuk dengan akun yang sudah kamu daftarkan',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Form card
              Container(
                padding: const EdgeInsets.all(AppSpacing.cardInner),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Email', style: AppTextStyles.labelMd),
                        Text(
                          'Resmi',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _InputField(
                      controller: _emailCtrl,
                      icon: Icons.mail_outline,
                      hint: 'nama@domain.com',
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_kirim,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Kata Sandi', style: AppTextStyles.labelMd),
                    const SizedBox(height: 6),
                    _InputField(
                      controller: _passwordCtrl,
                      icon: Icons.lock_outline,
                      hint: 'Masukkan kata sandi',
                      enabled: !_kirim,
                      onSubmitted: (_) => _masuk(),
                      obscureText: _obscurePassword,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppColors.outline,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: widget.onLupaPasswordTap ?? () => showComingSoon(context, 'Lupa password?'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                        ),
                        child: Text(
                          'Lupa password?',
                          style: AppTextStyles.labelSm,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        key: const Key('login_error'),
                        padding: const EdgeInsets.all(AppSpacing.xs),
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
                              child: Text(
                                _error!,
                                style: AppTextStyles.bodySm.copyWith(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    ElevatedButton(
                      onPressed: _kirim ? null : _masuk,
                      child: _kirim
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('Masuk'),
                                SizedBox(width: AppSpacing.xs),
                                Icon(Icons.arrow_forward, size: 16),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      'atau',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: () => showComingSoon(context, 'Masuk dengan Google'),
                icon: const Icon(Icons.g_mobiledata, size: 24),
                label: const Text('Masuk dengan Google'),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Trust mini card
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.verified_user,
                        size: 20,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Autentisitas Terjamin',
                            style: AppTextStyles.headlineSm.copyWith(
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Setiap karya dikurasi oleh kurator independen',
                            style: AppTextStyles.bodySm.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '256-BIT',
                      style: AppTextStyles.overline.copyWith(
                        fontSize: 10,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Wrap(
                  children: [
                    Text(
                      'Belum punya akun? ',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onRegisterTap,
                      child: Text(
                        'Daftar',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.accent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
    this.enabled = true,
    this.onSubmitted,
  });

  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.outline),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              onSubmitted: onSubmitted,
              obscureText: obscureText,
              keyboardType: keyboardType,
              style: AppTextStyles.bodyMd,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.outline,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          ?suffix,
        ],
      ),
    );
  }
}
