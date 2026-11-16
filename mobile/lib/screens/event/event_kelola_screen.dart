import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../services/event_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/commerce_widgets.dart';
import '../../utils/format.dart';
import '../../utils/format_waktu.dart';
import '../../widgets/event_widgets.dart';
import '../../widgets/pesanan_widgets.dart';

const _kopi = Color(0xFF3E251E);

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
  String _filterPeserta = 'semua';

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
      backgroundColor: kLatarMarketplace,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
    final terjual = e.tiketTerjual ?? 0;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.sm),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4D2F26), Color(0xFF2F1B15)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TanggalTile(tanggal: e.mulai, ukuran: 56),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  StatusEventChip(status: e.status),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.full)),
                    child: Text(e.format == 'online' ? 'ONLINE' : 'OFFLINE', style: AppTextStyles.overline.copyWith(fontSize: 8.5, color: Colors.white70)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(e.judul, style: AppTextStyles.headlineMd.copyWith(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${formatTanggal(e.mulai)} · ${jamMenit(e.mulai)} - ${jamMenit(e.selesai)}', style: AppTextStyles.bodySm.copyWith(color: Colors.white70)),
                Text(e.lokasi, style: AppTextStyles.bodySm.copyWith(color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.xs),
        KartuBagian(
          judul: 'Penjualan Tiket',
          ikon: Icons.insights_outlined,
          child: Column(children: [
            Row(children: [
              Text('Kuota terisi', style: AppTextStyles.bodySm.copyWith(fontSize: 11.5, color: AppColors.muted)),
              const Spacer(),
              Text('${e.totalKuota == 0 ? 0 : (terjual * 100 / e.totalKuota).round()}%', style: AppTextStyles.labelMd.copyWith(fontWeight: FontWeight.w800, color: _kopi)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: e.totalKuota == 0 ? 0 : (terjual / e.totalKuota).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0xFFE6DFD5),
                valueColor: const AlwaysStoppedAnimation(_kopi),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              _s('$terjual/${e.totalKuota}', 'Tiket terjual'),
              const SizedBox(width: 8),
              _s(formatRupiah(e.pendapatanIdr ?? 0), 'Pendapatan', sorot: true),
              const SizedBox(width: 8),
              _s('${e.sudahCheckin ?? 0}', 'Sudah check-in'),
            ]),
          ]),
        ),
        KartuBagian(
          judul: 'Check-in Peserta',
          ikon: Icons.qr_code_scanner,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              FilledButton(
                key: const Key('tombol_checkin'),
                onPressed: _cek ? null : _checkin,
                style: FilledButton.styleFrom(backgroundColor: _kopi, foregroundColor: Colors.white),
                child: _cek ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Check-in'),
              ),
            ]),
            if (_hasil != null)
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.xs),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: (_hasil!.berhasil ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(children: [
                  Icon(_hasil!.berhasil ? Icons.check_circle : Icons.error_outline, color: _hasil!.berhasil ? AppColors.success : AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_hasil!.pesan, key: const Key('hasil_checkin'), style: AppTextStyles.labelMd),
                      if (_hasil!.namaPemegang != null) Text('${_hasil!.namaPemegang} · ${_hasil!.tiketNama}', style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
                    ]),
                  ),
                ]),
              ),
          ]),
        ),
        KartuBagian(
          judul: 'Peserta (${_peserta.length})',
          ikon: Icons.groups_2_outlined,
          child: _peserta.isEmpty
              ? Text('Belum ada tiket yang terbit.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted))
              : Column(children: [
                  Row(children: [
                    for (final (kunci, label) in const [('semua', 'Semua'), ('hadir', 'Hadir'), ('belum', 'Belum')])
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _filterPeserta = kunci),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _filterPeserta == kunci ? _kopi : Colors.white,
                              borderRadius: BorderRadius.circular(AppRadius.full),
                              border: Border.all(color: _filterPeserta == kunci ? _kopi : AppColors.border),
                            ),
                            child: Text(
                              '$label ${kunci == 'semua' ? _peserta.length : _peserta.where((p) => (p.status == 'terpakai') == (kunci == 'hadir')).length}',
                              style: AppTextStyles.labelMd.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: _filterPeserta == kunci ? Colors.white : AppColors.onSurface),
                            ),
                          ),
                        ),
                      ),
                  ]),
                  for (final p in _peserta.where((p) => _filterPeserta == 'semua' || (p.status == 'terpakai') == (_filterPeserta == 'hadir')))
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: Row(children: [
                        Icon(p.status == 'terpakai' ? Icons.check_circle : Icons.confirmation_number_outlined, size: 18, color: p.status == 'terpakai' ? AppColors.success : AppColors.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.namaPemegang ?? p.akunPembeli, style: AppTextStyles.labelMd.copyWith(fontSize: 13)),
                            Text('${p.tiketNama} · ${p.kode}', style: AppTextStyles.bodySm.copyWith(fontSize: 10.5, color: AppColors.muted)),
                          ]),
                        ),
                        Text(p.status == 'terpakai' ? 'Hadir' : 'Belum', style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: p.status == 'terpakai' ? AppColors.success : AppColors.muted)),
                      ]),
                    ),
                ]),
        ),
        if (e.bisaDibatalkan)
          OutlinedButton(onPressed: () => _batalkan(e), child: const Text('Batalkan event', style: TextStyle(color: AppColors.error)))
        else if (e.status == 'akan_datang' || e.status == 'berlangsung')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: CatatanIkon('Event yang sudah punya pembeli tidak bisa dibatalkan di versi ini (pengembalian dana belum tersedia).'),
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _s(String v, String l, {bool sorot = false}) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(color: sorot ? const Color(0xFFF7E7C1) : const Color(0xFFF3EFE9), borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Column(children: [
            Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.labelMd.copyWith(fontSize: 14, fontWeight: FontWeight.w800, color: sorot ? const Color(0xFF7A5410) : _kopi), textAlign: TextAlign.center),
            Text(l, style: AppTextStyles.bodySm.copyWith(fontSize: 10, color: AppColors.muted), textAlign: TextAlign.center),
          ]),
        ),
      );
}
