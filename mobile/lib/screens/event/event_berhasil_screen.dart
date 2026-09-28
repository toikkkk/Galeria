import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_2/.../galeria_event_berhasil_diterbitkan/code.html
class EventBerhasilScreen extends StatelessWidget {
  const EventBerhasilScreen({super.key, required this.onKelolaEvent, required this.onKembaliDasbor});

  final VoidCallback onKelolaEvent;
  final VoidCallback onKembaliDasbor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter, vertical: AppSpacing.md),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: AppColors.accentSoft.withValues(alpha: 0.6), shape: BoxShape.circle),
                          child: const Icon(Icons.event_available, color: AppColors.accent, size: 26),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Event Berhasil Diterbitkan',
                          textAlign: TextAlign.center, style: AppTextStyles.headlineLg),
                      const SizedBox(height: 4),
                      Text(
                        'Event kamu sedang ditinjau tim kurator dan akan tayang dalam 1x24 jam.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // Event summary card
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.accentSoft, width: 1.5),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  height: 140,
                                  width: double.infinity,
                                  color: AppColors.inverseSurface,
                                  child: const Icon(Icons.image, color: Colors.white24, size: 40),
                                ),
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(AppRadius.full)),
                                    child: Text('PAMERAN GALERI FISIK',
                                        style: AppTextStyles.overline
                                            .copyWith(color: AppColors.accentSoft, fontSize: 9)),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 10,
                                  right: 10,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Sanggar Rupa Nusantara',
                                          style: TextStyle(color: Colors.white, fontSize: 11)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: Colors.black45,
                                            borderRadius: BorderRadius.circular(3)),
                                        child: const Text('PRO ACCREDITED',
                                            style: TextStyle(color: Color(0xFFF3E2A8), fontSize: 9)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Pameran Tunggal: Jejak Cahaya Nusantara',
                                      style: AppTextStyles.headlineSm),
                                  const Divider(height: AppSpacing.md),
                                  _metaRow(Icons.calendar_today, '20 - 26 Okt 2026 · 10:00 - 20:00 WIB'),
                                  const SizedBox(height: 6),
                                  _metaRow(Icons.location_on_outlined, 'Galeri Nasional Indonesia, Jakarta Pusat'),
                                  const SizedBox(height: 6),
                                  _metaRow(Icons.confirmation_number_outlined,
                                      '150 tiket · mulai Rp 50.000'),
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Status Publikasi:',
                                          style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                            color: Colors.amber.shade50,
                                            border: Border.all(color: Colors.amber.shade200),
                                            borderRadius: BorderRadius.circular(AppRadius.full)),
                                        child: Text('Menunggu Kurasi',
                                            style: AppTextStyles.labelSm
                                                .copyWith(color: Colors.amber.shade800)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Share card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BAGIKAN EVENT',
                                style: AppTextStyles.overline.copyWith(color: AppColors.accent)),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _shareIcon(Icons.link, 'Salin Tautan'),
                                _shareIcon(Icons.chat_bubble_outline, 'WhatsApp'),
                                _shareIcon(Icons.photo_camera_outlined, 'Instagram'),
                                _shareIcon(Icons.groups_outlined, 'Komunitas'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                onPressed: onKelolaEvent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('Kelola Event'),
                    SizedBox(width: AppSpacing.xs),
                    Icon(Icons.arrow_forward, size: 16, color: AppColors.accentSoft),
                  ],
                ),
              ),
              TextButton(
                onPressed: onKembaliDasbor,
                child: Text('Kembali ke Dasbor',
                    style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodySm)),
        ],
      );

  Widget _shareIcon(IconData icon, String label) => Column(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
        ],
      );
}
