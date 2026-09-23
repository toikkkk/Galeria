import 'package:flutter/material.dart';

import '../../../models/lelang.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kolektor/kolektor_bottom_nav.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR UTAMA/.../galeria_lelang_karya/code.html
///
/// Data lot & countdown di sini contoh (placeholder) -- lihat models/lelang.dart.
class LelangScreen extends StatefulWidget {
  const LelangScreen({
    super.key,
    required this.onBack,
    this.onNavTap,
    this.onPindai,
    this.onDetailTap,
  });

  final VoidCallback onBack;
  final ValueChanged<int>? onNavTap;
  final VoidCallback? onPindai;
  final ValueChanged<LelangLot>? onDetailTap;

  @override
  State<LelangScreen> createState() => _LelangScreenState();
}

class _LelangScreenState extends State<LelangScreen> {
  int _filter = 0; // 0=semua, 1=berlangsung, 2=segera, 3=selesai

  @override
  Widget build(BuildContext context) {
    final filtered = sampleLelang.where((l) {
      switch (_filter) {
        case 1:
          return l.status == StatusLelang.berlangsung;
        case 2:
          return l.status == StatusLelang.segeraDimulai;
        case 3:
          return l.status == StatusLelang.selesai;
        default:
          return true;
      }
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Lelang Karya', style: AppTextStyles.headlineMd),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.help_outline)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.tune)),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenGutter,
                vertical: AppSpacing.xs,
              ),
              itemCount: 4,
              separatorBuilder: (context, i) =>
                  const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, i) {
                const labels = [
                  'Semua Lot',
                  'Berlangsung',
                  'Segera Dimulai',
                  'Selesai',
                ];
                final active = i == _filter;
                return ChoiceChip(
                  label: Text(labels[i]),
                  selected: active,
                  onSelected: (_) => setState(() => _filter = i),
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  labelStyle: AppTextStyles.labelMd.copyWith(
                    color: active ? Colors.white : AppColors.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: active ? AppColors.primary : AppColors.border,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada lot pada kategori ini',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenGutter,
                      AppSpacing.sm,
                      AppSpacing.screenGutter,
                      AppSpacing.lg,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (context, i) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, i) => _LotCard(
                      lot: filtered[i],
                      onTap: () => widget.onDetailTap?.call(filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: KolektorBottomNav(
        currentIndex: 1,
        onTap: (i) => widget.onNavTap?.call(i),
        onPindai: widget.onPindai ?? () {},
      ),
    );
  }
}

class _LotCard extends StatelessWidget {
  const _LotCard({required this.lot, this.onTap});

  final LelangLot lot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final live = lot.status == StatusLelang.berlangsung;
    final soon = lot.status == StatusLelang.segeraDimulai;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.asset(lot.karya.assetPath, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _pill('LOT #${lot.lotNumber}', bg: Colors.white),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: live
                      ? _pill(
                          'Berakhir ${lot.countdownFormatted}',
                          bg: AppColors.errorContainer,
                          fg: AppColors.error,
                          icon: Icons.schedule,
                        )
                      : soon
                      ? _pill(
                          'Segera Dimulai',
                          bg: AppColors.accentSoft,
                          fg: AppColors.accent,
                          icon: Icons.schedule,
                        )
                      : _pill(
                          'Selesai',
                          bg: AppColors.surfaceContainerHighest,
                          fg: AppColors.muted,
                        ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified,
                        size: 13,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        lot.galleryName,
                        style: AppTextStyles.labelSm.copyWith(
                          color: Colors.white,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black87),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              lot.karya.title,
              style: AppTextStyles.headlineSm.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            Text(
              '${lot.karya.styleName} · Cat di atas kanvas',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          soon
                              ? 'ESTIMASI BUKA LELANG'
                              : 'TAWARAN TERTINGGI SAAT INI',
                          style: AppTextStyles.overline.copyWith(fontSize: 9),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          lot.currentBidFormatted,
                          style: AppTextStyles.headlineSm.copyWith(
                            fontSize: 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Ditaruh di baris terpisah (bukan sebaris dgn harga
                        // via Row) supaya tidak overflow horizontal saat
                        // harga + jumlah tawaran bersama lebih lebar dari
                        // ruang yang tersisa di sebelah tombol aksi.
                        if (!soon)
                          Text(
                            '${lot.bidCount} Tawaran',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.accent,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  if (!soon)
                    FilledButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.gavel, size: 15),
                      label: const Text('Pasang Bid'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(0, 38),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.notifications_active_outlined,
                        size: 15,
                        color: AppColors.accent,
                      ),
                      label: const Text('Ingatkan'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(
    String text, {
    required Color bg,
    Color fg = AppColors.onSurface,
    IconData? icon,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg.withValues(alpha: bg == Colors.white ? 0.95 : 1),
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
        ],
        Text(
          text,
          style: AppTextStyles.overline.copyWith(fontSize: 9, color: fg),
        ),
      ],
    ),
  );
}
