import 'package:flutter/material.dart';

import '../../../models/pesanan.dart';
import '../../../services/keranjang_service.dart';
import '../../../services/pesanan_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../widgets/commerce_widgets.dart';
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

  Alamat? get _alamatTerpilih => _alamat.where((a) => a.id == _dipilih).firstOrNull;

  Future<void> _ubahAlamat() async {
    if (_alamat.isEmpty) return _tambahAlamat();
    final id = await tampilkanPilihAlamat(context, daftar: _alamat, dipilih: _dipilih);
    if (id == null || !mounted) return;
    if (id == kAlamatBaru) return _tambahAlamat();
    setState(() => _dipilih = id);
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

  Widget _baris(ItemKeranjang item) {
    final k = item.karya;
    return Opacity(
      opacity: item.tersedia ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => widget.onKaryaTap(item),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(width: 76, height: 92, child: KaryaImage(karya: k)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k.title, style: AppTextStyles.labelMd.copyWith(fontSize: 13.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      LencanaKecil(k.styleName, ikon: Icons.palette_outlined, warna: AppColors.onSurfaceVariant),
                      if (k.lebarCm != null && k.tinggiCm != null)
                        LencanaKecil('${_cm(k.lebarCm!)} × ${_cm(k.tinggiCm!)} cm', ikon: Icons.aspect_ratio, warna: AppColors.onSurfaceVariant),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Text(formatRupiah(k.priceIdr), style: AppTextStyles.labelMd.copyWith(fontSize: 14))),
                      IconButton(
                        key: Key('hapus_${k.id}'),
                        onPressed: () => _hapus(item),
                        tooltip: 'Keluarkan dari keranjang',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline, size: 22, color: AppColors.muted),
                      ),
                    ],
                  ),
                  if (!item.tersedia && item.alasan != null)
                    Text(item.alasan!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kelompokkan per toko/seniman, seperti keranjang Shopee.
  List<Widget> _kelompok(List<ItemKeranjang> items) {
    final grup = <String, List<ItemKeranjang>>{};
    for (final i in items) {
      final nama = i.karya.galleryName.isNotEmpty ? i.karya.galleryName : i.karya.artistName;
      grup.putIfAbsent(nama, () => []).add(i);
    }
    return [
      for (final e in grup.entries)
        KartuBagian(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
          child: Column(
            children: [
              TokoBaris(nama: e.key),
              const Divider(height: AppSpacing.sm),
              for (var n = 0; n < e.value.length; n++) ...[
                if (n > 0) const Divider(height: 1),
                _baris(e.value[n]),
              ],
            ],
          ),
        ),
    ];
  }

  static String _cm(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final adaIsi = d != null && d.items.isNotEmpty;
    final bisaPesan = d != null && d.jumlahTersedia > 0;
    return Scaffold(
      backgroundColor: kLatarMarketplace,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text(adaIsi ? 'Keranjang (${d.items.length})' : 'Keranjang', style: AppTextStyles.headlineSm),
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
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        children: [
                          ..._kelompok(d.items),
                          AlamatTile(alamat: _alamatTerpilih, onUbah: _ubahAlamat),
                          KartuBagian(
                            judul: 'Ringkasan Belanja',
                            ikon: Icons.receipt_long_outlined,
                            child: Column(
                              children: [
                                BarisHarga('Subtotal (${d.jumlahTersedia} karya)', formatRupiah(d.totalIdr)),
                                const BarisHarga('Ongkos kirim', 'Belum dihitung'),
                                const Divider(height: AppSpacing.md),
                                BarisHarga('Total', formatRupiah(d.totalIdr), tebal: true),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                            child: CatatanIkon('Tiap karya menjadi satu pesanan sendiri (karya seni itu unik) dan dibayar satu per satu.'),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
      bottomNavigationBar: adaIsi
          ? BarBawah(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('TOTAL (${d.jumlahTersedia} karya)', style: AppTextStyles.overline.copyWith(color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(formatRupiah(d.totalIdr), style: AppTextStyles.headlineMd.copyWith(fontSize: 19)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    key: const Key('checkout_keranjang'),
                    onPressed: (_mengirim || !bisaPesan) ? null : _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onSurface,
                      minimumSize: const Size(0, 48),
                      maximumSize: const Size(200, 48),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    ),
                    child: _mengirim
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Pesan Sekarang', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
