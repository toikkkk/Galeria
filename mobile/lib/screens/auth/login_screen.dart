import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_1/.../galeria_layar_masuk_login_screen/code.html
///
/// TODO(backend): wire ke endpoint auth asli -- saat ini submit cuma
/// memanggil [onLoginSuccess] tanpa validasi kredensial nyata.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onBack,
    required this.onLoginSuccess,
    required this.onRegisterTap,
  });

  final VoidCallback onBack;
  final VoidCallback onLoginSuccess;
  final VoidCallback onRegisterTap;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter, vertical: AppSpacing.sm),
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
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: AppColors.accent, size: 32),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 24, height: 1, color: AppColors.border),
                        const SizedBox(width: AppSpacing.xs),
                        Text('FINE ART AUCTION', style: AppTextStyles.overline),
                        const SizedBox(width: AppSpacing.xs),
                        Container(width: 24, height: 1, color: AppColors.border),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Masuk ke GALERIA',
                  textAlign: TextAlign.center, style: AppTextStyles.displayMd),
              const SizedBox(height: 4),
              Text('Satu akun untuk kolektor dan seniman',
                  textAlign: TextAlign.center,
                  style:
                      AppTextStyles.bodyMd.copyWith(color: AppColors.muted)),
              const SizedBox(height: AppSpacing.xl),
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
                        Text('Resmi',
                            style: AppTextStyles.bodySm
                                .copyWith(color: AppColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _InputField(
                      controller: _emailCtrl,
                      icon: Icons.mail_outline,
                      hint: 'nama@domain.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Kata Sandi', style: AppTextStyles.labelMd),
                    const SizedBox(height: 6),
                    _InputField(
                      controller: _passwordCtrl,
                      icon: Icons.lock_outline,
                      hint: 'Masukkan kata sandi',
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
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32)),
                        child: Text('Lupa password?',
                            style: AppTextStyles.labelSm),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ElevatedButton(
                      onPressed: widget.onLoginSuccess,
                      child: Row(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text('atau',
                        style: AppTextStyles.bodySm
                            .copyWith(color: AppColors.muted)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: widget.onLoginSuccess,
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
                      child: const Icon(Icons.verified_user,
                          size: 20, color: AppColors.accent),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Autentisitas Terjamin',
                              style: AppTextStyles.headlineSm
                                  .copyWith(fontSize: 15)),
                          Text('Setiap karya dikurasi oleh kurator independen',
                              style: AppTextStyles.bodySm
                                  .copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                    Text('256-BIT',
                        style: AppTextStyles.overline.copyWith(
                            fontSize: 10, color: AppColors.accent)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Wrap(
                  children: [
                    Text('Belum punya akun? ',
                        style: AppTextStyles.bodyMd
                            .copyWith(color: AppColors.muted)),
                    GestureDetector(
                      onTap: widget.onRegisterTap,
                      child: Text('Daftar',
                          style: AppTextStyles.labelMd.copyWith(
                            color: AppColors.accent,
                            decoration: TextDecoration.underline,
                          )),
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
  });

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
              obscureText: obscureText,
              keyboardType: keyboardType,
              style: AppTextStyles.bodyMd,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.outline),
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
