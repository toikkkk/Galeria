import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/event_stepper.dart';

/// Konversi dari
/// docs/design/role_seniman_2/.../galeria_buat_event_langkah_2_dari_3_jadwal_lokasi/code.html
class BuatEventStep2Screen extends StatefulWidget {
  const BuatEventStep2Screen({super.key, required this.onKembali, required this.onLanjut});

  final VoidCallback onKembali;
  final VoidCallback onLanjut;

  @override
  State<BuatEventStep2Screen> createState() => _BuatEventStep2ScreenState();
}

class _BuatEventStep2ScreenState extends State<BuatEventStep2Screen> {
  bool _fisik = true;
  bool _berulangHarian = true;
  bool _tutupOtomatis = true;
  int _kuota = 150;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onKembali, icon: const Icon(Icons.arrow_back)),
        title: Text('Jadwal & Lokasi Pameran', style: AppTextStyles.headlineSm),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter, AppSpacing.sm, AppSpacing.screenGutter, AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EventStepper(currentStep: 2),
            const SizedBox(height: AppSpacing.lg),
            // Format acara
            Text('Format Acara *', style: AppTextStyles.labelMd),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _formatCard(
                    icon: Icons.museum_outlined,
                    title: 'Pameran Fisik',
                    subtitle: 'Tatap muka langsung di galeri',
                    selected: _fisik,
                    onTap: () => setState(() => _fisik = true),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _formatCard(
                    icon: Icons.videocam_outlined,
                    title: 'Virtual / Live',
                    subtitle: 'Streaming & tur ruang 3D',
                    selected: !_fisik,
                    onTap: () => setState(() => _fisik = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _card(
              icon: Icons.event_note_outlined,
              title: 'Jadwal Pelaksanaan',
              child: Column(
                children: [
                  Row(children: [
                    Expanded(child: _readonlyField('TANGGAL MULAI', '20 Okt 2026', Icons.calendar_today)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _readonlyField('JAM BUKA', '10:00 WIB', Icons.schedule)),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    Expanded(
                        child: _readonlyField(
                            'TANGGAL BERAKHIR', '26 Okt 2026', Icons.event_available)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: _readonlyField(
                            'JAM TUTUP', '20:00 WIB', Icons.history_toggle_off)),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  _readonlyField('ZONA WAKTU OPERASIONAL', 'WIB (GMT+7) — Waktu Indonesia Barat',
                      Icons.public),
                  const SizedBox(height: AppSpacing.sm),
                  _toggleRow(
                    title: 'Pameran Berulang Harian',
                    subtitle:
                        'Pameran buka setiap hari pada rentang jam yang sama sepanjang durasi kurasi berlangsung.',
                    value: _berulangHarian,
                    onChanged: (v) => setState(() => _berulangHarian = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _card(
              icon: Icons.location_on_outlined,
              title: 'Lokasi Pameran',
              child: Column(
                children: [
                  _readonlyField('NAMA GALERI / TEMPAT *', 'Galeri Nasional Indonesia', null),
                  const SizedBox(height: AppSpacing.sm),
                  _readonlyField('ALAMAT LENGKAP *',
                      'Jl. Medan Merdeka Timur No.14, Gambir, Jakarta Pusat', null, maxLines: 2),
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    Expanded(child: _readonlyField('PROVINSI', 'DKI Jakarta', null)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _readonlyField('KOTA / WILAYAH', 'Jakarta Pusat', null)),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Container(
                      height: 140,
                      color: AppColors.surfaceContainerHigh,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.pin_drop, color: AppColors.accent),
                          SizedBox(height: 4),
                          Text('Peta lokasi (placeholder)', style: TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _card(
              icon: Icons.groups_outlined,
              title: 'Kapasitas & Kuota Pengunjung',
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                        color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text('Batas Pengunjung Harian'),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => setState(() {
                                if (_kuota > 25) _kuota -= 25;
                              }),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('$_kuota', style: AppTextStyles.headlineSm),
                            IconButton(
                              onPressed: () => setState(() => _kuota += 25),
                              icon: const Icon(Icons.add_circle, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _toggleRow(
                    title: 'Tutup Otomatis Saat Penuh',
                    subtitle:
                        'Reservasi publik dan penjualan tiket akan dikunci otomatis begitu kuota harian terpenuhi.',
                    value: _tutupOtomatis,
                    onChanged: (v) => setState(() => _tutupOtomatis = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: widget.onKembali, child: const Text('Kembali')),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: widget.onLanjut,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('Lanjut ke Tiket'),
                      SizedBox(width: AppSpacing.xs),
                      Icon(Icons.arrow_forward, size: 16, color: AppColors.accentSoft),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formatCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        height: 128,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft.withValues(alpha: 0.5) : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: selected ? Border.all(color: AppColors.accent, width: 2) : null,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: selected ? AppColors.accent : AppColors.surfaceContainerHigh,
                  child: Icon(icon, size: 18, color: selected ? Colors.white : AppColors.onSurfaceVariant),
                ),
                if (selected) const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
              ],
            ),
            const Spacer(),
            Text(title, style: AppTextStyles.headlineSm),
            Text(subtitle, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _card({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 20, color: AppColors.onSurface),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.headlineSm),
          ]),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  Widget _readonlyField(String label, String value, IconData? icon, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSm.copyWith(color: AppColors.muted)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          decoration:
              BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.muted),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(value, style: AppTextStyles.bodyMd, maxLines: maxLines, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelMd),
                Text(subtitle, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary),
        ],
      ),
    );
  }
}
