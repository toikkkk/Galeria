import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pesanan.dart';
import '../theme/app_theme.dart';

/// Latar layar bergaya marketplace: abu-abu hangat, kartu putih di atasnya.
const kLatarMarketplace = AppColors.surfaceContainerLow;

/// Kartu bagian putih bergaris tipis (pola "section" Tokopedia/Shopee): judul kecil + isi.
class KartuBagian extends StatelessWidget {
  const KartuBagian({
    super.key,
    this.judul,
    this.ikon,
    this.aksi,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin = const EdgeInsets.only(bottom: AppSpacing.xs),
  });

  final String? judul;
  final IconData? ikon;
  final Widget? aksi;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (judul != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, 0),
              child: Row(
                children: [
                  if (ikon != null) ...[Icon(ikon, size: 17, color: AppColors.accent), const SizedBox(width: 6)],
                  Expanded(child: Text(judul!, style: AppTextStyles.labelMd.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ?aksi,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Baris "label ........ nilai" untuk rincian harga.
class BarisHarga extends StatelessWidget {
  const BarisHarga(this.label, this.nilai, {super.key, this.tebal = false, this.warna, this.catatan});

  final String label, nilai;
  final bool tebal;
  final Color? warna;
  final String? catatan;

  @override
  Widget build(BuildContext context) {
    final gaya = tebal ? AppTextStyles.labelMd.copyWith(fontSize: 14) : AppTextStyles.bodySm.copyWith(fontSize: 12.5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: gaya),
                if (catatan != null) Text(catatan!, style: AppTextStyles.bodySm.copyWith(fontSize: 10.5, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(nilai, style: gaya.copyWith(color: warna ?? gaya.color)),
        ],
      ),
    );
  }
}

/// Baris toko/seniman di atas barang (ikon toko + nama + lencana).
class TokoBaris extends StatelessWidget {
  const TokoBaris({super.key, required this.nama, this.lencana = 'Seniman', this.trailing, this.onTap});

  final String nama;
  final String? lencana;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(child: Text(nama, style: AppTextStyles.labelMd.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (lencana != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(4)),
              child: Text(lencana!, style: AppTextStyles.overline.copyWith(fontSize: 8.5, color: const Color(0xFF6B5410))),
            ),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Lencana kecil berwarna ("Terverifikasi", "Lelang", dst.).
class LencanaKecil extends StatelessWidget {
  const LencanaKecil(this.teks, {super.key, this.ikon, this.warna = AppColors.accent});

  final String teks;
  final IconData? ikon;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: warna.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ikon != null) ...[Icon(ikon, size: 12, color: warna), const SizedBox(width: 3)],
          Text(teks, style: AppTextStyles.labelSm.copyWith(fontSize: 10.5, color: warna)),
        ],
      ),
    );
  }
}

/// Hitung mundur "HH:MM:SS" (atau "N hari HH:MM:SS") menuju [batas]; memanggil [onHabis] sekali bila lewat.
class HitungMundurBatas extends StatefulWidget {
  const HitungMundurBatas({super.key, required this.batas, this.gaya, this.onHabis});

  final DateTime batas;
  final TextStyle? gaya;
  final VoidCallback? onHabis;

  @override
  State<HitungMundurBatas> createState() => _HitungMundurBatasState();
}

class _HitungMundurBatasState extends State<HitungMundurBatas> {
  Timer? _t;
  late Duration _sisa = _hitung();
  bool _habisDilapor = false;

  Duration _hitung() => widget.batas.difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    if (!_sisa.isNegative) {
      _t = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _sisa = _hitung());
        if (_sisa.isNegative) {
          _t?.cancel();
          if (!_habisDilapor) {
            _habisDilapor = true;
            widget.onHabis?.call();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _sisa.isNegative ? Duration.zero : _sisa;
    String dua(int n) => n.toString().padLeft(2, '0');
    final jam = d.inHours % 24;
    final hari = d.inDays;
    final teks = '${hari > 0 ? '$hari hari ' : ''}${dua(jam)}:${dua(d.inMinutes % 60)}:${dua(d.inSeconds % 60)}';
    return Text(teks, style: widget.gaya ?? AppTextStyles.labelMd.copyWith(fontFeatures: const [FontFeature.tabularFigures()]));
  }
}

/// Spanduk status besar di atas detail pesanan/pembayaran.
class BannerStatus extends StatelessWidget {
  const BannerStatus({super.key, required this.warna, required this.ikon, required this.judul, this.subjudul, this.trailing});

