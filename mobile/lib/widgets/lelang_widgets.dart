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

/// Kartu satu lelang di daftar: gambar dengan lencana status + pil hitung mundur (merah bila < 1 jam),
/// lalu judul, seniman, harga/bid tertinggi, dan jumlah tawaran.
class LelangKartu extends StatelessWidget {
  const LelangKartu({super.key, required this.lelang, required this.onTap, this.catatan});

  final Lelang lelang;
  final VoidCallback onTap;

  /// Baris tambahan di bawah (mis. "Kamu penawar tertinggi").
  final Widget? catatan;

  @override
  Widget build(BuildContext context) {
    final info = infoStatusLelang(lelang.statusSekarang);
    final mendesak = lelang.statusSekarang == 'berlangsung' && lelang.sisa < const Duration(hours: 1);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 164,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 124,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LelangGambar(lelang: lelang),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: info.warna, borderRadius: BorderRadius.circular(AppRadius.full)),
                        child: Text(info.label, style: AppTextStyles.overline.copyWith(fontSize: 8, color: info.warna == AppColors.accent ? AppColors.onSurface : Colors.white)),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(color: mendesak ? AppColors.error : const Color(0xE63E251E), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.timer_outlined, size: 12, color: Colors.white),
                            const SizedBox(width: 3),
                            Flexible(child: HitungMundur(lelang: lelang, style: AppTextStyles.labelSm.copyWith(color: Colors.white, fontSize: 10.5))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lelang.judul, style: AppTextStyles.labelMd.copyWith(fontSize: 14.5, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(lelang.artistName, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Text(lelang.jumlahBid == 0 ? 'Harga awal' : 'Bid tertinggi', style: AppTextStyles.bodySm.copyWith(fontSize: 10.5, color: AppColors.muted)),
                      Row(
                        children: [
                          Flexible(
                            child: Text(formatRupiah(lelang.hargaSaatIniIdr),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.headlineSm.copyWith(fontSize: 18, color: const Color(0xFF3E251E), fontWeight: FontWeight.w800)),
                          ),
                          if (lelang.jumlahBid > 0 && lelang.hargaAwalIdr > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFF7E7C1), borderRadius: BorderRadius.circular(AppRadius.full)),
                              child: Text('+${((lelang.hargaSaatIniIdr - lelang.hargaAwalIdr) * 100 / lelang.hargaAwalIdr).round()}%',
                                  style: AppTextStyles.labelSm.copyWith(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF7A5410))),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.groups_2_outlined, size: 14, color: Color(0xFF3E251E)),
                          const SizedBox(width: 4),
                          Text('${lelang.jumlahBid} bid', style: AppTextStyles.bodySm.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF3E251E))),
                        ],
                      ),
                      if (catatan != null) ...[const SizedBox(height: 3), catatan!],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
