import 'package:flutter/material.dart';

import '../../config/demo_seniman.dart';
import '../../models/dashboard_seniman.dart';
import '../../services/dashboard_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/dashboard/dashboard_sections.dart';

/// Riwayat tarik dana dari pendapatan seniman
/// (`GET /api/dashboard/seniman/{id}/penarikan`).
///
/// DATA CONTOH: belum ada fitur payout/rekening nyata -- backend menurunkan
/// riwayat ini dari pendapatan bersih bulanan data dummy.
class RiwayatPenarikanScreen extends StatefulWidget {
  const RiwayatPenarikanScreen({super.key, required this.onBack, this.service});

  final VoidCallback onBack;
  final DashboardService? service;

  @override
  State<RiwayatPenarikanScreen> createState() => _RiwayatPenarikanScreenState();
}

class _RiwayatPenarikanScreenState extends State<RiwayatPenarikanScreen> {
  late final DashboardService _service = widget.service ?? DashboardService();
  RiwayatPenarikan? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = await resolveDemoSenimanId(_service);
      final r = await _service.fetchRiwayatPenarikan(id);
      if (!mounted) return;
      setState(() {
        _data = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat riwayat: $e';
        _loading = false;
      });
    }
  }

  static const _bulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  String _namaBulan(String ym) {
    final p = ym.split('-');
    return '${_bulan[int.parse(p[1]) - 1]} ${p[0]}';
  }

  String _tgl(DateTime d) => '${d.day} ${_bulan[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Riwayat Tarik Dana', style: AppTextStyles.headlineSm),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final data = _data;
    if (data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Data tidak tersedia.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardInner),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL DITARIK',
                    style: AppTextStyles.overline.copyWith(color: Colors.white60)),
                const SizedBox(height: 4),
                Text(
                  formatRupiah(data.totalDitarikIdr),
                  style: AppTextStyles.displayMd.copyWith(color: Colors.white, fontSize: 26),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Align(
            alignment: Alignment.centerLeft,
            child: DataContohBadge(label: 'DATA CONTOH'),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (data.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(
                child: Text('Belum ada penarikan dana.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
              ),
            )
          else
            for (final p in data.items) _PenarikanTile(
              judul: 'Pendapatan ${_namaBulan(p.periodeBulan)}',
              subjudul: '${_tgl(p.tanggal)} · ${p.tujuan}',
              jumlah: formatRupiah(p.jumlahIdr),
              berhasil: p.berhasil,
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Riwayat ini dihitung dari pendapatan bersih data contoh (setelah komisi platform), '
            'bukan catatan transfer bank nyata.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PenarikanTile extends StatelessWidget {
  const _PenarikanTile({
    required this.judul,
    required this.subjudul,
    required this.jumlah,
    required this.berhasil,
  });

  final String judul, subjudul, jumlah;
  final bool berhasil;

  @override
  Widget build(BuildContext context) {
    final warna = berhasil ? AppColors.accent : AppColors.muted;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: warna.withValues(alpha: 0.12),
            child: Icon(
              berhasil ? Icons.south_west : Icons.hourglass_bottom,
              size: 18,
              color: warna,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul, style: AppTextStyles.labelMd, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subjudul,
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(jumlah, style: AppTextStyles.labelMd),
              const SizedBox(height: 2),
              Text(
                berhasil ? 'Berhasil' : 'Diproses',
                style: AppTextStyles.labelSm.copyWith(color: warna, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
