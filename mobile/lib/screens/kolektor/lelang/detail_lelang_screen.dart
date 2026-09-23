import 'package:flutter/material.dart';

import '../../../models/lelang.dart';
import '../../../theme/app_theme.dart';
import 'pasang_bid_sheet.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR UTAMA/.../galeria_detail_lelang_karya/code.html
///
/// Riwayat bid & statistik peserta di sini contoh (placeholder).
class DetailLelangScreen extends StatelessWidget {
  const DetailLelangScreen({
    super.key,
    required this.lot,
    required this.onBack,
  });

  final LelangLot lot;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Ajukan Tawaran', style: AppTextStyles.headlineSm),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter,
              vertical: AppSpacing.xs,
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: Image.asset(lot.karya.assetPath, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      'LOT NO. ${lot.lotNumber} · LELANG LANGSUNG',
                      style: AppTextStyles.overline.copyWith(
                        color: Colors.white,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
                if (lot.minutesRemaining != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Berakhir dalam ${lot.countdownFormatted}',
                              style: AppTextStyles.labelMd.copyWith(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'KARYA KURASI UNGGULAN',
                      style: AppTextStyles.overline.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        'Tersertifikasi Asli',
                        style: AppTextStyles.labelSm.copyWith(
                          fontSize: 10,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(lot.karya.title, style: AppTextStyles.headlineLg),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          lot.galleryName.substring(0, 2).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  lot.galleryName,
                                  style: AppTextStyles.labelMd,
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified,
                                  size: 14,
                                  color: AppColors.accent,
                                ),
                              ],
                            ),
                            Text(
                              'Kurator Terakreditasi',
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainerHighest,
                        ),
                        child: const Text('Ikuti'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BID TERTINGGI SAAT INI',
                              style: AppTextStyles.overline.copyWith(
                                fontSize: 9,
                                color: AppColors.accent,
                              ),
                            ),
                            Text(
                              lot.currentBidFormatted,
                              style: AppTextStyles.displayMd.copyWith(
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'HARGA AWAL',
                            style: AppTextStyles.overline.copyWith(fontSize: 9),
                          ),
                          Text(
                            'Rp ${(lot.currentBidIdr * 0.83).round().toString()}',
                            style: AppTextStyles.labelSm.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _statBlock(
                        Icons.groups_outlined,
                        '18 Kolektor',
                        'Peserta',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _statBlock(
                        Icons.gavel_outlined,
                        '${lot.bidCount} Tawaran',
                        'Total Bid',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _statBlock(
                        Icons.add_circle_outline,
                        'Rp 1jt',
                        'Kelipatan',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Riwayat Bid', style: AppTextStyles.headlineSm),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6),
                    ],
                  ),
                  child: Column(
                    children: [
                      _bidItem(
                        'rani_k***',
                        lot.currentBidFormatted,
                        '3 menit lalu',
                        leading: true,
                      ),
                      const Divider(height: 1),
                      _bidItem(
                        'budi_***7',
                        'Rp ${(lot.currentBidIdr - 1000000)}',
                        '8 menit lalu',
                      ),
                      const Divider(height: 1),
                      _bidItem(
                        'kartika_***',
                        'Rp ${(lot.currentBidIdr - 2500000)}',
                        '14 menit lalu',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      const Icon(
                        Icons.palette_outlined,
                        size: 18,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Detail Karya',
                        style: AppTextStyles.headlineSm.copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 3,
                      children: [
                        _detailField('Medium', 'Minyak pada Kanvas'),
                        _detailField('Aliran', lot.karya.styleName),
                        _detailField('Tahun', '2024'),
                        _detailField('Sertifikasi', 'Ledger GALERIA'),
                      ],
                    ),
                  ],
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      const Icon(
                        Icons.gavel_outlined,
                        size: 18,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Syarat & Ketentuan Lelang',
                        style: AppTextStyles.headlineSm.copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        '• Jaminan deposit aktif wajib sebelum bid pertama.\n'
                        '• Kelipatan tawaran minimum Rp 1.000.000.\n'
                        '• Pelunasan wajib 1×24 jam setelah lelang berakhir.',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
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
      bottomSheet: Container(
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
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(
                Icons.smart_toy_outlined,
                size: 18,
                color: AppColors.accent,
              ),
              label: const Text('Auto-Bid'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => showPasangBidSheet(context, lot),
                icon: const Icon(Icons.gavel, size: 18),
                label: const Text('Pasang Bid'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBlock(IconData icon, String value, String label) => Container(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Column(
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.overline.copyWith(fontSize: 8),
        ),
        const SizedBox(height: 2),
        Icon(icon, size: 16, color: AppColors.accent),
        Text(value, style: AppTextStyles.labelMd.copyWith(fontSize: 12)),
      ],
    ),
  );

  Widget _bidItem(
    String user,
    String amount,
    String time, {
    bool leading = false,
  }) => Container(
    color: leading ? AppColors.accentSoft.withValues(alpha: 0.25) : null,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.sm,
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: leading
              ? AppColors.primary
              : AppColors.surfaceContainerHighest,
          child: Text(
            user.substring(0, 2).toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: leading ? Colors.white : AppColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user, style: AppTextStyles.labelMd.copyWith(fontSize: 13)),
              Text(
                time,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Text(amount, style: AppTextStyles.labelMd.copyWith(fontSize: 13)),
      ],
    ),
  );

  Widget _detailField(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.overline.copyWith(fontSize: 8),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMd.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}
