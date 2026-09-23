import 'package:flutter/material.dart';

import '../../../models/notifikasi.dart';
import '../../../theme/app_theme.dart';

/// Layar "Notifikasi" -- tujuan ikon lonceng di AppBar BerandaKolektorScreen.
///
/// Tidak ada mockup terpisah untuk ini di docs/ -- layar ini melengkapi
/// navigasi supaya ikon lonceng (yang sebelumnya no-op) benar-benar
/// menampilkan sesuatu: peringatan pesanan, ajakan ikut lelang, event yang
/// dipromosikan, rekomendasi karya, dan info sertifikat digital.
///
/// TODO(backend): lihat models/notifikasi.dart -- data & status baca/belum
/// baca di sini masih lokal (di-reset tiap kali layar dibuka ulang).
class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({
    super.key,
    required this.onBack,
    this.onPesananTap,
    this.onLelangTap,
    this.onEventTap,
    this.onRekomendasiTap,
    this.onSertifikatTap,
  });

  final VoidCallback onBack;
  final VoidCallback? onPesananTap;
  final VoidCallback? onLelangTap;
  final VoidCallback? onEventTap;
  final VoidCallback? onRekomendasiTap;
  final VoidCallback? onSertifikatTap;

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  late List<NotifikasiItem> _items = List.of(sampleNotifikasi);

  void _tandaiSemuaDibaca() {
    setState(() {
      _items = [
        for (final item in _items)
          NotifikasiItem(
            kategori: item.kategori,
            title: item.title,
            subtitle: item.subtitle,
            waktuLabel: item.waktuLabel,
            mendesak: item.mendesak,
            dibaca: true,
          ),
      ];
    });
  }

  void _bukaItem(int index) {
    final item = _items[index];
    setState(() {
      _items[index] = NotifikasiItem(
        kategori: item.kategori,
        title: item.title,
        subtitle: item.subtitle,
        waktuLabel: item.waktuLabel,
        mendesak: item.mendesak,
        dibaca: true,
      );
    });
    switch (item.kategori) {
      case NotifikasiKategori.pesanan:
        widget.onPesananTap?.call();
      case NotifikasiKategori.lelang:
        widget.onLelangTap?.call();
      case NotifikasiKategori.event:
        widget.onEventTap?.call();
      case NotifikasiKategori.rekomendasi:
        widget.onRekomendasiTap?.call();
      case NotifikasiKategori.sertifikat:
        widget.onSertifikatTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final belumDibaca = _items.where((i) => !i.dibaca).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Notifikasi', style: AppTextStyles.headlineSm),
        actions: [
          if (belumDibaca > 0)
            TextButton(
              onPressed: _tandaiSemuaDibaca,
              child: const Text('Tandai Semua Dibaca'),
            ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: Text(
                'Belum ada notifikasi',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.muted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenGutter,
                vertical: AppSpacing.sm,
              ),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) =>
                  _NotifikasiTile(item: _items[i], onTap: () => _bukaItem(i)),
            ),
    );
  }
}

class _NotifikasiTile extends StatelessWidget {
  const _NotifikasiTile({required this.item, this.onTap});

  final NotifikasiItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final Color color;
    switch (item.kategori) {
      case NotifikasiKategori.pesanan:
        icon = Icons.local_shipping_outlined;
        color = item.mendesak ? AppColors.error : AppColors.accent;
      case NotifikasiKategori.lelang:
        icon = Icons.gavel_outlined;
        color = AppColors.accent;
      case NotifikasiKategori.event:
        icon = Icons.confirmation_number_outlined;
        color = AppColors.accent;
      case NotifikasiKategori.rekomendasi:
        icon = Icons.auto_awesome_outlined;
        color = AppColors.primary;
      case NotifikasiKategori.sertifikat:
        icon = Icons.verified_user_outlined;
        color = AppColors.success;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: item.dibaca
              ? Colors.white
              : AppColors.accentSoft.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.labelMd.copyWith(
                      fontSize: 13.5,
                      fontWeight: item.dibaca
                          ? FontWeight.w600
                          : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.waktuLabel.toUpperCase(),
                    style: AppTextStyles.overline.copyWith(
                      fontSize: 8.5,
                      color: AppColors.outline,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.dibaca)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs, top: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.mendesak ? AppColors.error : AppColors.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
