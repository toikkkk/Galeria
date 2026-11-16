import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/pesanan.dart';
import '../../services/auth_service.dart';
import '../../services/pesanan_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/format_waktu.dart';
import '../../widgets/commerce_widgets.dart';
import '../../widgets/kolektor/tulis_ulasan_sheet.dart';
import '../../widgets/pesanan_widgets.dart';

/// Detail satu pesanan, dipakai kolektor DAN seniman. Tombol yang muncul ditentukan server (`aksi`),
/// jadi layar ini tidak menebak siapa boleh melakukan apa.
class DetailPesananScreen extends StatefulWidget {
  const DetailPesananScreen({
    super.key,
    required this.pesananId,
    required this.onBack,
    this.onBayar,
    PesananService? service,
  }) : _service = service;

  final String pesananId;
  final VoidCallback onBack;

  /// Kolektor menekan "Bayar sekarang" (membuka layar pembayaran).
  final ValueChanged<Pesanan>? onBayar;
  final PesananService? _service;

  @override
  State<DetailPesananScreen> createState() => _DetailPesananScreenState();
}

class _DetailPesananScreenState extends State<DetailPesananScreen> {
  late final PesananService _service = widget._service ?? PesananService();
  Pesanan? _p;
  bool _memuat = true;
  bool _sibuk = false;
  String? _error;

