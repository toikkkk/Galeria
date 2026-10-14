import 'package:flutter/material.dart';

import '../../state/studio_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/event_stepper.dart';
import '../../widgets/karya_image.dart';
import '../../widgets/karya_picker.dart';
import 'event_form_widgets.dart';

/// Langkah 1 wizard "Buat Event": nama, tema, deskripsi, karya yang
/// dipamerkan. Isian disimpan di [StudioStore.draftEvent].
class BuatEventStep1Screen extends StatefulWidget {
  const BuatEventStep1Screen({
    super.key,
    required this.onClose,
    required this.onLanjut,
    this.onUnggahKarya,
  });

  final VoidCallback onClose;
  final VoidCallback onLanjut;
  final VoidCallback? onUnggahKarya;

  @override
  State<BuatEventStep1Screen> createState() => _BuatEventStep1ScreenState();
}

class _BuatEventStep1ScreenState extends State<BuatEventStep1Screen> {
  static const _tema = [
    'Pameran Tunggal', 'Pameran Bersama', 'Lelang Amal', 'Open Studio', 'Workshop & Pameran',
  ];

  final _draft = StudioStore.instance.draftEvent;
  late final _nama = TextEditingController(text: _draft.nama);
  late final _deskripsi = TextEditingController(text: _draft.deskripsi);
  String? _error;

  @override
  void dispose() {
    _nama.dispose();
    _deskripsi.dispose();
    super.dispose();
  }

  Future<void> _pilihKarya() async {
    final hasil = await showKaryaPicker(
      context,
      multi: true,
      awal: _draft.karya,
      onUnggahBaru: widget.onUnggahKarya,
    );
    if (hasil != null) setState(() => _draft.karya = hasil);
  }

  void _lanjut() {
    _draft.nama = _nama.text.trim();
    _draft.deskripsi = _deskripsi.text.trim();
    if (_draft.nama.length < 3) {
      setState(() => _error = 'Isi nama event (minimal 3 karakter).');
      return;
    }
    if (_draft.deskripsi.isEmpty) {
      setState(() => _error = 'Isi deskripsi event.');
      return;
    }
    if (_draft.karya.isEmpty) {
      setState(() => _error = 'Pilih minimal 1 karya yang dipamerkan.');
      return;
    }
    setState(() => _error = null);
    widget.onLanjut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close)),
        title: Text('Buat Event', style: AppTextStyles.headlineSm),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: [
          const EventStepper(currentStep: 1),
          const SizedBox(height: AppSpacing.md),
          EventSectionCard(
            title: 'Informasi Event',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                eventLabel('Nama event'),
                TextField(controller: _nama, decoration: eventDekor('mis. Jejak Cahaya Nusantara')),
                const SizedBox(height: AppSpacing.sm),
                eventLabel('Jenis acara'),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final t in _tema)
                      ChoiceChip(
                        label: Text(t),
                        selected: _draft.tema == t,
                        onSelected: (_) => setState(() => _draft.tema = t),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                eventLabel('Deskripsi'),
                TextField(
                  controller: _deskripsi,
                  maxLines: 4,
                  decoration: eventDekor('Ceritakan konsep dan highlight pameran'),
                ),
              ],
            ),
          ),
          EventSectionCard(
            title: 'Karya yang Dipamerkan',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_draft.karya.isEmpty)
                  Text(
                    'Belum ada karya dipilih. Hanya karya terverifikasi yang bisa dipamerkan.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                  )
                else
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _draft.karya.length,
                      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
                      itemBuilder: (context, i) {
                        final k = _draft.karya[i];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: SizedBox(width: 80, height: 96, child: KaryaImage(karya: k)),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _pilihKarya,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: Text(_draft.karya.isEmpty ? 'Pilih Karya' : 'Ubah Pilihan (${_draft.karya.length})'),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  child: Text('SR', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PENYELENGGARA', style: AppTextStyles.overline.copyWith(color: AppColors.muted)),
                      Text('Sanggar Rupa Nusantara', style: AppTextStyles.labelMd),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
          ],
        ],
      ),
      bottomNavigationBar: EventBottomBar(lanjutLabel: 'Lanjut ke Jadwal', onLanjut: _lanjut),
    );
  }
}
