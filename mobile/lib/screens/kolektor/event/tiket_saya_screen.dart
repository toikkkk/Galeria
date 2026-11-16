import 'package:flutter/material.dart';

import '../../../models/event.dart';
import '../../../services/event_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format_waktu.dart';
import '../../../widgets/commerce_widgets.dart';
import '../../../widgets/event_widgets.dart';

/// Semua e-tiketmu (`GET /api/tiket-saya`), dikelompokkan per event dan jenis tiket.
class TiketSayaScreen extends StatefulWidget {
  const TiketSayaScreen({
    super.key,
    required this.onBack,
    required this.onBuka,
    EventService? service,
  }) : _service = service;

  final VoidCallback onBack;

  /// Buka e-tiket sebuah kelompok (event + jenis tiket yang sama).
  final void Function(
    EventRingkas event,
    String tiketNama,
    List<ETiket> etiket,
    String? linkOnline,
  )
  onBuka;
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
      backgroundColor: kLatarMarketplace,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Tiket Saya', style: AppTextStyles.headlineSm),
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            if (_error != null)
              Column(
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _muat,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              )
            else if (_memuat && _data.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_data.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Kamu belum punya tiket. Temukan event di halaman Event.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                ),
              )
            else
              for (final g in kelompok.values)
                GestureDetector(
                  onTap: () => widget.onBuka(g.first.event, g.first.tiketNama, [
                    for (final x in g) x.etiket,
                  ], g.first.linkOnline),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // sisi kiri gelap: tanggal event
                          Container(
                            width: 78,
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF1C1C1C), Color(0xFF3A3326)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: TanggalTile(
                                tanggal: g.first.event.mulai,
                                ukuran: 54,
                              ),
                            ),
                          ),
                          // garis potong tiket
                          Container(
                            width: 1.5,
                            color: AppColors.outlineVariant,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StatusEventChip(status: g.first.event.status),
                                  const SizedBox(height: 4),
                                  Text(
                                    g.first.event.judul,
                                    style: AppTextStyles.labelMd.copyWith(
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${g.length} × ${g.first.tiketNama} · ${formatTanggal(g.first.event.mulai)}',
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.qr_code_2,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${g.where((x) => x.etiket.terpakai).length} dari ${g.length} sudah digunakan',
                                          style: AppTextStyles.bodySm.copyWith(
                                            color: AppColors.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: AppColors.muted,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
