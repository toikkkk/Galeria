import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// "14:05" dari waktu lokal.
String jamMenit(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Lencana status event: akan datang / berlangsung / selesai / dibatalkan.
class StatusEventChip extends StatelessWidget {
  const StatusEventChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, warna) = switch (status) {
      'berlangsung' => ('BERLANGSUNG', AppColors.accent),
      'akan_datang' => ('AKAN DATANG', AppColors.primary),
      'dibatalkan' => ('DIBATALKAN', AppColors.error),
      _ => ('SELESAI', AppColors.outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: warna.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(label, style: AppTextStyles.overline.copyWith(fontSize: 8.5, color: warna)),
    );
  }
}

const _bulanPendek = ['JAN', 'FEB', 'MAR', 'APR', 'MEI', 'JUN', 'JUL', 'AGU', 'SEP', 'OKT', 'NOV', 'DES'];

/// Blok tanggal ala potongan tiket: tanggal besar di atas, bulan singkat di bawah.
class TanggalTile extends StatelessWidget {
  const TanggalTile({super.key, required this.tanggal, this.ukuran = 58, this.terang = false});

  final DateTime tanggal;
  final double ukuran;

  /// true = kotak putih (di atas latar gelap); false = kotak emas.
  final bool terang;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ukuran,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: terang ? Colors.white : AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${tanggal.day}', style: AppTextStyles.headlineMd.copyWith(fontSize: ukuran * 0.40, height: 1.05, color: AppColors.onSurface)),
          Text(_bulanPendek[tanggal.month - 1], style: AppTextStyles.overline.copyWith(fontSize: 10, color: AppColors.onSurface)),
        ],
      ),
    );
  }
}
