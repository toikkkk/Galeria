import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:share_plus/share_plus.dart';

import '../../../models/karya.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../widgets/commerce_widgets.dart';
import '../../../widgets/favorit_hati.dart';
import '../../../widgets/karya_image.dart';
import '../../../widgets/keranjang_tombol.dart';
import '../../../widgets/ulasan_karya_card.dart';

/// Halaman produk karya (pola Tokopedia/Shopee): gambar besar yang bisa diperbesar, harga, lencana,
/// info ringkas, sertifikat keaslian digital, kartu penjual, ulasan, deskripsi, dan bilah beli lengket.
///
/// Semua isi berasal dari data karya nyata -- tidak ada angka karangan (pengikut, lokasi, dst.).
/// "Sertifikat Keaslian Digital" = bukti registrasi kepemilikan digital di GALERIA, BUKAN pemeriksaan keaslian fisik.
class DetailKaryaScreen extends StatelessWidget {
  const DetailKaryaScreen({
    super.key,
    required this.karya,
    required this.onBack,
    this.onArTap,
    this.onBeliTap,
    this.onLelangTap,
    this.onTokoTap,
  });

  final Karya karya;
  final VoidCallback onBack;
  final VoidCallback? onArTap;
  final VoidCallback? onBeliTap;

  /// Karya sedang dilelang: buka halaman lelangnya (dengan id lelang).
  final ValueChanged<String>? onLelangTap;
  final VoidCallback? onTokoTap;

