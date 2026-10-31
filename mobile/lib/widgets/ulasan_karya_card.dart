import 'package:flutter/material.dart';

import '../models/ulasan_karya.dart';
import '../services/ulasan_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_waktu.dart';

/// "Ulasan Pembeli" sebuah karya: rata-rata bintang, sebaran, dan ulasan terbaru dari pembeli yang sudah
/// menerima karya ini. Disembunyikan bila gagal dimuat (mis. karya contoh yang tidak ada di database),
/// supaya halaman beli tidak dipenuhi pesan error.
class UlasanKaryaCard extends StatefulWidget {
  const UlasanKaryaCard({super.key, required this.karyaId, this.service});

  final String karyaId;
  final UlasanService? service;

  @override
  State<UlasanKaryaCard> createState() => _UlasanKaryaCardState();
}

class _UlasanKaryaCardState extends State<UlasanKaryaCard> {
  late final UlasanService _service = widget.service ?? UlasanService();
  UlasanKarya? _data;
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    if (widget.karyaId.isEmpty) {
      setState(() => _memuat = false);
      return;
    }
    try {
      final d = await _service.ulasanKarya(widget.karyaId);
      if (mounted) setState(() => _data = d);
    } catch (_) {
      // sembunyikan kartu
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (_memuat || d == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ulasan Pembeli', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.xs),
          if (d.jumlah == 0)
            Text(
              'Belum ada ulasan. Ulasan muncul setelah pembeli menerima karya ini.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
            )
          else ...[
            Row(
              children: [
                const Icon(Icons.star_rounded, color: AppColors.accent, size: 22),
                const SizedBox(width: 4),
                Text(d.rata2!.toStringAsFixed(1), style: AppTextStyles.headlineMd.copyWith(fontSize: 22)),
                const SizedBox(width: AppSpacing.xs),
                Text('dari ${d.jumlah} ulasan', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (var b = 5; b >= 1; b--)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    SizedBox(width: 14, child: Text('$b', style: AppTextStyles.bodySm.copyWith(fontSize: 11))),
                    const Icon(Icons.star_rounded, size: 11, color: AppColors.outline),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(
                          value: d.jumlah == 0 ? 0 : (d.sebaran['$b'] ?? 0) / d.jumlah,
                          minHeight: 6,
                          backgroundColor: AppColors.surfaceContainer,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    SizedBox(width: 26, child: Text('${d.sebaran['$b'] ?? 0}', textAlign: TextAlign.right, style: AppTextStyles.bodySm.copyWith(fontSize: 11))),
                  ],
                ),
              ),
            const Divider(height: AppSpacing.md),
            for (final u in d.items.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(u.nama, style: AppTextStyles.labelMd.copyWith(fontSize: 12)),
                        const SizedBox(width: 6),
                        for (var i = 1; i <= 5; i++)
                          Icon(i <= u.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 13, color: AppColors.accent),
                        const Spacer(),
                        Text(formatTanggal(u.tanggal), style: AppTextStyles.bodySm.copyWith(fontSize: 10.5, color: AppColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(u.teks, style: AppTextStyles.bodySm),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
