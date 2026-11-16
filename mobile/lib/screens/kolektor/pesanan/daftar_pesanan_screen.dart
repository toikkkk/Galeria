import 'package:flutter/material.dart';

import '../../../models/pesanan.dart';
import '../../../services/pesanan_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/commerce_widgets.dart';
import '../../../widgets/kolektor/kolektor_bottom_nav.dart';
import '../../../widgets/pesanan_widgets.dart';

/// Tab "Pesanan" kolektor: semua pesananmu dari server (`GET /api/pesanan`),
/// dengan tab status berlencana jumlah (pola Shopee "Pesanan Saya").
class DaftarPesananScreen extends StatefulWidget {
  const DaftarPesananScreen({
    super.key,
    this.onNavTap,
    this.onPindai,
    this.onBayarTap,
    this.onDetailTap,
    PesananService? service,
  }) : _service = service;

  final ValueChanged<int>? onNavTap;
  final VoidCallback? onPindai;

  /// Kartu "Menunggu pembayaran" ditekan tombol Bayar -> layar pembayaran.
  final ValueChanged<Pesanan>? onBayarTap;

  /// Kartu ditekan -> detail pesanan (diberi id).
  final ValueChanged<Pesanan>? onDetailTap;
  final PesananService? _service;

  @override
  State<DaftarPesananScreen> createState() => _DaftarPesananScreenState();
}

class _DaftarPesananScreenState extends State<DaftarPesananScreen> {
  late final PesananService _service = widget._service ?? PesananService();
  List<Pesanan> _semua = [];
  bool _memuat = true;
  String? _error;
  int _filter = 0; // 0 semua, 1 belum dibayar, 2 diproses, 3 dikirim, 4 selesai, 5 dibatalkan

  static const _label = ['Semua', 'Belum dibayar', 'Diproses', 'Dikirim', 'Selesai', 'Dibatalkan'];

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
      final d = await _service.daftar();
      if (mounted) setState(() => _semua = d);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat pesanan: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  bool _cocokDi(int f, Pesanan p) => switch (f) {
        1 => p.status == 'menunggu_pembayaran',
        2 => p.status == 'dibayar' || (p.status == 'dikonfirmasi' && !p.sudahDikirim),
        3 => p.status == 'dikonfirmasi' && p.sudahDikirim,
        4 => p.status == 'selesai',
        5 => p.status == 'dibatalkan',
        _ => true,
      };

  int _jumlah(int f) => _semua.where((p) => _cocokDi(f, p)).length;

  @override
  Widget build(BuildContext context) {
    final tampil = _semua.where((p) => _cocokDi(_filter, p)).toList();
    return Scaffold(
      backgroundColor: kLatarMarketplace,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Pesanan Saya', style: AppTextStyles.headlineMd),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            color: Colors.white,
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              itemCount: _label.length,
              itemBuilder: (_, i) => _tab(i),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            if (_error != null)
              KartuBagian(
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                    const SizedBox(height: AppSpacing.xs),
                    OutlinedButton.icon(onPressed: _muat, icon: const Icon(Icons.refresh, size: 16), label: const Text('Coba Lagi')),
                  ],
                ),
              )
            else if (_memuat && _semua.isEmpty)
              const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator()))
            else if (_semua.isEmpty)
              _kosong(
                Icons.shopping_bag_outlined,
                'Belum ada pesanan. Pilih karya di beranda lalu tekan "Beli Sekarang".',
              )
            else if (tampil.isEmpty)
              _kosong(Icons.inbox_outlined, 'Tidak ada pesanan di kategori ini.')
            else
              for (final p in tampil)
                PesananKartu(
                  pesanan: p,
                  onTap: () => widget.onDetailTap?.call(p),
                  tombol: p.bisa('bayar')
                      ? FilledButton(
                          onPressed: () => widget.onBayarTap?.call(p),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.onSurface,
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          ),
                          child: const Text('Bayar sekarang'),
                        )
                      : null,
                ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
      bottomNavigationBar: KolektorBottomNav(
        currentIndex: 2,
        onTap: (i) => widget.onNavTap?.call(i),
        onPindai: widget.onPindai ?? () {},
      ),
    );
  }

  Widget _tab(int i) {
    final aktif = _filter == i;
    final n = i == 0 ? 0 : _jumlah(i);
    return InkWell(
      onTap: () => setState(() => _filter = i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: aktif ? AppColors.accent : Colors.transparent, width: 2.5))),
        child: Row(
          children: [
            Text(
              _label[i],
              style: AppTextStyles.labelMd.copyWith(fontSize: 13, color: aktif ? AppColors.onSurface : AppColors.muted, fontWeight: aktif ? FontWeight.w700 : FontWeight.w500),
            ),
            if (n > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: aktif ? AppColors.accent : AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppRadius.full)),
                child: Text('$n', style: AppTextStyles.labelSm.copyWith(fontSize: 10, color: AppColors.onSurface)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kosong(IconData ikon, String teks) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
        child: Column(
          children: [
            CircleAvatar(radius: 34, backgroundColor: AppColors.surfaceContainerHigh, child: Icon(ikon, size: 32, color: AppColors.muted)),
            const SizedBox(height: AppSpacing.sm),
            Text(teks, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 13)),
          ],
        ),
      );
}
