import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../services/event_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/format_waktu.dart';
import '../../widgets/event_widgets.dart';
import '../../widgets/pesanan_widgets.dart';

/// Kelola satu event milik sendiri: statistik, check-in peserta (ketik/tempel kode e-tiket), daftar peserta,
/// dan pembatalan (hanya bila belum ada tiket yang terbayar).
class EventKelolaScreen extends StatefulWidget {
  const EventKelolaScreen({super.key, required this.eventId, required this.onBack, EventService? service}) : _service = service;

  final String eventId;
  final VoidCallback onBack;
  final EventService? _service;

  @override
  State<EventKelolaScreen> createState() => _EventKelolaScreenState();
}

class _EventKelolaScreenState extends State<EventKelolaScreen> {
  late final EventService _service = widget._service ?? EventService();
  final _kode = TextEditingController();
  EventInfo? _e;
  List<Peserta> _peserta = [];
  HasilCheckin? _hasil;
  bool _memuat = true;
  bool _cek = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _kode.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final hasil = await Future.wait([_service.detail(widget.eventId), _service.peserta(widget.eventId)]);
      if (mounted) {
        setState(() {
          _e = hasil[0] as EventInfo;
          _peserta = hasil[1] as List<Peserta>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat event: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _checkin() async {
    final k = _kode.text.trim();
    if (k.length < 6) {
      setState(() => _hasil = const HasilCheckin(berhasil: false, pesan: 'Isi kode tiket (contoh: GAL-ABCDE12345).'));
      return;
    }
    setState(() {
      _cek = true;
      _hasil = null;
    });
    try {
      final h = await _service.checkin(k);
      if (!mounted) return;
      setState(() => _hasil = h);
      if (h.berhasil) {
        _kode.clear();
        await _muat();
      }
    } catch (e) {
      if (mounted) setState(() => _hasil = HasilCheckin(berhasil: false, pesan: e.toString()));
    } finally {
      if (mounted) setState(() => _cek = false);
    }
  }

  Future<void> _batalkan(EventInfo e) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan event?'),
        content: const Text('Event belum punya tiket yang terbayar, jadi bisa dibatalkan. Pesanan yang masih menunggu pembayaran ikut dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, batalkan')),
        ],
      ),
    );
    if (ya != true) return;
    try {
      final baru = await _service.batal(e.id);
      if (mounted) {
        setState(() => _e = baru);
        tampilkanPesan(context, 'Event dibatalkan.');
      }
    } catch (err) {
      if (mounted) tampilkanPesan(context, err.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Kelola Event', style: AppTextStyles.headlineSm),
        actions: [IconButton(onPressed: _memuat ? null : _muat, icon: const Icon(Icons.refresh))],
      ),
      body: _memuat && e == null
          ? const Center(child: CircularProgressIndicator())
          : e == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error ?? 'Event tidak ditemukan.', textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                      OutlinedButton(onPressed: _muat, child: const Text('Coba lagi')),
                    ]),
                  ),
                )
              : RefreshIndicator(onRefresh: _muat, child: _isi(e)),
    );
  }

  Widget _isi(EventInfo e) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: [
        StatusEventChip(status: e.status),
        const SizedBox(height: 4),
        Text(e.judul, style: AppTextStyles.headlineMd),
        Text('${formatTanggal(e.mulai)} · ${jamMenit(e.mulai)} - ${jamMenit(e.selesai)} · ${e.lokasi}', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Row(children: [
            _s('${e.tiketTerjual ?? 0}/${e.totalKuota}', 'Tiket terjual'),
            _s(formatRupiah(e.pendapatanIdr ?? 0), 'Pendapatan'),
            _s('${e.sudahCheckin ?? 0}', 'Sudah check-in'),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Check-in Peserta', style: AppTextStyles.headlineSm),
        const SizedBox(height: 2),
        Text('Minta peserta menunjukkan e-tiket, lalu ketik kode di bawah QR-nya. Dibuka 2 jam sebelum event.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
        const SizedBox(height: AppSpacing.xs),
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('kode_checkin'),
              controller: _kode,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _checkin(),
              decoration: const InputDecoration(hintText: 'GAL-XXXXXXXXXX', filled: true, fillColor: Colors.white, isDense: true),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton(key: const Key('tombol_checkin'), onPressed: _cek ? null : _checkin, child: _cek ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Check-in')),
        ]),
        if (_hasil != null)
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: (_hasil!.berhasil ? AppColors.accent : AppColors.error).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(children: [
              Icon(_hasil!.berhasil ? Icons.check_circle : Icons.error_outline, color: _hasil!.berhasil ? AppColors.accent : AppColors.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_hasil!.pesan, key: const Key('hasil_checkin'), style: AppTextStyles.labelMd),
                  if (_hasil!.namaPemegang != null) Text('${_hasil!.namaPemegang} · ${_hasil!.tiketNama}', style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
                ]),
              ),
            ]),
          ),
        const SizedBox(height: AppSpacing.md),
        Text('Peserta (${_peserta.length})', style: AppTextStyles.headlineSm),
        const SizedBox(height: AppSpacing.xs),
        if (_peserta.isEmpty)
          Text('Belum ada tiket yang terbit.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted))
        else
          for (final p in _peserta)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Row(children: [
                Icon(p.status == 'terpakai' ? Icons.check_circle : Icons.confirmation_number_outlined, size: 18, color: p.status == 'terpakai' ? AppColors.accent : AppColors.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.namaPemegang ?? p.akunPembeli, style: AppTextStyles.labelMd.copyWith(fontSize: 13)),
                    Text('${p.tiketNama} · ${p.kode}', style: AppTextStyles.bodySm.copyWith(fontSize: 10.5, color: AppColors.muted)),
                  ]),
                ),
                Text(p.status == 'terpakai' ? 'Hadir' : 'Belum', style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: p.status == 'terpakai' ? AppColors.accent : AppColors.muted)),
              ]),
            ),
        if (e.bisaDibatalkan) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: () => _batalkan(e), child: const Text('Batalkan event', style: TextStyle(color: AppColors.error))),
        ] else if (e.status == 'akan_datang' || e.status == 'berlangsung') ...[
          const SizedBox(height: AppSpacing.md),
          Text('Event yang sudah punya pembeli tidak bisa dibatalkan di versi ini (pengembalian dana belum tersedia).', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _s(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: AppTextStyles.labelMd, textAlign: TextAlign.center),
          Text(l, style: AppTextStyles.bodySm.copyWith(fontSize: 10, color: AppColors.muted), textAlign: TextAlign.center),
        ]),
      );
}
