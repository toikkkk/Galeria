import 'package:flutter/material.dart';

import '../../models/karya.dart';
import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_1/.../galeria_layar_sambutan_welcome_screen/code.html
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onLoginTap,
    required this.onRegisterTap,
    required this.onGuestTap,
  });

  final VoidCallback onLoginTap;
  final VoidCallback onRegisterTap;
  final VoidCallback onGuestTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Top ~62% -- collage + headline overlay
          Expanded(
            flex: 62,
            child: _CollageSection(),
          ),
          // Bottom card -- CTA buttons
          Expanded(
            flex: 38,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.lg,
                AppSpacing.screenGutter,
                AppSpacing.xl,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: onLoginTap,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('Masuk'),
                            SizedBox(width: AppSpacing.xs),
                            Icon(Icons.arrow_forward,
                                size: 16, color: AppColors.accent),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: onRegisterTap,
                        child: const Text('Daftar'),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      TextButton(
                        onPressed: onGuestTap,
                        child: Text(
                          'Lanjut sebagai tamu',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('KEASLIAN TERJAMIN',
                              style: AppTextStyles.overline
                                  .copyWith(fontSize: 11)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: CircleAvatar(
                                radius: 2, backgroundColor: AppColors.accent),
                          ),
                          Text('SERTIFIKAT DIGITAL',
                              style: AppTextStyles.overline
                                  .copyWith(fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollageSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF151413),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Collage grid
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 48, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 7,
                  child: _artImage(sampleKarya[3].assetPath), // Rembrandt
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      Expanded(child: _artImage(sampleKarya[0].assetPath)), // Renoir
                      const SizedBox(height: 10),
                      Expanded(child: _artImage(sampleKarya[4].assetPath)), // Picasso
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom gradient
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 260,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF121110),
                    const Color(0xFF121110).withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          // Top bar badges
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text('GALERIA',
                      style: AppTextStyles.overline.copyWith(
                          color: AppColors.surface, letterSpacing: 2)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border:
                        Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                          radius: 3, backgroundColor: AppColors.accent),
                      const SizedBox(width: 6),
                      Text('KURASI ASLI',
                          style: AppTextStyles.overline
                              .copyWith(color: AppColors.accentSoft)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Headline
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 32, height: 2, color: AppColors.accent),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Temukan dan miliki\nkarya seni asli',
                  style: AppTextStyles.displayMd.copyWith(
                    color: AppColors.surface,
                    fontSize: 30,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Akses eksklusif lelang dan koleksi terverifikasi dari galeri terkemuka.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: const Color(0xFFDBD6CE),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _artImage(String assetPath) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
}
