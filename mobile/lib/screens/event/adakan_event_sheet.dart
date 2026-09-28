import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_2/.../galeria_adakan_event_pameranmu_bottom_sheet_pro/code.html
///
/// Bottom sheet upsell "Seniman PRO" -- dipanggil dari tombol "Buat Event" di
/// DashboardScreen. `onUpgrade` untuk sekarang cuma placeholder (belum ada
/// alur pembayaran subscription).
Future<void> showAdakanEventSheet(
  BuildContext context, {
  required VoidCallback onUpgrade,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AdakanEventSheet(onUpgrade: onUpgrade),
  );
}

class _AdakanEventSheet extends StatelessWidget {
  const _AdakanEventSheet({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter, AppSpacing.xs,
            AppSpacing.screenGutter, AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle + close
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainer,
                      foregroundColor: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Icon badge
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accentSoft.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_available, color: AppColors.accent, size: 26),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Adakan Event & Pameranmu',
                textAlign: TextAlign.center, style: AppTextStyles.headlineLg),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                children: const [
                  TextSpan(text: 'Fitur ini tersedia untuk '),
                  TextSpan(
                    text: 'Seniman PRO',
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            // Benefit list
            Column(
              children: const [
                _BenefitRow('Buat pameran, lelang privat, dan workshop'),
                _BenefitRow('Jual tiket dengan pembayaran terintegrasi'),
                _BenefitRow('Tampil di halaman Event kolektor'),
                _BenefitRow('Undang komunitas dan pengikutmu sekaligus'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // PRO plan card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.cardInner),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text('SENIMAN PRO',
                            style: AppTextStyles.overline.copyWith(color: AppColors.accent)),
                      ),
                      Text('LANGGANAN BULANAN',
                          style: AppTextStyles.labelSm.copyWith(color: AppColors.muted)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('Rp 149.000',
                          style: AppTextStyles.headlineLg.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Text('/ bulan',
                          style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.verified_user, size: 14, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Batalkan kapan saja · Garansi kurasi 14 hari',
                            style: AppTextStyles.bodySm),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onUpgrade();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Upgrade ke PRO'),
                  SizedBox(width: AppSpacing.xs),
                  Icon(Icons.arrow_forward, size: 16, color: AppColors.accentSoft),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Nanti Saja',
                  style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 13, color: AppColors.accent, weight: 700),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.bodyMd)),
        ],
      ),
    );
  }
}
