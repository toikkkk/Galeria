import 'package:flutter/material.dart';

import '../../../models/event.dart';
import '../../../services/auth_service.dart';
import '../../../services/event_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../utils/format_waktu.dart';

/// Pilih jenis & jumlah tiket, isi nama pemegang, lalu buat pesanan tiket (`POST /api/event/{id}/pesan`).
/// Tiket gratis langsung terbit; tiket berbayar lanjut ke pembayaran. Kuota dicek server (maks 5 tiket per akun).
class TiketCheckoutScreen extends StatefulWidget {
  const TiketCheckoutScreen({super.key, required this.event, required this.onBack, required this.onDipesan, EventService? service})
      : _service = service;

  final EventInfo event;
  final VoidCallback onBack;
  final ValueChanged<PesananTiket> onDipesan;
  final EventService? _service;

  @override
  State<TiketCheckoutScreen> createState() => _TiketCheckoutScreenState();
}

class _TiketCheckoutScreenState extends State<TiketCheckoutScreen> {
  late final EventService _service = widget._service ?? EventService();
  late final _nama = TextEditingController(text: AuthService.instance.user?.displayName ?? '');
  TiketEvent? _tiket;
  int _jumlah = 1;
  bool _kirim = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tiket = widget.event.tiket.where((t) => !t.habis).firstOrNull;
  }

  @override
  void dispose() {
    _nama.dispose();
    super.dispose();
  }

  int get _total => (_tiket?.hargaIdr ?? 0) * _jumlah;

  Future<void> _pesan() async {
    final t = _tiket;
    if (t == null) {
      setState(() => _error = 'Pilih jenis tiket.');
      return;
    }
    if (_nama.text.trim().length < 2) {
      setState(() => _error = 'Isi nama pemegang tiket.');
      return;
    }
    setState(() {
      _kirim = true;
      _error = null;
    });
    try {
      final p = await _service.pesan(widget.event.id, tiketId: t.id, jumlah: _jumlah, namaPemegang: _nama.text.trim());
      if (mounted) widget.onDipesan(p);
    } catch (e) {
      if (mounted) {
        setState(() {
          _kirim = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final t = _tiket;
    final maks = t == null ? 1 : (t.sisa < 5 ? t.sisa : 5);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Pesan Tiket', style: AppTextStyles.headlineSm),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: [
          Text(e.judul, style: AppTextStyles.headlineSm),
          Text('${formatTanggal(e.mulai)} · ${e.lokasi}', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
          const SizedBox(height: AppSpacing.md),
          Text('Jenis Tiket', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.xs),
          for (final x in e.tiket)
            GestureDetector(
              onTap: x.habis || _kirim ? null : () => setState(() {
                    _tiket = x;
                    if (_jumlah > x.sisa) _jumlah = x.sisa;
                  }),
              child: Opacity(
                opacity: x.habis ? 0.5 : 1,
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: _tiket?.id == x.id ? AppColors.accent : AppColors.border, width: _tiket?.id == x.id ? 1.6 : 1),
                  ),
                  child: Row(children: [
                    Icon(_tiket?.id == x.id ? Icons.radio_button_checked : Icons.radio_button_off, color: _tiket?.id == x.id ? AppColors.accent : AppColors.muted, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(x.nama, style: AppTextStyles.labelMd),
                        Text(x.habis ? 'Habis' : 'Sisa ${x.sisa}', style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted)),
                      ]),
                    ),
                    Text(x.gratis ? 'Gratis' : formatRupiah(x.hargaIdr), style: AppTextStyles.labelMd),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Text('Jumlah', style: AppTextStyles.labelMd),
            const Spacer(),
            IconButton(onPressed: _jumlah > 1 && !_kirim ? () => setState(() => _jumlah--) : null, icon: const Icon(Icons.remove_circle_outline)),
            Text('$_jumlah', style: AppTextStyles.headlineSm),
            IconButton(onPressed: _jumlah < maks && !_kirim ? () => setState(() => _jumlah++) : null, icon: const Icon(Icons.add_circle_outline)),
          ]),
          TextField(
            controller: _nama,
            enabled: !_kirim,
            decoration: const InputDecoration(labelText: 'Nama pemegang tiket', filled: true, fillColor: Colors.white, isDense: true),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(children: [
              Text('Total', style: AppTextStyles.labelMd),
              const Spacer(),
              Text(_total == 0 ? 'Gratis' : formatRupiah(_total), style: AppTextStyles.headlineSm.copyWith(color: AppColors.accent)),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('pesan_tiket'),
              onPressed: _kirim || t == null ? null : _pesan,
              child: _kirim
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_total == 0 ? 'Daftar & Terbitkan Tiket' : 'Lanjut ke Pembayaran'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _total == 0 ? 'Tiket gratis langsung terbit. Maksimal 5 tiket per akun.' : 'Kuota ditahan 30 menit sejak pesanan dibuat. Maksimal 5 tiket per akun.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
