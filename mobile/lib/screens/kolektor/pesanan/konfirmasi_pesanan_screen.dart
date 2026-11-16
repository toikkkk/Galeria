import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../models/pesanan.dart';
import '../../../services/pesanan_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../widgets/commerce_widgets.dart';
import '../../../widgets/karya_image.dart';
import '../../../widgets/pesanan_widgets.dart';

/// Checkout satu karya: alamat, rincian barang, ringkasan pembayaran, lalu membuat pesanan di server
/// (`POST /api/pesanan`). Harga & komisi ditentukan server dari harga karya, bukan dari layar ini.
/// Ongkos kirim belum dihitung otomatis (tidak ada integrasi kurir), jadi total = harga karya.
class KonfirmasiPesananScreen extends StatefulWidget {
  const KonfirmasiPesananScreen({
    super.key,
    required this.karya,
    required this.onBack,
    required this.onDibuat,
    AlamatService? alamatService,
    PesananService? pesananService,
  })  : _alamat = alamatService,
        _pesanan = pesananService;

  final Karya karya;
  final VoidCallback onBack;
  final ValueChanged<Pesanan> onDibuat;
  final AlamatService? _alamat;
  final PesananService? _pesanan;

  @override
  State<KonfirmasiPesananScreen> createState() => _KonfirmasiPesananScreenState();
}

class _KonfirmasiPesananScreenState extends State<KonfirmasiPesananScreen> {
  late final AlamatService _alamatService = widget._alamat ?? AlamatService();
  late final PesananService _pesananService = widget._pesanan ?? PesananService();
  List<Alamat> _alamat = [];
  String? _dipilih;
  bool _memuat = true;
  bool _mengirim = false;
  String? _error;

  Alamat? get _alamatTerpilih => _alamat.where((a) => a.id == _dipilih).firstOrNull;

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
      final daftar = await _alamatService.daftar();
      if (!mounted) return;
      setState(() {
        _alamat = daftar;
        _dipilih = daftar.where((a) => a.isUtama).firstOrNull?.id ?? daftar.firstOrNull?.id;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat alamat: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
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

  Future<void> _ubahAlamat() async {
    if (_alamat.isEmpty) return _tambahAlamat();
    final id = await tampilkanPilihAlamat(context, daftar: _alamat, dipilih: _dipilih);
    if (id == null || !mounted) return;
    if (id == kAlamatBaru) return _tambahAlamat();
    setState(() => _dipilih = id);
  }

  Future<void> _buat() async {
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
      final pesanan = await _pesananService.buat(karyaId: widget.karya.id, alamatId: id);
      if (mounted) widget.onDibuat(pesanan);
    } catch (e) {
      if (mounted) {
        setState(() {
          _mengirim = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final karya = widget.karya;
    return Scaffold(
      backgroundColor: kLatarMarketplace,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Konfirmasi Pesanan', style: AppTextStyles.headlineSm),
      ),
      body: Column(
        children: [
          const IndikatorLangkah(aktif: 0),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.sm),
              children: [
                AlamatTile(alamat: _alamatTerpilih, memuat: _memuat, onUbah: _ubahAlamat),
                KartuBagian(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TokoBaris(nama: karya.galleryName.isNotEmpty ? karya.galleryName : karya.artistName),
                      const Divider(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: SizedBox(width: 84, height: 84, child: KaryaImage(karya: karya)),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(karya.title, style: AppTextStyles.labelMd.copyWith(fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                Text(karya.artistName, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    LencanaKecil(karya.styleName, ikon: Icons.palette_outlined, warna: AppColors.onSurfaceVariant),
                                    if (karya.lebarCm != null && karya.tinggiCm != null)
                                      LencanaKecil('${_cm(karya.lebarCm!)} × ${_cm(karya.tinggiCm!)} cm', ikon: Icons.aspect_ratio, warna: AppColors.onSurfaceVariant),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(formatRupiah(karya.priceIdr), style: AppTextStyles.labelMd.copyWith(fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined, size: 18, color: AppColors.primary),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Pengiriman oleh seniman', style: AppTextStyles.labelMd.copyWith(fontSize: 12.5)),
                                  Text('Seniman mengirim lewat kurir dan mengisi nomor resi. Ongkos kirim belum dihitung otomatis.',
                                      style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                KartuBagian(
                  judul: 'Metode Pembayaran',
                  ikon: Icons.account_balance_wallet_outlined,
                  child: const CatatanIkon('Dipilih di langkah berikutnya: Virtual Account BCA, Mandiri, BNI, atau QRIS.', ikon: Icons.payments_outlined),
                ),
                KartuBagian(
                  judul: 'Ringkasan Pembayaran',
                  ikon: Icons.receipt_long_outlined,
                  child: Column(
                    children: [
                      BarisHarga('Subtotal karya', formatRupiah(karya.priceIdr)),
                      const BarisHarga('Ongkos kirim', 'Belum dihitung'),
                      const Divider(height: AppSpacing.md),
                      BarisHarga('Total Pembayaran', formatRupiah(karya.priceIdr), tebal: true),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                  child: CatatanIkon(
                    'Setelah pesanan selesai, karya tercatat atas namamu di GALERIA beserta sertifikat digital keaslian bila tersedia.',
                    ikon: Icons.verified_user_outlined,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                  if (_alamat.isEmpty && !_memuat) TextButton(onPressed: _muat, child: const Text('Muat ulang alamat')),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BarBawah(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total', style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
                  Text(formatRupiah(karya.priceIdr), style: AppTextStyles.headlineMd.copyWith(fontSize: 19, color: AppColors.onSurface)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: ElevatedButton(
                onPressed: (_mengirim || _memuat) ? null : _buat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onSurface,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
                child: _mengirim
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Buat Pesanan & Lanjut Bayar', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _cm(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');
}
