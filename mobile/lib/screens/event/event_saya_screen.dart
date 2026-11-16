import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../services/event_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/format_waktu.dart';
import '../../widgets/commerce_widgets.dart';
import '../../widgets/event_widgets.dart';

const _kopi = Color(0xFF3E251E);
const _emas = Color(0xFFDBA12C);
const _emasTua = Color(0xFFB07D12);

/// Event yang kamu selenggarakan (`GET /api/event/saya`): ringkasan, filter status, dan kartu dengan progres tiket.
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
  String _filter = 'semua';

  static const _filters = [
    ('semua', 'Semua'),
    ('akan_datang', 'Akan datang'),
    ('berlangsung', 'Berlangsung'),
    ('selesai', 'Selesai'),
    ('dibatalkan', 'Dibatalkan'),
  ];

  int _jumlah(String f) => f == 'semua' ? _data.length : _data.where((e) => e.status == f).length;

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
    final tampil = _filter == 'semua' ? _data : _data.where((e) => e.status == _filter).toList();
    return Scaffold(
      backgroundColor: kLatarMarketplace,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Event Saya', style: AppTextStyles.headlineSm),
        actions: [IconButton(onPressed: widget.onBuat, icon: const Icon(Icons.add), tooltip: 'Buat event')],
      ),
      floatingActionButton: _data.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: widget.onBuat,
              backgroundColor: _kopi,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.event_available_outlined, size: 18),
              label: const Text('Buat Event', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 88),
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
                  const CircleAvatar(radius: 34, backgroundColor: AppColors.surfaceContainerHigh, child: Icon(Icons.event_note_outlined, size: 30, color: AppColors.muted)),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Kamu belum menyelenggarakan event.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                  const SizedBox(height: AppSpacing.xs),
                  FilledButton.icon(onPressed: widget.onBuat, icon: const Icon(Icons.event_note_outlined), label: const Text('Buat event')),
                ]),
              )
            else ...[
              _Ringkasan(data: _data),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final (kunci, label) = _filters[i];
                    final aktif = _filter == kunci;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = kunci),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: aktif ? _kopi : Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(color: aktif ? _kopi : AppColors.border),
                        ),
                        child: Text('$label ${_jumlah(kunci)}',
                            style: AppTextStyles.labelMd.copyWith(fontSize: 12.5, color: aktif ? Colors.white : AppColors.onSurface, fontWeight: aktif ? FontWeight.w800 : FontWeight.w600)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (tampil.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: Text('Tidak ada event pada status ini.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted))),
                )
              else
                for (final e in tampil) _KartuEventSaya(event: e, onTap: () => widget.onKelola(e)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ringkasan semua event: pendapatan tiket, event aktif, tiket terjual, dan check-in.
class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.data});

  final List<EventInfo> data;

  @override
  Widget build(BuildContext context) {
    final pendapatan = data.fold<int>(0, (a, e) => a + (e.pendapatanIdr ?? 0));
    final terjual = data.fold<int>(0, (a, e) => a + (e.tiketTerjual ?? 0));
    final checkin = data.fold<int>(0, (a, e) => a + (e.sudahCheckin ?? 0));
    final aktif = data.where((e) => e.status == 'akan_datang' || e.status == 'berlangsung').length;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4D2F26), Color(0xFF2F1B15)]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.confirmation_number_outlined, size: 15, color: Color(0xFFF0C86A)),
          const SizedBox(width: 6),
          Text('PENDAPATAN TIKET', style: AppTextStyles.overline.copyWith(color: Colors.white70, fontSize: 10)),
        ]),
        const SizedBox(height: 4),
        Text(formatRupiah(pendapatan), style: AppTextStyles.headlineSm.copyWith(fontSize: 26, color: const Color(0xFFF0C86A), fontWeight: FontWeight.w800)),
        Text('Dari tiket berbayar semua event milikmu', style: AppTextStyles.bodySm.copyWith(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          _Stat(nilai: '$aktif', label: 'Event aktif'),
          _Stat(nilai: '$terjual', label: 'Tiket terjual'),
          _Stat(nilai: '$checkin', label: 'Check-in'),
        ]),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.nilai, required this.label});

  final String nilai, label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nilai, style: AppTextStyles.headlineSm.copyWith(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w800)),
            Text(label, style: AppTextStyles.bodySm.copyWith(color: Colors.white70, fontSize: 11)),
          ]),
        ),
      );
}

