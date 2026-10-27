import 'package:flutter/material.dart';

import '../state/studio_store.dart';
import '../theme/app_theme.dart';

/// Pastikan seniman sudah PRO sebelum memakai [fitur]. Kalau belum, tampilkan
/// pop up upgrade; mengembalikan true bila sekarang sudah PRO.
///
/// Upgrade di sini DEMO (belum ada alur pembayaran subscription nyata) --
/// tombol "Upgrade ke PRO" langsung mengaktifkan status PRO di
/// [StudioStore].
Future<bool> ensurePro(BuildContext context, {required String fitur}) async {
  final store = StudioStore.instance;
  if (store.isPro) return true;
  final upgraded = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProSheet(fitur: fitur),
  );
  if (upgraded == true) {
    store.upgradeKePro();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun kamu sekarang Seniman PRO (mode demo, tanpa pembayaran).'),
        ),
      );
    }
    return true;
  }
  return false;
}

class _ProSheet extends StatelessWidget {
  const _ProSheet({required this.fitur});

  final String fitur;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.xs,
          AppSpacing.screenGutter,
          AppSpacing.lg,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(Icons.workspace_premium, color: AppColors.accent),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text('Upgrade ke Seniman PRO', style: AppTextStyles.headlineMd),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$fitur adalah fitur Seniman PRO. Upgrade dulu untuk membuka fitur ini.',
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _Benefit('Melabeli & mempromosikan karya di beranda dan tab lelang'),
            const _Benefit('Membuat event pameran lengkap dengan tiket'),
            const _Benefit('Lencana PRO pada profil toko'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.accentSoft.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Text('Rp149.000', style: AppTextStyles.headlineMd),
                  Text(' / bulan', style: AppTextStyles.bodySm),
                  const Spacer(),
                  Text(
                    'Mode demo',
                    style: AppTextStyles.labelSm.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Upgrade ke PRO'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Nanti Saja',
                style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 18, color: AppColors.accent),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text, style: AppTextStyles.bodyMd)),
        ],
      ),
    );
  }
}
