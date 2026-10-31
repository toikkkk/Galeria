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