class _KartuEventSaya extends StatelessWidget {
  const _KartuEventSaya({required this.event, required this.onTap});

  final EventInfo event;
  final VoidCallback onTap;

  /// "H-10", "Hari ini", "Berlangsung", atau null bila sudah lewat / dibatalkan.
  String? get _hitung {
    if (event.status == 'berlangsung') return 'Berlangsung';
    if (event.status != 'akan_datang') return null;
    final n = DateTime.now();
    final selisih = DateTime(event.mulai.year, event.mulai.month, event.mulai.day).difference(DateTime(n.year, n.month, n.day)).inDays;
    return selisih <= 0 ? 'Hari ini' : 'H-$selisih';
  }

  @override
  Widget build(BuildContext context) {
    final e = event;
    final terjual = e.tiketTerjual ?? 0;
    final persen = e.totalKuota == 0 ? 0.0 : (terjual / e.totalKuota).clamp(0.0, 1.0);
    final hampirPenuh = persen >= 0.8;
    final hitung = _hitung;
    final online = e.format == 'online';
    final lokasi = online ? 'Online' : [if (e.namaLokasi != null) e.namaLokasi!, if (e.kota != null) e.kota!].join(', ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF4D2F26), Color(0xFF2F1B15)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Row(children: [
              TanggalTile(tanggal: e.mulai, ukuran: 52),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    StatusEventChip(status: e.status),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.full)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(online ? Icons.videocam_outlined : Icons.place_outlined, size: 10, color: Colors.white70),
                        const SizedBox(width: 3),
                        Text(online ? 'ONLINE' : 'OFFLINE', style: AppTextStyles.overline.copyWith(fontSize: 8.5, color: Colors.white70)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(e.judul, style: AppTextStyles.headlineSm.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  Text('${formatTanggal(e.mulai)} · ${jamMenit(e.mulai)}', style: AppTextStyles.bodySm.copyWith(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (lokasi.isNotEmpty) Text(lokasi, style: AppTextStyles.bodySm.copyWith(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              if (hitung != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: _emas, borderRadius: BorderRadius.circular(AppRadius.full)),
                  child: Text(hitung, style: AppTextStyles.labelSm.copyWith(color: _kopi, fontWeight: FontWeight.w800, fontSize: 11.5)),
                ),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 6),
            child: Column(children: [
              Row(children: [
                Text('Tiket terjual', style: AppTextStyles.bodySm.copyWith(fontSize: 11.5, color: AppColors.muted)),
                const Spacer(),
                Text('${(persen * 100).round()}%', style: AppTextStyles.labelMd.copyWith(fontSize: 12.5, fontWeight: FontWeight.w800, color: hampirPenuh ? _emasTua : _kopi)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: persen,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE6DFD5),
                  valueColor: AlwaysStoppedAnimation(hampirPenuh ? _emas : _kopi),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                _s('$terjual/${e.totalKuota}', 'Terjual'),
                _s(formatRupiah(e.pendapatanIdr ?? 0), 'Pendapatan'),
                _s('${e.sudahCheckin ?? 0}', 'Check-in'),
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              const Icon(Icons.sell_outlined, size: 15, color: _emasTua),
              const SizedBox(width: 5),
              Text(e.gratis ? 'Gratis' : 'Mulai ${formatRupiah(e.hargaMulaiIdr)}', style: AppTextStyles.labelMd.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kopi)),
              const SizedBox(width: 8),
              Flexible(child: Text('· ${e.tiket.length} jenis tiket', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm.copyWith(fontSize: 11.5, color: AppColors.muted))),
              const Spacer(),
              Text('Kelola', style: AppTextStyles.labelMd.copyWith(fontSize: 12.5, fontWeight: FontWeight.w800, color: _kopi)),
              const Icon(Icons.chevron_right, size: 18, color: _kopi),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _s(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.labelMd.copyWith(fontSize: 13.5, fontWeight: FontWeight.w800, color: _kopi)),
          Text(l, style: AppTextStyles.bodySm.copyWith(fontSize: 10.5, color: AppColors.muted)),
        ]),
      );
}
