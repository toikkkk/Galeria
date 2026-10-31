import 'package:flutter/material.dart';

import '../../models/pesanan.dart';
import '../../services/pesanan_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pesanan_widgets.dart';

/// Pesanan masuk seniman (`GET /api/pesanan?peran=penjual`), dikelompokkan menurut tahap:
/// Perlu diproses (sudah dibayar / perlu dikirim), Dikirim, Selesai. Menunggu pembayaran belum
/// ditampilkan sebagai tugas karena kolektor belum membayar.
class PesananSenimanScreen extends StatefulWidget {
  const PesananSenimanScreen({super.key, required this.onBack, this.onDetailTap, PesananService? service})
      : _service = service;

  final VoidCallback onBack;
  final ValueChanged<Pesanan>? onDetailTap;
  final PesananService? _service;

  @override
  State<PesananSenimanScreen> createState() => _PesananSenimanScreenState();
}

class _PesananSenimanScreenState extends State<PesananSenimanScreen> {
  late final PesananService _service = widget._service ?? PesananService();
  List<Pesanan> _semua = [];
  bool _memuat = true;
  String? _error;
  final Set<String> _sibuk = {};

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
      final d = await _service.daftar(penjual: true);
      if (mounted) setState(() => _semua = d);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat pesanan: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _konfirmasi(Pesanan p) async {
    setState(() => _sibuk.add(p.id));
    try {
      final baru = await _service.konfirmasi(p.id);
      if (!mounted) return;
      setState(() => _semua = [for (final x in _semua) x.id == p.id ? baru : x]);
      tampilkanPesan(context, 'Pesanan dikonfirmasi. Silakan kemas dan kirim karya.');
    } catch (e) {
      if (mounted) tampilkanPesan(context, e.toString());
    } finally {
      if (mounted) setState(() => _sibuk.remove(p.id));
    }
  }

  Future<void> _kirim(Pesanan p) async {
    final hasil = await tampilkanDialogKirim(context);
    if (hasil == null || !mounted) return;
    final (k, r) = hasil;
    setState(() => _sibuk.add(p.id));
    try {
      final baru = await _service.kirim(p.id, kurir: k, noResi: r);
      if (!mounted) return;
      setState(() => _semua = [for (final x in _semua) x.id == p.id ? baru : x]);
      tampilkanPesan(context, 'Pesanan ditandai dikirim.');
    } catch (e) {
      if (mounted) tampilkanPesan(context, e.toString());
    } finally {
      if (mounted) setState(() => _sibuk.remove(p.id));
    }
  }

  List<Pesanan> get _perluDiproses =>
      _semua.where((p) => p.status == 'dibayar' || (p.status == 'dikonfirmasi' && !p.sudahDikirim)).toList();
  List<Pesanan> get _dikirim => _semua.where((p) => p.status == 'dikonfirmasi' && p.sudahDikirim).toList();
  List<Pesanan> get _selesai => _semua.where((p) => p.status == 'selesai').toList();

  Widget? _tombol(Pesanan p) {
    final sibuk = _sibuk.contains(p.id);
    if (p.bisa('konfirmasi')) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(onPressed: sibuk ? null : () => _konfirmasi(p), child: const Text('Konfirmasi pesanan')),
      );
    }
    if (p.bisa('kirim')) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: sibuk ? null : () => _kirim(p),
          icon: const Icon(Icons.local_shipping_outlined, size: 18),
          label: const Text('Tandai dikirim + resi'),
        ),
      );
    }
    return null;
  }

  Widget _daftar(List<Pesanan> data, String kosong) {
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: [
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
          else if (data.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(kosong, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
            )
          else
            for (final p in data)
              PesananKartu(
                pesanan: p,
                sebagaiPenjual: true,
                onTap: () => widget.onDetailTap?.call(p),
                tombol: _tombol(p),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
          title: Text('Pesanan Masuk', style: AppTextStyles.headlineSm),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            indicatorColor: AppColors.accent,
            labelStyle: AppTextStyles.labelMd,
            tabs: [
              Tab(text: 'Perlu Diproses (${_perluDiproses.length})'),
              Tab(text: 'Dikirim (${_dikirim.length})'),
              const Tab(text: 'Selesai'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _daftar(_perluDiproses, 'Belum ada pesanan yang perlu diproses.'),
            _daftar(_dikirim, 'Belum ada pesanan dalam pengiriman.'),
            _daftar(_selesai, 'Belum ada pesanan selesai.'),
          ],
        ),
      ),
    );
  }
}
