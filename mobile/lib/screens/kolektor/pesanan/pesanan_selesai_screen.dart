import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../theme/app_theme.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR PEMBELIAN PEMBAYARAN/.../galeria_pesanan_selesai_ulasan/code.html
///
/// (Judul aslinya di mockup salah tertulis "Konfirmasi Pesanan" -- diperbaiki
/// di sini jadi "Pesanan Selesai" sesuai isi & konteks layar.)
///
/// TODO(backend): kirim ulasan ke endpoint review nyata -- saat ini hanya
/// mengubah state lokal layar ini.
class PesananSelesaiScreen extends StatefulWidget {
  const PesananSelesaiScreen({
    super.key,
    required this.karya,
    required this.onSelesai,
  });

  final Karya karya;
  final VoidCallback onSelesai;

  @override
  State<PesananSelesaiScreen> createState() => _PesananSelesaiScreenState();
}

class _PesananSelesaiScreenState extends State<PesananSelesaiScreen> {
  int _rating = 5;
  bool _submitted = false;
  final _catatanCtrl = TextEditingController(
    text:
        'Karya tiba dalam kondisi sempurna dengan peti kayu berinsulasi rapi.',
  );

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Pesanan Selesai', style: AppTextStyles.headlineSm),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
          vertical: AppSpacing.sm,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 8),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                  child: const Icon(Icons.verified, color: Colors.white),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRANSAKSI SUKSES · LELANG TERVERIFIKASI',
                        style: AppTextStyles.overline.copyWith(
                          fontSize: 8.5,
                          color: AppColors.accent,
                        ),
                      ),
                      Text(
                        'Pembayaran Diterima & Sah',
                        style: AppTextStyles.headlineSm.copyWith(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.asset(
                    widget.karya.assetPath,
                    width: 72,
                    height: 92,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.karya.title,
                        style: AppTextStyles.headlineSm.copyWith(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      Text(
                        widget.karya.artistName,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.karya.priceFormatted,
                        style: AppTextStyles.labelMd.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppColors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sertifikat Digital (COA) Terbit',
                        style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                      ),
                      Text(
                        'Bukti registrasi kepemilikan digital di platform GALERIA',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: () {}, child: const Text('Lihat')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ulasan & Sertifikasi Kepuasan',
                  style: AppTextStyles.headlineSm.copyWith(fontSize: 15),
                ),
                Text(
                  'Bagikan evaluasi Anda terhadap kondisi fisik karya & ketepatan pengiriman.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 1; i <= 5; i++)
                        IconButton(
                          onPressed: () => setState(() => _rating = i),
                          icon: Icon(
                            i <= _rating ? Icons.star : Icons.star_border,
                            color: AppColors.accent,
                            size: 28,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _catatanCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide.none,
                    ),
                    hintText:
                        'Tulis catatan kondisi karya saat serah terima...',
                  ),
                  style: AppTextStyles.bodySm,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!_submitted)
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _submitted = true),
                    icon: const Icon(Icons.verified, size: 18),
                    label: const Text('Kirim Ulasan & Klaim Lencana Kolektor'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.successContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.military_tech,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lencana "Kolektor Terverifikasi" Diperbarui',
                                style: AppTextStyles.labelMd.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Ulasan Anda diterbitkan di katalog karya.',
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.muted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: widget.onSelesai,
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Buka Koleksi Pribadi Saya'),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Unduh Bukti Transaksi Resmi (PDF)'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
