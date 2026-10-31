import 'package:flutter/material.dart';

import '../../../models/event.dart';
import '../../../services/event_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format_waktu.dart';
import '../../../widgets/event_widgets.dart';

/// Semua e-tiketmu (`GET /api/tiket-saya`), dikelompokkan per event dan jenis tiket.
class TiketSayaScreen extends StatefulWidget {
  const TiketSayaScreen({super.key, required this.onBack, required this.onBuka, EventService? service}) : _service = service;

  final VoidCallback onBack;

  /// Buka e-tiket sebuah kelompok (event + jenis tiket yang sama).
  final void Function(EventRingkas event, String tiketNama, List<ETiket> etiket, String? linkOnline) onBuka;
  final EventService? _service;

  @override
  State<TiketSayaScreen> createState() => _TiketSayaScreenState();
}

class _TiketSayaScreenState extends State<TiketSayaScreen> {
  late final EventService _service = widget._service ?? EventService();
  List<TiketSaya> _data = [];
  bool _memuat = true;
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
      final d = await _service.tiketSaya();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat tiket: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kelompok = <String, List<TiketSaya>>{};
    for (final t in _data) {
      kelompok.putIfAbsent('${t.event.id}|${t.tiketNama}', () => []).add(t);
    }
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Tiket Saya', style: AppTextStyles.headlineSm),
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
          children: [
            if (_error != null)
              Column(children: [
                Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                OutlinedButton.icon(onPressed: _muat, icon: const Icon(Icons.refresh, size: 16), label: const Text('Coba Lagi')),
              ])
            else if (_memuat && _data.isEmpty)
              const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator()))
            else if (_data.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text('Kamu belum punya tiket. Temukan event di halaman Event.', textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
              )
            else
              for (final g in kelompok.values)
                GestureDetector(
                  onTap: () => widget.onBuka(g.first.event, g.first.tiketNama, [for (final x in g) x.etiket], g.first.linkOnline),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
                    child: Row(children: [
                      const Icon(Icons.qr_code_2, size: 40, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          StatusEventChip(status: g.first.event.status),
                          Text(g.first.event.judul, style: AppTextStyles.labelMd, maxLines: 2, overflow: TextOverflow.ellipsis),
                          Text('${g.length} × ${g.first.tiketNama} · ${formatTanggal(g.first.event.mulai)}', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
                          Text(
                            '${g.where((x) => x.etiket.terpakai).length} dari ${g.length} sudah digunakan',
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
                          ),
                        ]),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                    ]),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
