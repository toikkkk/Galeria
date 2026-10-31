import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../models/pesanan.dart';
import '../../../services/pesanan_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../widgets/karya_image.dart';
import '../../../widgets/pesanan_widgets.dart';

/// Konfirmasi pesanan: ringkasan karya + pilih alamat pengiriman, lalu membuat pesanan di server
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Konfirmasi Pesanan', style: AppTextStyles.headlineSm),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: [
          _kartu(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: SizedBox(width: 80, height: 80, child: KaryaImage(karya: karya)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(karya.title, style: AppTextStyles.labelMd, maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(karya.artistName, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                      const SizedBox(height: 4),
                      Text(formatRupiah(karya.priceIdr), style: AppTextStyles.labelMd),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Alamat Pengiriman', style: AppTextStyles.headlineSm),
              TextButton.icon(
                onPressed: _memuat ? null : _tambahAlamat,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah'),
              ),
            ],
          ),
          if (_memuat)
            const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Center(child: CircularProgressIndicator()))
          else if (_alamat.isEmpty)
            _kartu(
              child: Column(
                children: [
                  Text(
                    'Kamu belum punya alamat pengiriman.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  OutlinedButton.icon(
                    onPressed: _tambahAlamat,
                    icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                    label: const Text('Tambah alamat'),
                  ),
                ],
              ),
            )
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
                      Icon(
                        _dipilih == a.id ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 20,
                        color: _dipilih == a.id ? AppColors.accent : AppColors.muted,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(a.label, style: AppTextStyles.labelMd),
                                if (a.isUtama) ...[
                                  const SizedBox(width: 6),
                                  Text('UTAMA', style: AppTextStyles.overline.copyWith(fontSize: 8, color: AppColors.accent)),
                                ],
                              ],
                            ),
                            Text('${a.namaPenerima} · ${a.telepon}', style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
                            Text(a.ringkas, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.md),
          Text('Ringkasan Pembayaran', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.xs),
          _kartu(
            child: Column(
              children: [
                _baris('Harga karya', formatRupiah(karya.priceIdr)),
                const Divider(height: AppSpacing.md),
                _baris('Total', formatRupiah(karya.priceIdr), tebal: true),
                const SizedBox(height: 6),
                Text(
                  'Ongkos kirim belum dihitung otomatis di versi ini; atur bersama seniman bila diperlukan.',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
            if (_alamat.isEmpty && !_memuat)
              TextButton(onPressed: _muat, child: const Text('Muat ulang alamat')),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_mengirim || _memuat) ? null : _buat,
              child: _mengirim
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Buat Pesanan & Lanjut Bayar'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _kartu({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: child,
      );

  Widget _baris(String l, String v, {bool tebal = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: tebal ? AppTextStyles.labelMd : AppTextStyles.bodySm),
          Text(v, style: tebal ? AppTextStyles.labelMd : AppTextStyles.bodySm),
        ],
      );
}
