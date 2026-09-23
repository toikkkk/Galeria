import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kolektor/karya_grid_card.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR PEMBELIAN PEMBAYARAN/.../galeria_profil_toko_seniman_.../code.html
class ProfilTokoScreen extends StatelessWidget {
  const ProfilTokoScreen({super.key, required this.onBack, this.onKaryaTap});

  final VoidCallback onBack;
  final ValueChanged<Karya>? onKaryaTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            leading: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/catalog/baroque_01.jpg',
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenGutter,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'SR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user,
                              size: 13,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Kurator Terakreditasi',
                              style: AppTextStyles.labelSm.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Sanggar Rupa Nusantara',
                    style: AppTextStyles.headlineLg,
                  ),
                  Text(
                    'Salon Utama · Jakarta Selatan',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kolektif kurasi karya seni rupa murni Indonesia era klasik hingga kontemporer, '
                    'bersertifikat dan provenansi teruji.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _stat('12', 'Karya Aktif')),
                        Container(
                          width: 1,
                          height: 32,
                          color: AppColors.border,
                        ),
                        Expanded(child: _stat('48', 'Terjual')),
                        Container(
                          width: 1,
                          height: 32,
                          color: AppColors.border,
                        ),
                        Expanded(child: _stat('1.240', 'Pengikut')),
                        Container(
                          width: 1,
                          height: 32,
                          color: AppColors.border,
                        ),
                        Expanded(child: _stat('4,9 ★', '128 Ulasan')),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: const [
                      _TrustBadge(
                        icon: Icons.check_circle,
                        label: 'Identitas Terverifikasi',
                      ),
                      _TrustBadge(
                        icon: Icons.shield_outlined,
                        label: 'Escrow Aman',
                      ),
                      _TrustBadge(
                        icon: Icons.inventory_2_outlined,
                        label: 'Peti Standar Museum',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Karya Tersedia', style: AppTextStyles.headlineSm),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.66,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => KaryaGridCard(
                  karya: sampleKarya[i],
                  overline: null,
                  onTap: () => onKaryaTap?.call(sampleKarya[i]),
                ),
                childCount: sampleKarya.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
    children: [
      Text(value, style: AppTextStyles.headlineSm.copyWith(fontSize: 16)),
      Text(
        label.toUpperCase(),
        style: AppTextStyles.overline.copyWith(fontSize: 7.5),
      ),
    ],
  );
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelSm.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
