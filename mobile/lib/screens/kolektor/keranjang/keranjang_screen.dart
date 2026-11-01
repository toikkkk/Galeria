import 'package:flutter/material.dart';

import '../../../models/pesanan.dart';
import '../../../services/keranjang_service.dart';
import '../../../services/pesanan_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../widgets/karya_image.dart';
import '../../../widgets/pesanan_widgets.dart';

/// Keranjang kolektor. Karya seni itu unik (stok 1), jadi tidak ada jumlah. Checkout membuat SATU pesanan
/// per karya (tiap karya = transaksi bertanda tangan sendiri) ke alamat yang dipilih; pembayaran tetap per pesanan.
class KeranjangScreen extends StatefulWidget {
  const KeranjangScreen({
    super.key,
    required this.onBack,
    required this.onKaryaTap,
    required this.onSelesai,
    KeranjangService? service,
    AlamatService? alamatService,
  })  : _service = service,
        _alamat = alamatService;

  final VoidCallback onBack;
  final ValueChanged<ItemKeranjang> onKaryaTap;

  /// Dipanggil setelah checkout (minimal satu pesanan berhasil dibuat).
  final ValueChanged<HasilCheckout> onSelesai;
  final KeranjangService? _service;
  final AlamatService? _alamat;

  @override
  State<KeranjangScreen> createState() => _KeranjangScreenState();
}

class _KeranjangScreenState extends State<KeranjangScreen> {
  late final KeranjangService _service = widget._service ?? KeranjangService();
  late final AlamatService _alamatService = widget._alamat ?? AlamatService();
  Keranjang? _data;
  List<Alamat> _alamat = [];
  String? _dipilih;
  bool _memuat = true;
  bool _mengirim = false;
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
      final hasil = await Future.wait([_service.lihat(), _alamatService.daftar()]);
      if (!mounted) return;
      final k = hasil[0] as Keranjang;
      final a = hasil[1] as List<Alamat>;
      setState(() {
        _data = k;
        _alamat = a;
        _dipilih ??= a.isEmpty ? null : (a.firstWhere((x) => x.isUtama, orElse: () => a.first)).id;
      });
      KeranjangStore.instance.setelahPerubahan(k.items.map((i) => i.karya.id));
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat keranjang: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _hapus(ItemKeranjang item) async {
    try {
      await _service.hapus(item.karya.id);
      await _muat();
    } catch (e) {
      if (mounted) tampilkanPesan(context, e.toString());
    }
  }

