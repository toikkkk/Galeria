import 'dart:async';

import 'package:flutter/material.dart';

import '../models/karya.dart';
import '../models/lelang.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'karya_image.dart';

/// Gambar karya sebuah lelang.
class LelangGambar extends StatelessWidget {
  const LelangGambar({super.key, required this.lelang});

  final Lelang lelang;

  @override
  Widget build(BuildContext context) => KaryaImage(
        karya: Karya(
          assetPath: 'assets/images/catalog/${lelang.imageFilename ?? ''}',
          imageUrl: lelang.imageUrl,
          title: lelang.judul,
          artistName: lelang.artistName,
          styleName: lelang.styleName,
          priceIdr: lelang.hargaSaatIniIdr,
          galleryName: lelang.senimanNama,
        ),
      );
}

/// Hitung mundur yang berdetak tiap detik dari jam server (lihat [Lelang.sisa]).
class HitungMundur extends StatefulWidget {
  const HitungMundur({super.key, required this.lelang, this.style, this.onHabis});

  final Lelang lelang;
  final TextStyle? style;

  /// Dipanggil sekali saat sisa waktu mencapai nol (mis. muat ulang data).
  final VoidCallback? onHabis;

  @override
  State<HitungMundur> createState() => _HitungMundurState();
}

class _HitungMundurState extends State<HitungMundur> {
  Timer? _timer;
  bool _sudahHabis = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      final l = widget.lelang;
      // waktu habis menurut jam server, tapi data dari server masih belum 'selesai' -> minta data terbaru
      if (!_sudahHabis && l.status != 'selesai' && l.status != 'dibatalkan' && l.statusSekarang == 'selesai') {
        _sudahHabis = true;
        widget.onHabis?.call();
      }
    });
  }

  @override
  void didUpdateWidget(covariant HitungMundur old) {
    super.didUpdateWidget(old);
    if (old.lelang.id != widget.lelang.id || old.lelang.selesai != widget.lelang.selesai) _sudahHabis = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lelang;
    final st = l.statusSekarang;
    final teks = switch (st) {
      'berlangsung' => formatSisa(l.sisa),
      'akan_datang' => 'Mulai ${formatSisa(l.sisa)}',
      'dibatalkan' => 'Dibatalkan',
      _ => 'Berakhir',
    };
    return Text(teks, style: widget.style ?? AppTextStyles.labelMd);
  }
}

({String label, Color warna}) infoStatusLelang(String status) => switch (status) {
      'berlangsung' => (label: 'BERLANGSUNG', warna: AppColors.accent),
      'akan_datang' => (label: 'SEGERA', warna: const Color(0xFFB26A00)),
      'dibatalkan' => (label: 'DIBATALKAN', warna: AppColors.error),
      _ => (label: 'SELESAI', warna: AppColors.outline),
    };

/// Kartu satu lelang di daftar.
class LelangKartu extends StatelessWidget {
  const LelangKartu({super.key, required this.lelang, required this.onTap, this.catatan});

  final Lelang lelang;
  final VoidCallback onTap;

  /// Baris tambahan di bawah (mis. "Kamu penawar tertinggi").
  final Widget? catatan;

  @override
  Widget build(BuildContext context) {
    final info = infoStatusLelang(lelang.statusSekarang);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(width: 110, height: 130, child: LelangGambar(lelang: lelang)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: info.warna.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)),
                      child: Text(info.label, style: AppTextStyles.overline.copyWith(fontSize: 8.5, color: info.warna)),
                    ),
                    const SizedBox(height: 4),
                    Text(lelang.judul, style: AppTextStyles.labelMd, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(lelang.artistName, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(lelang.jumlahBid == 0 ? 'Harga awal' : 'Bid tertinggi', style: AppTextStyles.bodySm.copyWith(fontSize: 10, color: AppColors.muted)),
                    Text(formatRupiah(lelang.hargaSaatIniIdr), style: AppTextStyles.labelMd.copyWith(color: AppColors.accent)),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 13, color: AppColors.muted),
                        const SizedBox(width: 3),
                        HitungMundur(lelang: lelang, style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
                        const Spacer(),
                        Text('${lelang.jumlahBid} bid', style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                    if (catatan != null) ...[const SizedBox(height: 2), catatan!],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