  bool get _sebagaiPenjual => AuthService.instance.user?.isSeniman ?? false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final p = await _service.detail(widget.pesananId);
      if (mounted) setState(() => _p = p);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat pesanan: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _aksi(Future<Pesanan> Function() kerja, {String? berhasil}) async {
    setState(() => _sibuk = true);
    try {
      final baru = await kerja();
      if (!mounted) return;
      setState(() => _p = baru);
      if (berhasil != null) tampilkanPesan(context, berhasil);
    } catch (e) {
      if (mounted) tampilkanPesan(context, e.toString());
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _dialogKirim(Pesanan p) async {
    final hasil = await tampilkanDialogKirim(context);
    if (hasil == null || !mounted) return;
    final (k, r) = hasil;
    await _aksi(() => _service.kirim(p.id, kurir: k, noResi: r), berhasil: 'Pesanan ditandai dikirim.');
  }

  Future<void> _konfirmasiTerima(Pesanan p) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Karya sudah diterima?'),
        content: const Text('Pastikan karya sudah kamu terima dan kondisinya baik. Setelah ini pesanan selesai dan kepemilikan karya tercatat atas namamu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Belum')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, sudah diterima')),
        ],
      ),
    );
    if (ya == true) await _aksi(() => _service.terima(p.id), berhasil: 'Pesanan selesai. Karya kini tercatat milikmu.');
  }

  Future<void> _tulisUlasan(Pesanan p) async {
    final terkirim = await tampilkanTulisUlasan(context, pesananId: p.id, judulKarya: p.judul);
    if (!terkirim || !mounted) return;
    tampilkanPesan(context, 'Terima kasih! Ulasanmu tersimpan dan akan dianalisis.');
    await _muat();
  }

  Future<void> _salin(String teks, String pesan) async {
    await Clipboard.setData(ClipboardData(text: teks));
    if (mounted) tampilkanPesan(context, pesan);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: kLatarMarketplace,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Detail Pesanan', style: AppTextStyles.headlineSm),
        actions: [IconButton(onPressed: _memuat ? null : _muat, icon: const Icon(Icons.refresh))],
      ),
      body: _memuat && p == null
          ? const Center(child: CircularProgressIndicator())
          : p == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'Pesanan tidak ditemukan.', textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(onPressed: _muat, child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(onRefresh: _muat, child: _isi(p)),
      bottomNavigationBar: (p == null) ? null : _barAksi(p),
    );
  }

  /// Tombol utama menurut `aksi` dari server (maks. dua, ditaruh di bilah bawah).
  Widget? _barAksi(Pesanan p) {
    final tombol = <Widget>[
      if (p.bisa('bayar')) _tombol('Bayar sekarang', Icons.payments_outlined, () => widget.onBayar?.call(p)),
      if (p.bisa('konfirmasi'))
        _tombol('Konfirmasi pesanan', Icons.check, () => _aksi(() => _service.konfirmasi(p.id), berhasil: 'Pesanan dikonfirmasi. Silakan kemas dan kirim karya.')),
      if (p.bisa('kirim')) _tombol('Tandai dikirim + resi', Icons.local_shipping_outlined, () => _dialogKirim(p)),
      if (p.bisa('terima')) _tombol('Karya sudah saya terima', Icons.inventory_2_outlined, () => _konfirmasiTerima(p)),
      if (p.bisa('ulas')) _tombol('Tulis ulasan', Icons.rate_review_outlined, () => _tulisUlasan(p)),
    ];
    if (tombol.isEmpty) return null;
    return BarBawah(child: Row(children: [for (final t in tombol) Expanded(child: t)]));
  }

  Widget _tombol(String label, IconData ikon, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ElevatedButton.icon(
          onPressed: _sibuk ? null : onTap,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.onSurface, minimumSize: const Size(0, 48)),
          icon: Icon(ikon, size: 18),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );

  BannerStatus _banner(Pesanan p) {
    final (warna, ikon) = tampilanStatusPesanan(p);
    final penjual = _sebagaiPenjual;
    switch (p.status) {
      case 'menunggu_pembayaran':
        return BannerStatus(
          warna: warna,
          ikon: ikon,
          judul: 'Menunggu pembayaran',
          subjudul: penjual ? 'Pembeli belum membayar.' : 'Selesaikan pembayaran sebelum batas waktu.',
          trailing: p.batasBayarAt == null ? null : HitungMundurBatas(batas: p.batasBayarAt!, gaya: AppTextStyles.labelMd.copyWith(color: Colors.white)),
        );
      case 'dibayar':
        return BannerStatus(
          warna: warna,
          ikon: ikon,
          judul: penjual ? 'Pesanan baru dibayar' : 'Pembayaran diterima',
          subjudul: penjual ? 'Konfirmasi pesanan ini lalu kemas karya.' : 'Menunggu seniman mengonfirmasi pesananmu.',
        );
      case 'dikonfirmasi':
        return p.sudahDikirim
            ? BannerStatus(
                warna: warna,
                ikon: ikon,
                judul: 'Pesanan dikirim',
                subjudul: p.kurir != null ? '${p.kurir} · ${p.noResi ?? '-'}' : 'Karya dalam perjalanan.',
              )
            : BannerStatus(warna: warna, ikon: ikon, judul: 'Pesanan diproses', subjudul: penjual ? 'Kemas karya dan isi nomor resi.' : 'Seniman sedang menyiapkan karyamu.');
      case 'selesai':
        return BannerStatus(warna: warna, ikon: ikon, judul: 'Pesanan selesai', subjudul: penjual ? 'Pendapatan dicatat setelah komisi.' : 'Karya kini tercatat atas namamu.');
      default:
        return BannerStatus(warna: warna, ikon: ikon, judul: 'Pesanan dibatalkan', subjudul: 'Karya tersedia kembali di katalog.');
    }
  }

  Widget _isi(Pesanan p) {
    final penjual = _sebagaiPenjual;
    final langkah = <LangkahItem>[
      LangkahItem('Pesanan dibuat', waktu: formatTanggalJam(p.createdAt)),
      LangkahItem('Pembayaran diterima', waktu: p.dibayarAt == null ? null : formatTanggalJam(p.dibayarAt!)),
      LangkahItem('Dikonfirmasi seniman', waktu: p.dikonfirmasiAt == null ? null : formatTanggalJam(p.dikonfirmasiAt!)),
      LangkahItem(
        'Dikirim',
        waktu: p.dikirimAt == null ? null : formatTanggalJam(p.dikirimAt!),
        keterangan: p.kurir != null ? '${p.kurir} · ${p.noResi ?? '-'}' : null,
      ),
      LangkahItem('Diterima, pesanan selesai', waktu: p.selesaiAt == null ? null : formatTanggalJam(p.selesaiAt!)),
      if (p.dibatalkanAt != null) LangkahItem('Dibatalkan', waktu: formatTanggalJam(p.dibatalkanAt!), batal: true),
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.sm),
      children: [
        _banner(p),
        const SizedBox(height: AppSpacing.xs),
        KartuBagian(
          judul: 'Pelacakan Pesanan',
          ikon: Icons.timeline,
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          child: LangkahVertikal(langkah),
        ),
        KartuBagian(
          judul: 'Info Pengiriman',
          ikon: Icons.local_shipping_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.kurir != null && p.noResi != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kurir ${p.kurir}', style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
                          Text(p.noResi!, style: AppTextStyles.labelMd.copyWith(letterSpacing: 0.6)),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () => _salin(p.noResi!, 'Nomor resi disalin.'), child: const Text('Salin')),
                  ],
                ),
                const Divider(height: AppSpacing.md),
              ],
              Text('Alamat tujuan', style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
              const SizedBox(height: 2),
              Text(p.alamatRingkas, style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurface, fontSize: 12.5)),
            ],
          ),
        ),
        KartuBagian(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TokoBaris(nama: p.penjualNama),
              const Divider(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PesananGambar(pesanan: p, ukuran: 84),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.judul, style: AppTextStyles.labelMd.copyWith(fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(p.artistName, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            LencanaKecil(p.styleName, ikon: Icons.palette_outlined, warna: AppColors.onSurfaceVariant),
                            if (p.dariLelang) const LencanaKecil('Lelang', ikon: Icons.gavel),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        KartuBagian(
          judul: 'Rincian Pembayaran',
          ikon: Icons.receipt_long_outlined,
          child: Column(
            children: [
              BarisHarga('Harga karya', formatRupiah(p.hargaIdr)),
              if (penjual) ...[
                BarisHarga('Komisi platform', '-${formatRupiah(p.komisiIdr)}'),
                const Divider(height: AppSpacing.md),
                BarisHarga('Pendapatan seniman', formatRupiah(p.pendapatanSenimanIdr), tebal: true, warna: AppColors.success),
              ] else ...[
                const BarisHarga('Ongkos kirim', 'Belum dihitung'),
                const Divider(height: AppSpacing.md),
                BarisHarga('Total Pembayaran', formatRupiah(p.hargaIdr), tebal: true),
              ],
            ],
          ),
        ),
        KartuBagian(
          judul: 'Info Pesanan',
          ikon: Icons.info_outline,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text('No. pesanan', style: AppTextStyles.bodySm)),
                  Text(p.kode, style: AppTextStyles.labelMd.copyWith(fontSize: 12.5)),
                  IconButton(onPressed: () => _salin(p.kode, 'Nomor pesanan disalin.'), icon: const Icon(Icons.copy, size: 15), visualDensity: VisualDensity.compact),
                ],
              ),
              BarisHarga('Pembeli', p.pembeliNama),
              BarisHarga('Penjual', p.penjualNama),
              BarisHarga('Dibuat', formatTanggalJam(p.createdAt)),
            ],
          ),
        ),
        if (p.sudahDiulas)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: CatatanIkon('Kamu sudah mengulas pesanan ini.', ikon: Icons.check_circle, warna: AppColors.accent),
          ),
        if (p.bisa('batal'))
          Center(
            child: TextButton(
              onPressed: _sibuk ? null : () => _aksi(() => _service.batal(p.id), berhasil: 'Pesanan dibatalkan.'),
              child: const Text('Batalkan pesanan', style: TextStyle(color: AppColors.error)),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