  bool get _dilelang => karya.lelangId != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLatarMarketplace,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Detail Karya', style: AppTextStyles.headlineSm),
        actions: [
          IconButton(
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: '${karya.title} — ${karya.artistName} di GALERIA\n${karya.shareUrl}'),
            ),
            icon: const Icon(Icons.share_outlined),
          ),
          FavoritHati(karya: karya, bulat: false, ukuran: 24),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          _galeri(context),
          _blokHarga(),
          const SizedBox(height: AppSpacing.xs),
          _infoKarya(),
          if (karya.artworkId != null) _sertifikat(context),
          _kartuPenjual(),
          if (karya.id.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: UlasanKaryaCard(karyaId: karya.id),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, 0),
            child: KartuBagian(
              judul: 'Deskripsi Karya',
              ikon: Icons.notes,
              child: Text(
                (karya.deskripsi != null && karya.deskripsi!.isNotEmpty)
                    ? karya.deskripsi!
                    : 'Karya beraliran ${karya.styleName} oleh ${karya.artistName}, ditawarkan oleh ${karya.galleryName}.',
                style: AppTextStyles.bodyMd.copyWith(fontSize: 13.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: KartuBagian(
              judul: 'Belanja Aman di GALERIA',
              ikon: Icons.shield_outlined,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CatatanIkon('Karya seni bersifat unik: hanya ada satu stok per karya.', ikon: Icons.looks_one_outlined),
                  SizedBox(height: 6),
                  CatatanIkon('Kepemilikan tercatat atas namamu setelah pesanan selesai.', ikon: Icons.assignment_turned_in_outlined),
                  SizedBox(height: 6),
                  CatatanIkon('Sertifikat digital hanya menandai registrasi di GALERIA, bukan pemeriksaan keaslian fisik lukisan.', ikon: Icons.info_outline),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bilahBeli(),
    );
  }

  Widget _galeri(BuildContext context) {
    return Container(
      color: Colors.white,
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => _perbesar(context),
              child: Container(color: AppColors.surfaceContainer, child: KaryaImage(karya: karya, fit: BoxFit.contain)),
            ),
            Positioned(
              left: AppSpacing.sm,
              top: AppSpacing.sm,
              child: Wrap(
                spacing: 6,
                children: [
                  if (karya.statusVerifikasi == 'terverifikasi') const LencanaKecil('Terverifikasi', ikon: Icons.verified, warna: AppColors.success),
                  if (_dilelang) const LencanaKecil('Sedang dilelang', ikon: Icons.gavel),
                  if (karya.isPromoted) const LencanaKecil('Promosi', ikon: Icons.campaign_outlined, warna: AppColors.primary),
                ].map((w) => DecoratedBox(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.full)), child: w)).toList(),
              ),
            ),
            Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(AppRadius.full)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.zoom_out_map, size: 13, color: Colors.white), SizedBox(width: 4), Text('Ketuk untuk perbesar', style: TextStyle(color: Colors.white, fontSize: 10))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _perbesar(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(minScale: 1, maxScale: 5, child: Center(child: KaryaImage(karya: karya, fit: BoxFit.contain))),
          ),
          Positioned(
            top: MediaQuery.of(ctx).padding.top + 8,
            right: 8,
            child: IconButton.filled(
              onPressed: () => Navigator.pop(ctx),
              style: IconButton.styleFrom(backgroundColor: Colors.white24),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blokHarga() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatRupiah(karya.priceIdr), style: AppTextStyles.displayMd.copyWith(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          const SizedBox(height: 2),
          Text(karya.title, style: AppTextStyles.headlineMd.copyWith(fontSize: 20)),
          const SizedBox(height: 4),
          Text('${karya.artistName} · ${karya.styleName}', style: AppTextStyles.bodySm.copyWith(fontSize: 12.5)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              LencanaKecil(karya.terjual ? 'Sudah terjual' : 'Tersedia · stok 1', ikon: karya.terjual ? Icons.block : Icons.inventory_2_outlined, warna: karya.terjual ? AppColors.error : AppColors.success),
              const LencanaKecil('Karya unik', ikon: Icons.diamond_outlined, warna: AppColors.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 6),
          Text('Belum termasuk ongkos kirim', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _infoKarya() {
    final ukuran = (karya.lebarCm != null && karya.tinggiCm != null) ? '${_cm(karya.lebarCm!)} × ${_cm(karya.tinggiCm!)} cm' : 'Belum dicantumkan';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: KartuBagian(
        judul: 'Informasi Karya',
        ikon: Icons.palette_outlined,
        child: Column(
          children: [
            _barisInfo('Seniman', karya.artistName),
            _barisInfo('Aliran', karya.styleName),
            _barisInfo('Ukuran', ukuran),
            _barisInfo('Galeri', karya.galleryName),
            _barisInfo('Ketersediaan', karya.terjual ? 'Sudah terjual' : 'Tersedia'),
          ],
        ),
      ),
    );
  }

  Widget _barisInfo(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 104, child: Text(l, style: AppTextStyles.bodySm.copyWith(fontSize: 12.5))),
            Expanded(child: Text(v, style: AppTextStyles.labelMd.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500))),
          ],
        ),
      );

  Widget _sertifikat(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, 0),
      child: KartuBagian(
        judul: 'Sertifikat Keaslian Digital',
        ikon: Icons.verified_user_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
              decoration: BoxDecoration(color: AppColors.accentSoft.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(
                children: [
                  Expanded(child: Text(karya.artworkId ?? '', style: AppTextStyles.bodySm.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w600, color: AppColors.onSurface))),
                  GestureDetector(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: karya.artworkId ?? ''));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID sertifikat disalin.')));
                      }
                    },
                    child: const Icon(Icons.content_copy, size: 15, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bukti registrasi kepemilikan digital karya ini di platform GALERIA, ditandatangani secara kriptografis.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuPenjual() {
    final inisial = karya.artistName.trim().isEmpty ? '?' : karya.artistName.trim().substring(0, karya.artistName.trim().length >= 2 ? 2 : 1).toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: KartuBagian(
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary,
              child: Text(inisial, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(karya.artistName, style: AppTextStyles.headlineSm.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(karya.galleryName, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onTokoTap,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm)),
              child: const Text('Kunjungi Toko'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bilahBeli() {
    return BarBawah(
      child: Row(
        children: [
          IconButton.outlined(
            onPressed: onArTap,
            icon: const Icon(Icons.view_in_ar_outlined, color: AppColors.accent),
            tooltip: 'Coba di Ruangan (AR)',
          ),
          const SizedBox(width: AppSpacing.xs),
          KeranjangTombol(karya: karya),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: ElevatedButton(
              onPressed: karya.terjual ? null : (_dilelang ? () => onLelangTap?.call(karya.lelangId!) : onBeliTap),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.onSurface),
              child: Text(
                karya.terjual ? 'Sudah terjual' : (_dilelang ? 'Sedang dilelang · Ikuti Lelang' : 'Beli Sekarang · ${karya.priceFormatted}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 60.0 -> "60", 60.5 -> "60,5".
  static String _cm(double v) => (v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ','));
}