  final Color warna;
  final IconData ikon;
  final String judul;
  final String? subjudul;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [warna, Color.lerp(warna, Colors.black, 0.28)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Icon(ikon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul, style: AppTextStyles.headlineSm.copyWith(color: Colors.white, fontSize: 16)),
                if (subjudul != null) Text(subjudul!, style: AppTextStyles.bodySm.copyWith(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Satu langkah pada [LangkahVertikal].
class LangkahItem {
  const LangkahItem(this.judul, {this.waktu, this.keterangan, this.batal = false});

  final String judul;
  final String? waktu, keterangan;
  final bool batal;

  bool get selesai => waktu != null;
}

/// Garis waktu vertikal (pelacakan pesanan ala Shopee): titik terisi + garis penghubung.
class LangkahVertikal extends StatelessWidget {
  const LangkahVertikal(this.langkah, {super.key});

  final List<LangkahItem> langkah;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < langkah.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 22,
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: langkah[i].batal ? AppColors.error : (langkah[i].selesai ? AppColors.accent : Colors.white),
                          border: Border.all(color: langkah[i].batal ? AppColors.error : (langkah[i].selesai ? AppColors.accent : AppColors.outlineVariant), width: 2),
                        ),
                        child: (langkah[i].selesai || langkah[i].batal) ? const Icon(Icons.check, size: 9, color: Colors.white) : null,
                      ),
                      if (i < langkah.length - 1)
                        Expanded(
                          child: Container(width: 2, color: (langkah[i].selesai && langkah[i + 1].selesai) ? AppColors.accent : AppColors.border),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          langkah[i].judul,
                          style: AppTextStyles.labelMd.copyWith(
                            fontSize: 12.5,
                            color: langkah[i].batal ? AppColors.error : (langkah[i].selesai ? AppColors.onSurface : AppColors.muted),
                          ),
                        ),
                        if (langkah[i].keterangan != null) Text(langkah[i].keterangan!, style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted)),
                        if (langkah[i].waktu != null) Text(langkah[i].waktu!, style: AppTextStyles.bodySm.copyWith(fontSize: 10.5, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bilah aksi lengket di bawah layar (total di kiri, tombol di kanan).
class BarBawah extends StatelessWidget {
  const BarBawah({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2), child: child),
      ),
    );
  }
}

/// Teks bantuan kecil dengan ikon di depan (info/aman/peringatan).
class CatatanIkon extends StatelessWidget {
  const CatatanIkon(this.teks, {super.key, this.ikon = Icons.info_outline, this.warna = AppColors.muted});

  final String teks;
  final IconData ikon;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(ikon, size: 14, color: warna)),
        const SizedBox(width: 6),
        Expanded(child: Text(teks, style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: warna))),
      ],
    );
  }
}

/// Ringkasan alamat terpilih + tombol "Ubah" (membuka daftar alamat). Pola Shopee: satu baris, bukan daftar panjang.
class AlamatTile extends StatelessWidget {
  const AlamatTile({super.key, required this.alamat, required this.onUbah, this.memuat = false});

  final Alamat? alamat;
  final VoidCallback onUbah;
  final bool memuat;

  @override
  Widget build(BuildContext context) {
    final a = alamat;
    return KartuBagian(
      judul: 'Alamat Pengiriman',
      ikon: Icons.location_on_outlined,
      aksi: TextButton(
        onPressed: memuat ? null : onUbah,
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        child: Text(a == null ? 'Tambah' : 'Ubah'),
      ),
      child: memuat
          ? const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.xs), child: CircularProgressIndicator(strokeWidth: 2)))
          : a == null
              ? Text('Kamu belum punya alamat pengiriman.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(a.label, style: AppTextStyles.labelMd),
                        if (a.isUtama) ...[const SizedBox(width: 6), const LencanaKecil('Utama')],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${a.namaPenerima} · ${a.telepon}', style: AppTextStyles.bodySm.copyWith(fontSize: 12, color: AppColors.onSurface)),
                    Text(a.ringkas, style: AppTextStyles.bodySm.copyWith(fontSize: 11.5, color: AppColors.muted)),
                  ],
                ),
    );
  }
}

/// Daftar alamat sebagai bottom sheet. Mengembalikan id alamat terpilih, [kAlamatBaru] untuk "tambah alamat baru", atau null.
const kAlamatBaru = '__alamat_baru__';

Future<String?> tampilkanPilihAlamat(BuildContext context, {required List<Alamat> daftar, required String? dipilih}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pilih Alamat Pengiriman', style: AppTextStyles.headlineSm),
              const SizedBox(height: AppSpacing.xs),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final a in daftar)
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx, a.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: dipilih == a.id ? AppColors.accent : AppColors.border, width: dipilih == a.id ? 1.6 : 1),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(dipilih == a.id ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: dipilih == a.id ? AppColors.accent : AppColors.muted),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${a.label}${a.isUtama ? ' · Utama' : ''}', style: AppTextStyles.labelMd),
                                    Text('${a.namaPenerima} · ${a.telepon}', style: AppTextStyles.bodySm.copyWith(fontSize: 11.5)),
                                    Text(a.ringkas, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11.5)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, kAlamatBaru),
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('Tambah alamat baru'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Indikator langkah checkout ("Pesanan > Pembayaran > Selesai") dengan langkah aktif disorot.
class IndikatorLangkah extends StatelessWidget {
  const IndikatorLangkah({super.key, required this.aktif, this.label = const ['Pesanan', 'Pembayaran', 'Selesai']});

  final int aktif;
  final List<String> label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
      child: Row(
        children: [
          for (var i = 0; i < label.length; i++) ...[
            if (i > 0) Expanded(child: Container(height: 2, color: i <= aktif ? AppColors.accent : AppColors.border)),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= aktif ? AppColors.accent : Colors.white,
                    border: Border.all(color: i <= aktif ? AppColors.accent : AppColors.outlineVariant, width: 1.5),
                  ),
                  child: i < aktif
                      ? const Icon(Icons.check, size: 13, color: AppColors.onSurface)
                      : Text('${i + 1}', style: AppTextStyles.labelSm.copyWith(fontSize: 10.5, color: i == aktif ? AppColors.onSurface : AppColors.muted)),
                ),
                const SizedBox(height: 3),
                Text(label[i], style: AppTextStyles.labelSm.copyWith(fontSize: 10, color: i <= aktif ? AppColors.onSurface : AppColors.muted)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
