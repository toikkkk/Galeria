import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/studio_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/event_stepper.dart';
import 'event_form_widgets.dart';

/// Langkah 3 wizard "Buat Event": jenis tiket (nama, harga, kuota) dan
/// publikasi.
class BuatEventStep3Screen extends StatefulWidget {
  const BuatEventStep3Screen({super.key, required this.onKembali, required this.onTerbitkan});

  final VoidCallback onKembali;
  final VoidCallback onTerbitkan;

  @override
  State<BuatEventStep3Screen> createState() => _BuatEventStep3ScreenState();
}

class _BuatEventStep3ScreenState extends State<BuatEventStep3Screen> {
  final _draft = StudioStore.instance.draftEvent;
  bool _setuju = false;
  String? _error;

  Future<void> _formTiket({JenisTiket? edit}) async {
    final nama = TextEditingController(text: edit?.nama ?? '');
    final harga = TextEditingController(text: edit == null ? '' : '${edit.hargaIdr}');
    final kuota = TextEditingController(text: edit == null ? '' : '${edit.kuota}');
    final ket = TextEditingController(text: edit?.keterangan ?? '');
    String? err;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(edit == null ? 'Tambah Jenis Tiket' : 'Ubah Tiket'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nama, decoration: eventDekor('Nama tiket (mis. VIP)')),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: harga,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: eventDekor('Harga (0 = gratis)', prefix: 'Rp '),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: kuota,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: eventDekor('Kuota tiket'),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(controller: ket, decoration: eventDekor('Keterangan (opsional)')),
                if (err != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(err!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                final k = int.tryParse(kuota.text) ?? 0;
                if (nama.text.trim().isEmpty) {
                  setD(() => err = 'Isi nama tiket.');
                } else if (harga.text.isEmpty) {
                  setD(() => err = 'Isi harga tiket (0 jika gratis).');
                } else if (k <= 0) {
                  setD(() => err = 'Kuota harus lebih dari 0.');
                } else {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      setState(() {
        final h = int.parse(harga.text);
        final k = int.parse(kuota.text);
        if (edit != null) {
          edit
            ..nama = nama.text.trim()
            ..hargaIdr = h
            ..kuota = k
            ..keterangan = ket.text.trim();
        } else {
          _draft.tiket.add(
            JenisTiket(nama: nama.text.trim(), hargaIdr: h, kuota: k, keterangan: ket.text.trim()),
          );
        }
      });
    }
    nama.dispose();
    harga.dispose();
    kuota.dispose();
    ket.dispose();
  }

  void _terbitkan() {
    if (_draft.tiket.isEmpty) {
      setState(() => _error = 'Tambahkan minimal 1 jenis tiket.');
      return;
    }
    if (!_setuju) {
      setState(() => _error = 'Setujui ketentuan penyelenggaraan event.');
      return;
    }
    StudioStore.instance.terbitkanDraft();
    widget.onTerbitkan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onKembali, icon: const Icon(Icons.arrow_back)),
        title: Text('Tiket & Publikasi', style: AppTextStyles.headlineSm),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: [
          const EventStepper(currentStep: 3),
          const SizedBox(height: AppSpacing.md),
          EventSectionCard(
            title: 'Jenis Tiket',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_draft.tiket.isEmpty)
                  Text(
                    'Belum ada tiket.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                  ),
                for (final t in _draft.tiket) _tiketTile(t),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: () => _formTiket(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah Jenis Tiket'),
                ),
              ],
            ),
          ),
          EventSectionCard(
            title: 'Ringkasan Event',
            child: Column(
              children: [
                _baris('Nama', _draft.nama),
                _baris('Karya dipamerkan', '${_draft.karya.length} karya'),
                _baris(
                  'Lokasi',
                  _draft.format == 'online'
                      ? 'Online'
                      : '${_draft.namaLokasi}, ${_draft.kota}',
                ),
                _baris('Total kuota', '${_draft.totalKuota} tiket'),
                _baris(
                  'Potensi pendapatan',
                  _draft.gratis ? 'Gratis' : formatRupiah(_draft.potensiPendapatanIdr),
                ),
              ],
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _setuju,
            onChanged: (v) => setState(() => _setuju = v ?? false),
            title: Text(
              'Saya menyetujui ketentuan penyelenggaraan event di GALERIA.',
              style: AppTextStyles.bodySm,
            ),
          ),
          if (_error != null)
            Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
        ],
      ),
      bottomNavigationBar: EventBottomBar(
        lanjutLabel: 'Terbitkan Event',
        onLanjut: _terbitkan,
        onKembali: widget.onKembali,
      ),
    );
  }

  Widget _tiketTile(JenisTiket t) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.nama, style: AppTextStyles.labelMd),
                  Text(
                    '${t.hargaIdr == 0 ? 'Gratis' : formatRupiah(t.hargaIdr)} · kuota ${t.kuota}',
                    style: AppTextStyles.bodySm,
                  ),
                  if (t.keterangan.isNotEmpty)
                    Text(
                      t.keterangan,
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
                    ),
                ],
              ),
            ),
            IconButton(onPressed: () => _formTiket(edit: t), icon: const Icon(Icons.edit_outlined, size: 18)),
            IconButton(
              onPressed: () => setState(() => _draft.tiket.remove(t)),
              icon: const Icon(Icons.delete_outline, size: 18),
            ),
          ],
        ),
      );

  Widget _baris(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(label, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
            ),
            Flexible(
              child: Text(value, textAlign: TextAlign.right, style: AppTextStyles.labelMd),
            ),
          ],
        ),
      );
}
