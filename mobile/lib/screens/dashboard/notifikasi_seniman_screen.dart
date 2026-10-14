import 'package:flutter/material.dart';

import '../../config/demo_seniman.dart';
import '../../models/dashboard_seniman.dart';
import '../../services/dashboard_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/dashboard/dashboard_sections.dart';

/// Notifikasi seniman: pembelian dari kolektor, hasil lelang, dan tindakan
/// yang perlu dilakukan (mis. pesanan perlu dikemas).
/// (`GET /api/dashboard/seniman/{id}/notifikasi`)
///
/// DATA CONTOH: belum ada tabel notifikasi/lelang nyata -- backend
/// menurunkannya dari transaksi data dummy.
class NotifikasiSenimanScreen extends StatefulWidget {
  const NotifikasiSenimanScreen({super.key, required this.onBack, this.service});

  final VoidCallback onBack;
  final DashboardService? service;

  @override
  State<NotifikasiSenimanScreen> createState() => _NotifikasiSenimanScreenState();
}

class _NotifikasiSenimanScreenState extends State<NotifikasiSenimanScreen> {
  late final DashboardService _service = widget.service ?? DashboardService();
  List<NotifikasiSeniman>? _items;
  String? _error;
  bool _loading = true;
  String _filter = 'semua';

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
      final r = await _service.fetchNotifikasi(id);
      if (!mounted) return;
      setState(() {
        _items = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat notifikasi: $e';
        _loading = false;
      });
    }
  }

  static const _bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  String _waktu(DateTime d) {
    final l = d.toLocal();
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    return '${l.day} ${_bulan[l.month - 1]} ${l.year} · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Notifikasi', style: AppTextStyles.headlineSm),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final all = _items;
    if (all == null) {
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
    final items = _filter == 'semua' ? all : all.where((n) => n.tipe == _filter).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final f in const [
                ('semua', 'Semua'),
                ('tindakan', 'Perlu tindakan'),
                ('pembelian', 'Pembelian'),
                ('lelang', 'Lelang'),
              ])
                ChoiceChip(
                  label: Text(f.$2),
                  selected: _filter == f.$1,
                  onSelected: (_) => setState(() => _filter = f.$1),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Align(
            alignment: Alignment.centerLeft,
            child: DataContohBadge(label: 'DATA CONTOH'),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(
                child: Text('Belum ada notifikasi.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
              ),
            )
          else
            for (final n in items) _NotifTile(n: n, waktu: _waktu(n.waktu)),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.n, required this.waktu});

  final NotifikasiSeniman n;
  final String waktu;

  (IconData, Color) get _gaya => switch (n.tipe) {
        'tindakan' => (Icons.inventory_2_outlined, AppColors.error),
        'lelang' => (Icons.gavel_outlined, AppColors.primary),
        _ => (Icons.shopping_bag_outlined, AppColors.accent),
      };

  @override
  Widget build(BuildContext context) {
    final (ikon, warna) = _gaya;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: warna.withValues(alpha: 0.12),
            child: Icon(ikon, size: 18, color: warna),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.judul, style: AppTextStyles.labelMd),
                const SizedBox(height: 2),
                Text(n.deskripsi, style: AppTextStyles.bodySm),
                if (n.nominalIdr != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    formatRupiah(n.nominalIdr!),
                    style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 4),
                Text(waktu,
                    style: AppTextStyles.labelSm.copyWith(color: AppColors.muted, fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
