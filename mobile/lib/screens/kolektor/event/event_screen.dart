import 'package:flutter/material.dart';

import '../../../models/event.dart';
import '../../../services/auth_service.dart';
import '../../../services/event_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../utils/format_waktu.dart';
import '../../../widgets/commerce_widgets.dart';
import '../../../widgets/event_widgets.dart';

/// Daftar event yang akan datang dari server (`GET /api/event`). Tamu boleh melihat.
class EventScreen extends StatefulWidget {
  const EventScreen({
    super.key,
    required this.onBack,
    required this.onDetail,
    this.onTiketSaya,
    EventService? service,
  }) : _service = service;

  final VoidCallback onBack;
  final ValueChanged<EventInfo> onDetail;
  final VoidCallback? onTiketSaya;
  final EventService? _service;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  late final EventService _service = widget._service ?? EventService();
  final _cari = TextEditingController();
  String _waktu = 'mendatang';
  List<EventInfo> _data = [];
  bool _memuat = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final d = await _service.daftar(waktu: _waktu, q: _cari.text);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat event: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masuk = AuthService.instance.loggedIn;
    return Scaffold(
      backgroundColor: kLatarMarketplace,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Event & Pameran', style: AppTextStyles.headlineMd),
        actions: [
          if (masuk && !(AuthService.instance.user?.isSeniman ?? false))
            IconButton(
              onPressed: widget.onTiketSaya,
              icon: const Icon(Icons.confirmation_number_outlined),
              tooltip: 'Tiket saya',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            TextField(
              controller: _cari,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _muat(),
              decoration: InputDecoration(
                hintText: 'Cari judul, kota, atau tema',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                for (final f in const [
                  ('mendatang', 'Mendatang'),
                  ('selesai', 'Sudah berakhir'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _waktu == f.$1,
                      selectedColor: const Color(0xFF3E251E),
                      showCheckmark: false,
                      backgroundColor: Colors.white,
                      labelStyle: AppTextStyles.labelMd.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _waktu == f.$1 ? Colors.white : AppColors.onSurface,
                      ),
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: _waktu == f.$1
                              ? const Color(0xFF3E251E)
                              : AppColors.border,
                        ),
                      ),
                      onSelected: (_) {
                        setState(() => _waktu = f.$1);
                        _muat();
                      },
                    ),
                  ),
                const Spacer(),
                if (!_memuat)
                  Text(
                    '${_data.length} event',
                    style: AppTextStyles.bodySm.copyWith(fontSize: 11.5),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
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
                  _waktu == 'mendatang'
                      ? 'Belum ada event mendatang.'
                      : 'Belum ada event yang berakhir.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                ),
              )
            else
              for (final e in _data)
                _Kartu(e: e, onTap: () => widget.onDetail(e)),
          ],
        ),
      ),
    );
  }
}

class _Kartu extends StatelessWidget {
  const _Kartu({required this.e, required this.onTap});

  final EventInfo e;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final habis = e.totalSisa <= 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kepala gelap: tile tanggal + status + format (daring/luring)
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4D2F26), Color(0xFF2F1B15)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  TanggalTile(tanggal: e.mulai),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusEventChip(status: e.status),
                            const SizedBox(width: 6),
                            LencanaKecil(
                              e.online ? 'Daring' : 'Tatap muka',
                              ikon: e.online
                                  ? Icons.videocam_outlined
                                  : Icons.place_outlined,
                              warna: AppColors.accentSoft,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          e.judul,
                          style: AppTextStyles.headlineSm.copyWith(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _baris(
                    Icons.schedule,
                    '${formatTanggal(e.mulai)} · ${jamMenit(e.mulai)} - ${jamMenit(e.selesai)}',
                  ),
                  _baris(
                    e.online ? Icons.videocam_outlined : Icons.place_outlined,
                    e.lokasi,
                  ),
                  _baris(Icons.storefront_outlined, 'oleh ${e.penyelenggara}'),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: LinearProgressIndicator(
                      value: e.totalKuota == 0 ? 0 : ((e.totalKuota - e.totalSisa) / e.totalKuota).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: const Color(0xFFE6DFD5),
                      valueColor: AlwaysStoppedAnimation(habis || e.totalSisa <= e.totalKuota * 0.2 ? AppColors.error : const Color(0xFFDBA12C)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        e.gratis
                            ? 'Gratis'
                            : 'Mulai ${formatRupiah(e.hargaMulaiIdr)}',
                        style: AppTextStyles.labelMd.copyWith(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF3E251E)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: habis || e.totalSisa <= e.totalKuota * 0.2 ? AppColors.error.withValues(alpha: 0.12) : const Color(0xFFF7E7C1),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          habis ? 'Tiket habis' : 'Sisa ${e.totalSisa} tiket',
                          style: AppTextStyles.labelSm.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: habis || e.totalSisa <= e.totalKuota * 0.2 ? AppColors.error : const Color(0xFF7A5410),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _baris(IconData ikon, String teks) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(ikon, size: 15, color: AppColors.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            teks,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySm.copyWith(
              fontSize: 12,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    ),
  );
}
