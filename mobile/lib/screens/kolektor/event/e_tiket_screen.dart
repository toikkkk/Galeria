import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR UTAMA/.../galeria_pendaftaran_berhasil_e_tiket_event/code.html
///
/// Kode barcode di sini representasi visual saja (bar-bar statis), bukan
/// barcode Code-128 yang bisa dipindai sungguhan -- UI demo.
class ETiketScreen extends StatelessWidget {
  const ETiketScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'E-Tiket & Bukti Pendaftaran',
          style: AppTextStyles.headlineSm,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
          vertical: AppSpacing.md,
        ),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 28),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Pendaftaran Berhasil Terkonfirmasi',
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'E-Tiket & Bukti Pendaftaran',
                  style: AppTextStyles.headlineLg,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tunjukkan barcode di meja resepsionis kuratorial saat kedatangan.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 16),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  color: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.workspace_premium,
                            size: 16,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'GALERIA SALON VERNISSAGE',
                            style: AppTextStyles.overline.copyWith(
                              color: Colors.white,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          'KURATOR VIP',
                          style: AppTextStyles.overline.copyWith(
                            fontSize: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.asset(
                    'assets/images/catalog/baroque_01.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Diselenggarakan oleh Sanggar Rupa Nusantara',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      const Divider(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(child: _detail('Tanggal', '24 Okt 2026')),
                          Expanded(child: _detail('Sesi', '14:00 – 18:00')),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _detail('Nama Kolektor', 'Rani Paramita'),
                          ),
                          Expanded(child: _detail('Alokasi', 'VIP-A12')),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: AppColors.border,
                        style: BorderStyle.solid,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.qr_code_2,
                        size: 96,
                        color: AppColors.onSurface.withValues(alpha: 0.85),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'GLR-EVT-2026-8849-VIP',
                        style: AppTextStyles.labelMd.copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars, size: 18, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Hak Istimewa Akses VIP',
                      style: AppTextStyles.headlineSm.copyWith(fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _privilege(
                  'Akses eksklusif VIP Hall & Private Collectors Lounge',
                ),
                _privilege('Katalog pameran edisi hardbound bertanda tangan'),
                _privilege('Welcome evening cocktail bersama dewan kurator'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: onDone,
            child: const Text('Kembali ke Beranda Kolektor'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: AppTextStyles.overline.copyWith(fontSize: 8),
      ),
      Text(
        value,
        style: AppTextStyles.bodyMd.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    ],
  );

  Widget _privilege(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, size: 14, color: AppColors.success),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: AppTextStyles.bodySm)),
      ],
    ),
  );
}
