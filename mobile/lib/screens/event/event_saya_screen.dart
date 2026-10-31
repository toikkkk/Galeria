import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../services/event_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/format_waktu.dart';
import '../../widgets/event_widgets.dart';

/// Event yang kamu selenggarakan (`GET /api/event/saya`), dengan ringkasan penjualan tiket.
class EventSayaScreen extends StatefulWidget {
  const EventSayaScreen({super.key, required this.onBack, required this.onKelola, this.onBuat, EventService? service}) : _service = service;

  final VoidCallback onBack;
  final ValueChanged<EventInfo> onKelola;
  final VoidCallback? onBuat;
  final EventService? _service;

  @override
  State<EventSayaScreen> createState() => _EventSayaScreenState();
}

class _EventSayaScreenState extends State<EventSayaScreen> {
  late final EventService _service = widget._service ?? EventService();
  List<EventInfo> _data = [];
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
      final d = await _service.saya();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat event: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Event Saya', style: AppTextStyles.headlineSm),
        actions: [IconButton(onPressed: widget.onBuat, icon: const Icon(Icons.add), tooltip: 'Buat event')],
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
                child: Column(children: [
                  Text('Kamu belum menyelenggarakan event.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                  const SizedBox(height: AppSpacing.xs),
                  FilledButton.icon(onPressed: widget.onBuat, icon: const Icon(Icons.event_note_outlined), label: const Text('Buat event')),
                ]),
              )
            else
              for (final e in _data)
                GestureDetector(
                  onTap: () => widget.onKelola(e),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      StatusEventChip(status: e.status),
                      const SizedBox(height: 4),
                      Text(e.judul, style: AppTextStyles.labelMd),
                      Text('${formatTanggal(e.mulai)} · ${e.lokasi}', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
                      const SizedBox(height: 6),
                      Row(children: [
                        _s('${e.tiketTerjual ?? 0}/${e.totalKuota}', 'Terjual'),
                        _s(formatRupiah(e.pendapatanIdr ?? 0), 'Pendapatan'),
                        _s('${e.sudahCheckin ?? 0}', 'Check-in'),
                      ]),
                    ]),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _s(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: AppTextStyles.labelMd.copyWith(fontSize: 13)),
          Text(l, style: AppTextStyles.bodySm.copyWith(fontSize: 10, color: AppColors.muted)),
        ]),
      );
}
