import 'package:flutter/material.dart';

import '../../state/studio_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_waktu.dart';
import '../../widgets/event_stepper.dart';
import 'event_form_widgets.dart';

/// Langkah 2 wizard "Buat Event": tanggal, jam, format, dan lokasi.
class BuatEventStep2Screen extends StatefulWidget {
  const BuatEventStep2Screen({super.key, required this.onKembali, required this.onLanjut});

  final VoidCallback onKembali;
  final VoidCallback onLanjut;

  @override
  State<BuatEventStep2Screen> createState() => _BuatEventStep2ScreenState();
}

class _BuatEventStep2ScreenState extends State<BuatEventStep2Screen> {
  final _draft = StudioStore.instance.draftEvent;
  late final _lokasi = TextEditingController(text: _draft.namaLokasi);
  late final _alamat = TextEditingController(text: _draft.alamat);
  late final _kota = TextEditingController(text: _draft.kota);
  late final _link = TextEditingController(text: _draft.linkOnline);
  String? _error;

  @override
  void dispose() {
    _lokasi.dispose();
    _alamat.dispose();
    _kota.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _tanggal(bool mulai) async {
    final now = DateTime.now();
    final awal = (mulai ? _draft.tanggalMulai : _draft.tanggalSelesai) ?? _draft.tanggalMulai ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: awal.isBefore(now) ? now : awal,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (d == null) return;
    setState(() {
      if (mulai) {
        _draft.tanggalMulai = d;
        final s = _draft.tanggalSelesai;
        if (s != null && s.isBefore(d)) _draft.tanggalSelesai = d;
      } else {
        _draft.tanggalSelesai = d;
      }
    });
  }

  Future<void> _jam(bool buka) async {
    final t = await showTimePicker(
      context: context,
      initialTime: (buka ? _draft.jamBuka : _draft.jamTutup) ??
          TimeOfDay(hour: buka ? 10 : 20, minute: 0),
    );
    if (t == null) return;
    setState(() => buka ? _draft.jamBuka = t : _draft.jamTutup = t);
  }

  void _lanjut() {
    _draft.namaLokasi = _lokasi.text.trim();
    _draft.alamat = _alamat.text.trim();
    _draft.kota = _kota.text.trim();
    _draft.linkOnline = _link.text.trim();

    String? err;
    final buka = _draft.jamBuka;
    final tutup = _draft.jamTutup;
    if (_draft.tanggalMulai == null) {
      err = 'Pilih tanggal mulai.';
    } else if (_draft.tanggalSelesai == null) {
      err = 'Pilih tanggal selesai.';
    } else if (buka == null || tutup == null) {
      err = 'Pilih jam buka dan jam tutup.';
    } else if (_draft.tanggalMulai == _draft.tanggalSelesai &&
        tutup.hour * 60 + tutup.minute <= buka.hour * 60 + buka.minute) {
      err = 'Jam tutup harus setelah jam buka.';
    } else if (_draft.format == 'offline') {
      if (_draft.namaLokasi.isEmpty || _draft.alamat.isEmpty || _draft.kota.isEmpty) {
        err = 'Lengkapi nama lokasi, alamat, dan kota.';
      }
    } else if (_draft.linkOnline.isEmpty) {
      err = 'Isi tautan acara online.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() => _error = null);
    widget.onLanjut();
  }

  @override
  Widget build(BuildContext context) {
    final offline = _draft.format == 'offline';
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onKembali, icon: const Icon(Icons.arrow_back)),
        title: Text('Jadwal & Lokasi Pameran', style: AppTextStyles.headlineSm),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: [
          const EventStepper(currentStep: 2),
          const SizedBox(height: AppSpacing.md),
          EventSectionCard(
            title: 'Waktu Pelaksanaan',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                eventLabel('Tanggal'),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _tanggal(true),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _draft.tanggalMulai == null ? 'Mulai' : formatTanggal(_draft.tanggalMulai!),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _tanggal(false),
                        icon: const Icon(Icons.event, size: 16),
                        label: Text(
                          _draft.tanggalSelesai == null ? 'Selesai' : formatTanggal(_draft.tanggalSelesai!),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                eventLabel('Jam operasional'),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _jam(true),
                        icon: const Icon(Icons.wb_sunny_outlined, size: 16),
                        label: Text(_draft.jamBuka == null ? 'Jam buka' : formatJam(_draft.jamBuka!)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _jam(false),
                        icon: const Icon(Icons.nights_stay_outlined, size: 16),
                        label: Text(_draft.jamTutup == null ? 'Jam tutup' : formatJam(_draft.jamTutup!)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          EventSectionCard(
            title: 'Lokasi',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'offline', label: Text('Tatap muka'), icon: Icon(Icons.place_outlined)),
                    ButtonSegment(value: 'online', label: Text('Online'), icon: Icon(Icons.videocam_outlined)),
                  ],
                  selected: {_draft.format},
                  onSelectionChanged: (s) => setState(() => _draft.format = s.first),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (offline) ...[
                  eventLabel('Nama lokasi / galeri'),
                  TextField(controller: _lokasi, decoration: eventDekor('mis. Galeri Nasional Indonesia')),
                  const SizedBox(height: AppSpacing.sm),
                  eventLabel('Alamat lengkap'),
                  TextField(
                    controller: _alamat,
                    maxLines: 2,
                    decoration: eventDekor('Jl. Medan Merdeka Timur No. 14'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  eventLabel('Kota'),
                  TextField(controller: _kota, decoration: eventDekor('mis. Jakarta Pusat')),
                ] else ...[
                  eventLabel('Tautan acara online'),
                  TextField(controller: _link, decoration: eventDekor('https://...')),
                ],
              ],
            ),
          ),
          if (_error != null)
            Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
        ],
      ),
      bottomNavigationBar: EventBottomBar(
        lanjutLabel: 'Lanjut ke Tiket',
        onLanjut: _lanjut,
        onKembali: widget.onKembali,
      ),
    );
  }
}
