import 'package:flutter/material.dart';

import '../../models/pesanan.dart';
import '../../services/pesanan_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/format_waktu.dart';
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
    final kurir = TextEditingController(text: 'JNE');
    final resi = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kirim pesanan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: kurir, decoration: const InputDecoration(labelText: 'Kurir')),
            TextField(controller: resi, decoration: const InputDecoration(labelText: 'Nomor resi')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tandai dikirim')),
        ],
      ),
    );
    final k = kurir.text.trim(), r = resi.text.trim();
    kurir.dispose();
    resi.dispose();
    if (ok != true || !mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
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
    );
  }

  Widget _isi(Pesanan p) {
    final langkah = <(String, DateTime?)>[
      ('Pesanan dibuat', p.createdAt),
      ('Dibayar', p.dibayarAt),
      ('Dikonfirmasi seniman', p.dikonfirmasiAt),
      ('Dikirim${p.kurir != null ? ' · ${p.kurir} ${p.noResi}' : ''}', p.dikirimAt),
      ('Diterima, pesanan selesai', p.selesaiAt),
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: [
        _kartu(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PesananGambar(pesanan: p, ukuran: 84),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.kode, style: AppTextStyles.overline.copyWith(fontSize: 9, color: AppColors.outline)),
                    Text(p.judul, style: AppTextStyles.labelMd, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(p.artistName, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                    const SizedBox(height: 6),
                    StatusPesananChip(pesanan: p),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _kartu(
          Column(
            children: [
              _baris('Harga karya', formatRupiah(p.hargaIdr)),
              _baris('Komisi platform', formatRupiah(p.komisiIdr)),
              const Divider(height: AppSpacing.md),
              _baris('Diterima seniman', formatRupiah(p.pendapatanSenimanIdr), tebal: true),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _kartu(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pembeli', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
              Text(p.pembeliNama, style: AppTextStyles.labelMd),
              const SizedBox(height: AppSpacing.xs),
              Text('Penjual', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
              Text(p.penjualNama, style: AppTextStyles.labelMd),
              const SizedBox(height: AppSpacing.xs),
              Text('Dikirim ke', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
              Text(p.alamatRingkas, style: AppTextStyles.bodySm),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Perjalanan Pesanan', style: AppTextStyles.headlineSm),
        const SizedBox(height: AppSpacing.xs),
        for (final l in langkah)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(l.$2 != null ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: l.$2 != null ? AppColors.accent : AppColors.outline),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(l.$1, style: AppTextStyles.bodySm.copyWith(color: l.$2 != null ? null : AppColors.muted))),
                if (l.$2 != null) Text(formatTanggal(l.$2!), style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
        if (p.dibatalkanAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Icon(Icons.cancel, size: 18, color: AppColors.error),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text('Dibatalkan', style: AppTextStyles.bodySm.copyWith(color: AppColors.error))),
                Text(formatTanggal(p.dibatalkanAt!), style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        if (p.bisa('bayar'))
          _tombol('Bayar sekarang', Icons.payments_outlined, () => widget.onBayar?.call(p)),
        if (p.bisa('konfirmasi'))
          _tombol('Konfirmasi pesanan', Icons.check, () => _aksi(() => _service.konfirmasi(p.id), berhasil: 'Pesanan dikonfirmasi. Silakan kemas dan kirim karya.')),
        if (p.bisa('kirim')) _tombol('Tandai dikirim + resi', Icons.local_shipping_outlined, () => _dialogKirim(p)),
        if (p.bisa('terima')) _tombol('Karya sudah saya terima', Icons.inventory_2_outlined, () => _konfirmasiTerima(p)),
        if (p.bisa('batal'))
          TextButton(
            onPressed: _sibuk ? null : () => _aksi(() => _service.batal(p.id), berhasil: 'Pesanan dibatalkan.'),
            child: const Text('Batalkan pesanan', style: TextStyle(color: AppColors.error)),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _tombol(String label, IconData ikon, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(onPressed: _sibuk ? null : onTap, icon: Icon(ikon, size: 18), label: Text(label)),
        ),
      );

  Widget _kartu(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: child,
      );

  Widget _baris(String l, String v, {bool tebal = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: tebal ? AppTextStyles.labelMd : AppTextStyles.bodySm),
            Text(v, style: tebal ? AppTextStyles.labelMd : AppTextStyles.bodySm),
          ],
        ),
      );
}