  Future<void> _kosongkan() async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kosongkan keranjang?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kosongkan')),
        ],
      ),
    );
    if (ya != true) return;
    try {
      await _service.kosongkan();
      await _muat();
    } catch (e) {
      if (mounted) tampilkanPesan(context, e.toString());
    }
  }

  Future<void> _tambahAlamat() async {
    final baru = await tampilkanFormAlamat(context, service: _alamatService);
    if (baru == null || !mounted) return;
    setState(() {
      _alamat = [..._alamat, baru];
      _dipilih = baru.id;
    });
  }

  Future<void> _checkout() async {
    final id = _dipilih;
    if (id == null) {
      tampilkanPesan(context, 'Pilih atau tambahkan alamat pengiriman dulu.');
      return;
    }
    setState(() {
      _mengirim = true;
      _error = null;
    });
    try {
      final hasil = await _service.checkout(id);
      if (!mounted) return;
      await _muat();
      if (!mounted) return;
      setState(() => _mengirim = false); // jangan biarkan tombol berputar di belakang dialog
      if (hasil.gagal.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(hasil.pesanan.isEmpty ? 'Tidak ada pesanan dibuat' : '${hasil.pesanan.length} pesanan dibuat'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Beberapa karya tidak bisa dipesan dan tetap di keranjang:', style: AppTextStyles.bodySm),
                const SizedBox(height: 8),
                for (final g in hasil.gagal) Text('• ${g.judul}: ${g.alasan}', style: AppTextStyles.bodySm.copyWith(fontSize: 12)),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mengerti'))],
          ),
        );
      }
      if (hasil.pesanan.isNotEmpty && mounted) widget.onSelesai(hasil);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  Widget _kartuItem(ItemKeranjang item) {
    final k = item.karya;
    final redup = !item.tersedia;
    return Opacity(
      opacity: redup ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => widget.onKaryaTap(item),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(width: 64, height: 78, child: KaryaImage(karya: k)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k.title, style: AppTextStyles.labelMd, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(k.artistName, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(formatRupiah(k.priceIdr), style: AppTextStyles.labelMd.copyWith(fontSize: 13)),
                  if (!item.tersedia && item.alasan != null)
                    Text(item.alasan!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error, fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              key: Key('hapus_${k.id}'),
              onPressed: () => _hapus(item),
              tooltip: 'Keluarkan dari keranjang',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pilihAlamat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text('Alamat Pengiriman', style: AppTextStyles.headlineSm, maxLines: 1, overflow: TextOverflow.ellipsis)),
            TextButton.icon(onPressed: _tambahAlamat, icon: const Icon(Icons.add, size: 18), label: const Text('Tambah')),
          ],
        ),
        if (_alamat.isEmpty)
          Text('Kamu belum punya alamat pengiriman.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted))
        else
          for (final a in _alamat)
            GestureDetector(
              onTap: () => setState(() => _dipilih = a.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: _dipilih == a.id ? AppColors.accent : AppColors.border, width: _dipilih == a.id ? 1.6 : 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_dipilih == a.id ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: _dipilih == a.id ? AppColors.accent : AppColors.muted),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.label, style: AppTextStyles.labelMd),
                          Text('${a.namaPenerima} · ${a.telepon}', style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
                          Text(a.ringkas, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final adaIsi = d != null && d.items.isNotEmpty;
    final bisaPesan = d != null && d.jumlahTersedia > 0;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Keranjang', style: AppTextStyles.headlineSm),
        actions: [if (adaIsi) TextButton(onPressed: _kosongkan, child: const Text('Kosongkan'))],
      ),
      body: _memuat && d == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && d == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                        const SizedBox(height: AppSpacing.xs),
                        OutlinedButton.icon(onPressed: _muat, icon: const Icon(Icons.refresh, size: 16), label: const Text('Coba Lagi')),
                      ],
                    ),
                  ),
                )
              : !adaIsi
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_cart_outlined, size: 48, color: AppColors.muted),
                            const SizedBox(height: AppSpacing.xs),
                            Text('Keranjangmu masih kosong.', style: AppTextStyles.headlineSm),
                            const SizedBox(height: 4),
                            Text('Buka sebuah karya lalu ketuk ikon keranjang untuk menyimpannya di sini.', textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _muat,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter, AppSpacing.sm, AppSpacing.screenGutter, AppSpacing.xxl),
                        children: [
                          for (final i in d.items) _kartuItem(i),
                          const SizedBox(height: AppSpacing.sm),
                          _pilihAlamat(),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Tiap karya menjadi satu pesanan sendiri dan dibayar satu per satu. Ongkos kirim belum dihitung otomatis di versi ini.',
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                          ],
                        ],
                      ),
                    ),
      bottomNavigationBar: adaIsi
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter, vertical: AppSpacing.sm),
                decoration: const BoxDecoration(color: AppColors.surfaceContainerLowest, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)]),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('TOTAL (${d.jumlahTersedia} karya)', style: AppTextStyles.overline.copyWith(color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(formatRupiah(d.totalIdr), style: AppTextStyles.headlineMd),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      key: const Key('checkout_keranjang'),
                      onPressed: (_mengirim || !bisaPesan) ? null : _checkout,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48), maximumSize: const Size(200, 48), padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md)),
                      child: _mengirim
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Pesan Sekarang', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
