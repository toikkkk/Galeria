import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kolektor/kolektor_bottom_nav.dart';

/// Layar "Daftar Pesanan" -- pintu masuk tab "Pesanan" di bottom nav.
///
/// Tidak ada mockup terpisah untuk ini di
/// docs/KOLEKTOR FITUR PEMBELIAN PEMBAYARAN/ (folder itu isinya screen alur
/// linear: Detail Karya -> Profil Toko -> Konfirmasi Pesanan -> Selesaikan
/// Pembayaran -> Pesanan Selesai & Ulasan, semua sudah dikonversi di
/// screens/kolektor/karya/ & screens/kolektor/pesanan/). Layar ini
/// menghubungkan SEMUA layar pesanan itu jadi satu daftar yang bisa
/// dipencet, dengan gaya kartu yang sama dengan "Riwayat Pesanan Seni" di
/// ProfilKolektorScreen (docs/KOLEKTOR FITUR UTAMA/.../galeria_profil_kolektor).
///
/// Data status pesanan di sini contoh (placeholder).
///
/// TODO(backend): ganti [_pesananDemo] dengan fetch nyata ke endpoint
/// pesanan/order begitu tersedia.
enum StatusPesanan { menungguPembayaran, sedangDikirim, selesai }

class _PesananDemo {
  const _PesananDemo({
    required this.karya,
    required this.status,
    required this.kodeOrder,
    required this.tanggalLabel,
  });

  final Karya karya;
  final StatusPesanan status;
  final String kodeOrder;
  final String tanggalLabel;
}

final _pesananDemo = <_PesananDemo>[
  _PesananDemo(
    karya: sampleKarya[0],
    status: StatusPesanan.menungguPembayaran,
    kodeOrder: '#GLR-2026-9012',
    tanggalLabel: 'Dibuat hari ini · Batas bayar 23:47:10',
  ),
  _PesananDemo(
    karya: sampleKarya[1],
    status: StatusPesanan.sedangDikirim,
    kodeOrder: '#GLR-2026-8901',
    tanggalLabel: 'JNE Art Cargo · Tiba besok',
  ),
  _PesananDemo(
    karya: sampleKarya[2],
    status: StatusPesanan.selesai,
    kodeOrder: '#GLR-2025-4771',
    tanggalLabel: 'Selesai & diterima 18 Jan 2025',
  ),
];

class DaftarPesananScreen extends StatefulWidget {
  const DaftarPesananScreen({
    super.key,
    this.onNavTap,
    this.onPindai,
    this.onBayarTap,
    this.onDetailTap,
  });

  final ValueChanged<int>? onNavTap;
  final VoidCallback? onPindai;

  /// Dipanggil dengan total tagihan (Rp) saat kartu "Menunggu Pembayaran"
  /// ditekan -> buka SelesaikanPembayaranScreen.
  final ValueChanged<int>? onBayarTap;

  /// Dipanggil dengan [Karya] saat kartu "Sedang Dikirim"/"Selesai" ditekan
  /// -> buka PesananSelesaiScreen (berfungsi ganda sbg detail + lacak
  /// pengiriman, sesuai isi mockup aslinya yang juga punya tile "Pantau
  /// Pengiriman Khusus").
  final ValueChanged<Karya>? onDetailTap;

  @override
  State<DaftarPesananScreen> createState() => _DaftarPesananScreenState();
}

class _DaftarPesananScreenState extends State<DaftarPesananScreen> {
  int _filter = 0; // 0=semua, 1=menunggu, 2=diproses, 3=selesai

  @override
  Widget build(BuildContext context) {
    final filtered = _pesananDemo.where((p) {
      switch (_filter) {
        case 1:
          return p.status == StatusPesanan.menungguPembayaran;
        case 2:
          return p.status == StatusPesanan.sedangDikirim;
        case 3:
          return p.status == StatusPesanan.selesai;
        default:
          return true;
      }
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Pesanan Saya', style: AppTextStyles.headlineMd),
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
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, i) {
                const labels = [
                  'Semua',
                  'Menunggu Pembayaran',
                  'Diproses & Dikirim',
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
                      'Belum ada pesanan pada kategori ini',
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
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      return _PesananCard(
                        pesanan: p,
                        onTap: () {
                          if (p.status == StatusPesanan.menungguPembayaran) {
                            widget.onBayarTap?.call(p.karya.priceIdr + 2625000);
                          } else {
                            widget.onDetailTap?.call(p.karya);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: KolektorBottomNav(
        currentIndex: 2,
        onTap: (i) => widget.onNavTap?.call(i),
        onPindai: widget.onPindai ?? () {},
      ),
    );
  }
}

class _PesananCard extends StatelessWidget {
  const _PesananCard({required this.pesanan, this.onTap});

  final _PesananDemo pesanan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    late final Color badgeBg, badgeFg;
    late final IconData badgeIcon;
    late final String badgeLabel, actionLabel;
    switch (pesanan.status) {
      case StatusPesanan.menungguPembayaran:
        badgeBg = AppColors.errorContainer.withValues(alpha: 0.4);
        badgeFg = AppColors.error;
        badgeIcon = Icons.timer_outlined;
        badgeLabel = 'Menunggu Pembayaran';
        actionLabel = 'Bayar Sekarang';
      case StatusPesanan.sedangDikirim:
        badgeBg = AppColors.accentSoft.withValues(alpha: 0.6);
        badgeFg = AppColors.accent;
        badgeIcon = Icons.local_shipping_outlined;
        badgeLabel = 'Sedang Dikirim';
        actionLabel = 'Lacak Pengiriman';
      case StatusPesanan.selesai:
        badgeBg = AppColors.successContainer.withValues(alpha: 0.15);
        badgeFg = AppColors.success;
        badgeIcon = Icons.task_alt;
        badgeLabel = 'Selesai & Diterima';
        actionLabel = 'Lihat Detail';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 12, color: badgeFg),
                      const SizedBox(width: 4),
                      Text(
                        badgeLabel,
                        style: AppTextStyles.overline.copyWith(
                          fontSize: 9,
                          color: badgeFg,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  pesanan.kodeOrder,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.outline,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.asset(
                    pesanan.karya.assetPath,
                    width: 56,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pesanan.karya.title,
                        style: AppTextStyles.headlineSm.copyWith(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        pesanan.karya.artistName,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        pesanan.tanggalLabel,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.outline,
                          fontSize: 10.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pesanan.karya.priceFormatted,
                        style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    actionLabel,
                    style: AppTextStyles.labelMd.copyWith(fontSize: 12.5),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
