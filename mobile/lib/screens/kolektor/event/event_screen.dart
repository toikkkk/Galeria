import 'package:flutter/material.dart';

import '../../../models/event.dart';
import '../../../services/auth_service.dart';
import '../../../services/event_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../utils/format_waktu.dart';
import '../../../widgets/event_widgets.dart';

/// Daftar event yang akan datang dari server (`GET /api/event`). Tamu boleh melihat.
class EventScreen extends StatefulWidget {
  const EventScreen({super.key, required this.onBack, required this.onDetail, this.onTiketSaya, EventService? service})
      : _service = service;

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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Event & Pameran', style: AppTextStyles.headlineMd),
        actions: [
          if (masuk && !(AuthService.instance.user?.isSeniman ?? false))
            IconButton(onPressed: widget.onTiketSaya, icon: const Icon(Icons.confirmation_number_outlined), tooltip: 'Tiket saya'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final f in const [('mendatang', 'Mendatang'), ('selesai', 'Sudah berakhir')])
                  ChoiceChip(
                    label: Text(f.$2),
                    selected: _waktu == f.$1,
                    onSelected: (_) {
                      setState(() => _waktu = f.$1);
                      _muat();
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
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
                child: Text(
                  _waktu == 'mendatang' ? 'Belum ada event mendatang.' : 'Belum ada event yang berakhir.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                ),
              )
            else
              for (final e in _data) _Kartu(e: e, onTap: () => widget.onDetail(e)),
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
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              StatusEventChip(status: e.status),
              const SizedBox(width: 6),
              Icon(e.online ? Icons.videocam_outlined : Icons.place_outlined, size: 14, color: AppColors.muted),
              const SizedBox(width: 3),
              Expanded(child: Text(e.lokasi, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted))),
            ]),
            const SizedBox(height: 6),
            Text(e.judul, style: AppTextStyles.headlineSm),
            Text('oleh ${e.penyelenggara}', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.event, size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
              Text('${formatTanggal(e.mulai)} · ${jamMenit(e.mulai)}', style: AppTextStyles.bodySm),
            ]),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(e.gratis ? 'Gratis' : 'Mulai ${formatRupiah(e.hargaMulaiIdr)}', style: AppTextStyles.labelMd.copyWith(color: AppColors.accent)),
                const Spacer(),
                Text(habis ? 'Tiket habis' : 'Sisa ${e.totalSisa} tiket', style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: habis ? AppColors.error : AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
