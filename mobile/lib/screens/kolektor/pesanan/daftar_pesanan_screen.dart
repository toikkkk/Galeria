import 'package:flutter/material.dart';

import '../../../models/pesanan.dart';
import '../../../services/pesanan_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kolektor/kolektor_bottom_nav.dart';
import '../../../widgets/pesanan_widgets.dart';

/// Tab "Pesanan" kolektor: semua pesananmu dari server (`GET /api/pesanan`).
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
  int _filter = 0; // 0 semua, 1 belum dibayar, 2 diproses/dikirim, 3 selesai, 4 dibatalkan

  static const _label = ['Semua', 'Belum dibayar', 'Diproses', 'Selesai', 'Dibatalkan'];

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

  bool _cocok(Pesanan p) => switch (_filter) {
        1 => p.status == 'menunggu_pembayaran',
        2 => p.status == 'dibayar' || p.status == 'dikonfirmasi',
        3 => p.status == 'selesai',
        4 => p.status == 'dibatalkan',
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final tampil = _semua.where(_cocok).toList();
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text('Pesanan Saya', style: AppTextStyles.headlineMd)),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _label.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(label: Text(_label[i]), selected: _filter == i, onSelected: (_) => setState(() => _filter = i)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_error != null)
              Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                  const SizedBox(height: AppSpacing.xs),
                  OutlinedButton.icon(onPressed: _muat, icon: const Icon(Icons.refresh, size: 16), label: const Text('Coba Lagi')),
                ],
              )
            else if (_memuat && _semua.isEmpty)
              const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator()))
            else if (_semua.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Belum ada pesanan. Pilih karya di beranda lalu tekan "Beli Sekarang".',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                ),
              )
            else if (tampil.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text('Tidak ada pesanan di kategori ini.', textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
              )
            else
              for (final p in tampil)
                PesananKartu(
                  pesanan: p,
                  onTap: () => widget.onDetailTap?.call(p),
                  tombol: p.bisa('bayar')
                      ? SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(onPressed: () => widget.onBayarTap?.call(p), child: const Text('Bayar sekarang')),
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
}
