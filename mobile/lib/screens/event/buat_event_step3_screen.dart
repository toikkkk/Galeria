import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/event_stepper.dart';

/// Konversi dari
/// docs/design/role_seniman_2/.../galeria_buat_event_langkah_3_dari_3_tiket_publikasi/code.html
class BuatEventStep3Screen extends StatefulWidget {
  const BuatEventStep3Screen({super.key, required this.onKembali, required this.onTerbitkan});

  final VoidCallback onKembali;
  final VoidCallback onTerbitkan;

  @override
  State<BuatEventStep3Screen> createState() => _BuatEventStep3ScreenState();
}

class _BuatEventStep3ScreenState extends State<BuatEventStep3Screen> {
  bool _berbayar = true;
  bool _direktoriKolektor = true;
  bool _siarkanKomunitas = true;
  bool _bannerUtama = true;
  bool _setujuKetentuan = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onKembali, icon: const Icon(Icons.arrow_back)),
        title: Text('Tiket & Publikasi', style: AppTextStyles.headlineSm),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter, AppSpacing.sm, AppSpacing.screenGutter, AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EventStepper(currentStep: 3),
            const SizedBox(height: AppSpacing.lg),
            Text('Model Akses Pameran', style: AppTextStyles.labelMd),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _modelCard(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Gratis',
                    subtitle: 'Akses terbuka untuk umum',
                    selected: !_berbayar,
                    onTap: () => setState(() => _berbayar = false),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _modelCard(
                    icon: Icons.sell_outlined,
                    title: 'Berbayar',
                    subtitle: 'Monetisasi tiket & tur privat',
                    selected: _berbayar,
                    onTap: () => setState(() => _berbayar = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
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
                    const Icon(Icons.local_activity_outlined, size: 20, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text('Kategori Tiket', style: AppTextStyles.headlineSm),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  _ticketRow('Tiket Reguler', 'Umum', 'Rp 50.000', '120'),
                  const SizedBox(height: AppSpacing.sm),
                  _ticketRow('Kurator VIP', 'VIP Access', 'Rp 250.000', '30',
                      note: 'Termasuk katalog cetak bertanda tangan & tur privat.'),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah Jenis Tiket Baru'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
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
                    const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text('Proyeksi Hasil Penjualan', style: AppTextStyles.headlineSm),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  _projectionRow('Pendapatan Kotor (120x Rp50rb + 30x Rp250rb)', 'Rp 13.500.000'),
                  _projectionRow('Biaya Layanan & Verifikasi GALERIA (5%)', '- Rp 675.000',
                      color: AppColors.error),
                  const Divider(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estimasi Bersih Seniman', style: AppTextStyles.labelMd),
                          Text('PENCAIRAN TERJADWAL',
                              style: AppTextStyles.overline.copyWith(color: AppColors.accent)),
                        ],
                      ),
                      Text('Rp 12.825.000',
                          style: AppTextStyles.headlineMd.copyWith(
                              color: AppColors.accent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
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
                    const Icon(Icons.campaign_outlined, size: 20, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text('Publikasi & Distribusi', style: AppTextStyles.headlineSm),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  _toggleRow('Tampilkan di Direktori Kolektor',
                      'Kurasi agenda utama bagi 50.000+ patron seni aktif.', _direktoriKolektor,
                      (v) => setState(() => _direktoriKolektor = v)),
                  const Divider(),
                  _toggleRow('Siarkan ke Komunitas Kolektif',
                      'Notifikasi aplikasi ke anggota Kolektif Abstrak & Realis.', _siarkanKomunitas,
                      (v) => setState(() => _siarkanKomunitas = v)),
                  const Divider(),
                  _toggleRow('Sorotan Banner Utama Galeria (PRO)',
                      'Posisi hero editorial selama 7 hari pameran dibuka.', _bannerUtama,
                      (v) => setState(() => _bannerUtama = v), highlight: true),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _setujuKetentuan,
              onChanged: (v) => setState(() => _setujuKetentuan = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'Saya menyatakan kurasi karya orisinal, siap menyelenggarakan acara sesuai jadwal, dan tunduk pada Standar Etik & Kualitas Penyelenggara GALERIA.',
                style: AppTextStyles.bodySm,
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
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Pratinjau'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _setujuKetentuan ? widget.onTerbitkan : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('Terbitkan Event'),
                      SizedBox(width: AppSpacing.xs),
                      Icon(Icons.arrow_forward, size: 16),
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

  Widget _modelCard({
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
                  radius: 16,
                  backgroundColor: selected ? AppColors.accent : AppColors.surfaceContainer,
                  child: Icon(icon, size: 16, color: selected ? Colors.white : AppColors.onSurface),
                ),
                if (selected) const Icon(Icons.check_circle, color: AppColors.accent, size: 18),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(title, style: AppTextStyles.headlineSm),
            Text(subtitle, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _ticketRow(String name, String badge, String price, String kuota, {String? note}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration:
          BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(name, style: AppTextStyles.labelMd),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.full)),
                  child: Text(badge, style: AppTextStyles.overline.copyWith(fontSize: 9)),
                ),
              ]),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(children: [
            Text('Tarif: ', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
            Text(price, style: AppTextStyles.labelMd),
            const SizedBox(width: AppSpacing.sm),
            Text('Kuota: ', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
            Text(kuota, style: AppTextStyles.labelMd),
          ]),
          if (note != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.auto_awesome, size: 13, color: AppColors.accent),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(note,
                      style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.accent, fontStyle: FontStyle.italic, fontSize: 11))),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _projectionRow(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Text(label, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted))),
            Text(value,
                style: AppTextStyles.labelMd.copyWith(color: color ?? AppColors.onSurface)),
          ],
        ),
      );

  Widget _toggleRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged,
      {bool highlight = false}) {
    return Container(
      padding: highlight ? const EdgeInsets.all(AppSpacing.xs) : EdgeInsets.zero,
      decoration: highlight
          ? BoxDecoration(
              color: AppColors.accentSoft.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.md))
          : null,
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
          Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: highlight ? AppColors.accent : AppColors.primary),
        ],
      ),
    );
  }
}
