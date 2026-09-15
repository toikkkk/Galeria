import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Konversi dari docs/design/role_seniman_1/.../galeria_splash_screen/code.html
///
/// TODO(asset): ganti [Icons.auto_awesome] dengan logo GALERIA asli
/// (di HTML sumber masih pakai URL gambar sementara dari Google).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  /// Dipanggil setelah splash selesai (progress bar penuh) -- biasanya
  /// dipakai utk pindah ke welcome screen lewat router.
  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.12;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Simulasi loading bar seperti di source HTML (increment acak tiap 450ms).
    _timer = Timer.periodic(const Duration(milliseconds: 450), (timer) {
      setState(() {
        final increment = 8 + (DateTime.now().millisecond % 18);
        _progress = (_progress + increment / 100).clamp(0.0, 0.96);
      });
      if (_progress >= 0.96) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 400), widget.onFinished);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenGutter,
                vertical: AppSpacing.xxl,
              ),
              child: Column(
                children: [
                  // Top bar
                  Opacity(
                    opacity: 0.6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('KATALOG RESMI', style: AppTextStyles.overline),
                        const Icon(Icons.verified,
                            color: AppColors.accent, size: 16),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Center logo + title
                  Column(
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent.withValues(alpha: 0.05),
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: AppColors.accent, size: 56),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'G A L E R I A',
                        style: AppTextStyles.displayLg.copyWith(
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        width: 32,
                        height: 2,
                        color: AppColors.accent.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'AUTENTIKASI & PERDAGANGAN KARYA SENI',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelSm.copyWith(
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text('KOLEKSI TERVERIFIKASI',
                                style: AppTextStyles.labelSm
                                    .copyWith(fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Bottom progress + info
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: SizedBox(
                          width: 144,
                          height: 2,
                          child: LinearProgressIndicator(
                            value: _progress,
                            backgroundColor: AppColors.surfaceContainerHighest,
                            valueColor: const AlwaysStoppedAnimation(
                                AppColors.accent),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('EDISI TERKURASI',
                              style: AppTextStyles.overline
                                  .copyWith(color: AppColors.outline)),
                          _dotSeparator(),
                          Text('JAKARTA • PARIS',
                              style: AppTextStyles.overline
                                  .copyWith(color: AppColors.outline)),
                          _dotSeparator(),
                          Text('V1.0',
                              style: AppTextStyles.overline
                                  .copyWith(color: AppColors.outline)),
                        ],
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

  Widget _dotSeparator() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          width: 3,
          height: 3,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.outlineVariant,
          ),
        ),
      );
}
