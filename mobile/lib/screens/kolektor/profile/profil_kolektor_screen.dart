import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/kolektor/kolektor_bottom_nav.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR UTAMA/.../galeria_profil_kolektor/code.html
///
/// Data profil, statistik, & alamat di sini contoh (placeholder).
class ProfilKolektorScreen extends StatelessWidget {
  const ProfilKolektorScreen({
    super.key,
    this.onNavTap,
    this.onPindai,
    this.onLogout,
    this.onPesananTap,
  });

  final ValueChanged<int>? onNavTap;
  final VoidCallback? onPindai;
  final VoidCallback? onLogout;
  final VoidCallback? onPesananTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Profil Saya', style: AppTextStyles.headlineMd),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.tune)),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
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
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        const CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.primary,
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent,
                            ),
                            child: const Icon(
                              Icons.verified,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                            child: Text(
                              'KOLEKTOR TERVERIFIKASI',
                              style: AppTextStyles.overline.copyWith(
                                fontSize: 8,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rani Paramitha',
                            style: AppTextStyles.headlineMd.copyWith(
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Patron Seni Kontemporer & Modern',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'ID Kolektor: #GAL-8829-ID',
                            style: AppTextStyles.overline.copyWith(
                              fontSize: 9,
                              color: AppColors.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _stat('8', 'Karya Dikoleksi')),
                      Container(width: 1, height: 28, color: AppColors.border),
                      Expanded(child: _stat('14', 'Tawaran Lelang')),
                      Container(width: 1, height: 28, color: AppColors.border),
                      Expanded(child: _stat('3', 'Pameran Dihadiri')),
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
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.accentSoft,
                  child: const Icon(
                    Icons.workspace_premium,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TINGKAT KURATORIAL',
                        style: AppTextStyles.overline.copyWith(
                          fontSize: 8,
                          color: Colors.white60,
                        ),
                      ),
                      Text(
                        'GALERIA Premier Patron',
                        style: AppTextStyles.headlineSm.copyWith(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Riwayat Pesanan Seni', style: AppTextStyles.headlineSm),
              TextButton(
                onPressed: onPesananTap,
                child: const Text('Lihat Semua'),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
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
                    'assets/images/catalog/baroque_01.jpg',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          'Sedang Dikirim',
                          style: AppTextStyles.overline.copyWith(
                            fontSize: 8,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      Text(
                        'Sang Putri Mahkota Renaisans',
                        style: AppTextStyles.labelMd.copyWith(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      Text(
                        'Rp 120.000.000',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Alamat Tersimpan', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.xs),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'UTAMA · PENGIRIMAN KURATORIAL',
                    style: AppTextStyles.overline.copyWith(
                      fontSize: 8,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Apartemen & Galeri Pribadi (Jakarta)',
                  style: AppTextStyles.labelMd,
                ),
                Text(
                  'Rani Paramitha · +62 812-3456-7890',
                  style: AppTextStyles.bodySm.copyWith(fontSize: 11),
                ),
                Text(
                  'Apartemen Senopati Suites, Tower 2 Lt. 18, Jl. Senopati No. 41, Kebayoran Baru, Jakarta Selatan',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Preferensi & Layanan Kolektor',
            style: AppTextStyles.headlineSm,
          ),
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
                _menuTile(
                  Icons.account_balance_wallet_outlined,
                  'Metode Pembayaran & Escrow Seni',
                  'BCA Prioritas, Visa Signature',
                ),
                const Divider(height: 1),
                _menuTile(
                  Icons.history_edu_outlined,
                  'Sertifikat Keaslian (COA) Digital',
                  'Kriptografis & terverifikasi kurator',
                ),
                const Divider(height: 1),
                _menuTile(
                  Icons.auto_awesome_outlined,
                  'Preferensi Genre & Kurator Favorit',
                  'Barok, Kubisme, Impresionisme',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
            label: const Text(
              'Keluar dari Akun Kolektor',
              style: TextStyle(color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.errorContainer.withValues(alpha: 0.4),
              side: BorderSide.none,
              minimumSize: const Size(double.infinity, 46),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              'GALERIA Mobile Salons',
              style: AppTextStyles.labelSm.copyWith(color: AppColors.outline),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
      bottomNavigationBar: KolektorBottomNav(
        currentIndex: 3,
        onTap: (i) => onNavTap?.call(i),
        onPindai: onPindai ?? () {},
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
    children: [
      Text(value, style: AppTextStyles.headlineSm.copyWith(fontSize: 16)),
      Text(
        label.toUpperCase(),
        style: AppTextStyles.overline.copyWith(fontSize: 7),
      ),
    ],
  );

  Widget _menuTile(IconData icon, String title, String subtitle) => InkWell(
    onTap: () {},
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surfaceContainer,
            child: Icon(icon, size: 16, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMd.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.muted,
                    fontSize: 10.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
        ],
      ),
    ),
  );
}
