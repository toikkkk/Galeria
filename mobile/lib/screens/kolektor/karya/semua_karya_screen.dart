import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kolektor/karya_grid_card.dart';

/// Layar "Semua Karya" -- tujuan tombol "Lihat Semua" di sebelah
/// "Rekomendasi untukmu" pada BerandaKolektorScreen.
///
/// Tidak ada mockup terpisah untuk ini di docs/ (folder Kolektor Fitur
/// Utama cuma menampilkan 4 kartu rekomendasi di beranda tanpa layar
/// katalog lengkap) -- layar ini melengkapi navigasi supaya "Lihat Semua"
/// benar-benar menuju sesuatu, bukan menampilkan karya yang sama dari
/// beranda.
///
/// Karya yang [Karya.isPromoted] (dibayar seniman utk tampil lebih dulu)
/// ditaruh di section terpisah paling atas, sisanya di bawah -- sesuai
/// urutan tampil marketplace pada umumnya.
///
/// TODO(backend): ganti [sampleKarya] dengan fetch nyata ke
/// `GET /api/katalog` (dengan query/flag promosi) begitu tersedia.
class SemuaKaryaScreen extends StatelessWidget {
  const SemuaKaryaScreen({super.key, required this.onBack, this.onKaryaTap});

  final VoidCallback onBack;
  final ValueChanged<Karya>? onKaryaTap;

  @override
  Widget build(BuildContext context) {
    final promoted = sampleKarya.where((k) => k.isPromoted).toList();
    final lainnya = sampleKarya.where((k) => !k.isPromoted).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Semua Karya', style: AppTextStyles.headlineSm),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
          vertical: AppSpacing.sm,
        ),
        children: [
          if (promoted.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.trending_up,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text('Dipromosikan Seniman', style: AppTextStyles.headlineSm),
              ],
            ),
            Text(
              'Karya pilihan yang ditampilkan lebih dulu oleh senimannya',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.sm),
            _grid(promoted),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text('Karya Lainnya', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.sm),
          _grid(lainnya),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _grid(List<Karya> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.66,
      ),
      itemBuilder: (context, i) => KaryaGridCard(
        karya: items[i],
        overline: null,
        onTap: () => onKaryaTap?.call(items[i]),
      ),
    );
  }
}
