import 'package:flutter/material.dart';

import '../../models/karya.dart';
import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_2/.../galeria_promosikan_karya/code.html
class PromosikanKaryaScreen extends StatefulWidget {
  const PromosikanKaryaScreen({super.key, required this.karya, required this.onBack, required this.onLanjut});

  final Karya karya;
  final VoidCallback onBack;
  final VoidCallback onLanjut;

  @override
  State<PromosikanKaryaScreen> createState() => _PromosikanKaryaScreenState();
}

class _PromosikanKaryaScreenState extends State<PromosikanKaryaScreen> {
  static const _packages = [
    (hari: '7 Hari', dilihat: 'Perkiraan 1.200 dilihat', harga: 50000, badge: null),
    (hari: '14 Hari', dilihat: 'Perkiraan 2.600 dilihat', harga: 90000, badge: 'Paling Populer'),
    (hari: '30 Hari', dilihat: 'Perkiraan 5.800 dilihat', harga: 170000, badge: 'Maksimal'),
  ];

  int _selected = 1;
  bool _tampilLelang = true;
  bool _tampilBeranda = true;

  @override
  Widget build(BuildContext context) {
    final priceFmt = _packages[_selected].harga;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Promosikan Karya', style: AppTextStyles.headlineSm),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter, AppSpacing.md, AppSpacing.screenGutter, AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Artwork preview
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.asset(widget.karya.assetPath, width: 64, height: 76, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(AppRadius.full)),
                          child: Text('Terverifikasi Asli · Aktif',
                              style: AppTextStyles.labelSm.copyWith(color: AppColors.accent, fontSize: 9)),
                        ),
                        const SizedBox(height: 4),
                        Text(widget.karya.title,
                            style: AppTextStyles.headlineSm, overflow: TextOverflow.ellipsis),
                        Text('Harga Katalog: ${_rupiah(widget.karya.priceIdr)}',
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Pilih Paket Promosi', style: AppTextStyles.headlineMd),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < _packages.length; i++) ...[
              _packageCard(i),
              const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text('Tampil di Ruang Kurasi', style: AppTextStyles.headlineMd),
            Text('Pilih ruang kurasi untuk meningkatkan keterlihatan karya secara tepat sasaran.',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
            const SizedBox(height: AppSpacing.sm),
            _placementTile(
              title: 'Halaman Lelang Teratas',
              subtitle: 'Menduduki banner kuratorial teratas di tab Lelang resmi.',
              value: _tampilLelang,
              onChanged: (v) => setState(() => _tampilLelang = v),
            ),
            const SizedBox(height: AppSpacing.xs),
            _placementTile(
              title: 'Beranda Kolektor',
              subtitle: 'Rekomendasi prioritas pada feed beranda kolektor aktif.',
              value: _tampilBeranda,
              onChanged: (v) => setState(() => _tampilBeranda = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.accent),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                        'Promosi akan aktif dalam waktu 15 menit setelah pembayaran terkonfirmasi.',
                        style: AppTextStyles.bodySm),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter, vertical: AppSpacing.sm),
          decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)]),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL BIAYA PROMOSI',
                      style: AppTextStyles.overline.copyWith(color: AppColors.muted)),
                  Text(_rupiah(priceFmt), style: AppTextStyles.headlineMd),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: widget.onLanjut,
                // Tema global ElevatedButton pakai minimumSize lebar tak
                // terhingga (utk tombol full-width) -- di sini tombolnya
                // jadi anak Row (bukan Expanded), jadi lebarnya harus
                // dibatasi ke ukuran isinya sendiri, kalau tidak Flutter
                // gagal layout ("BoxConstraints forces an infinite width").
                style: ElevatedButton.styleFrom(minimumSize: Size.zero),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('Lanjut ke Pembayaran'),
                    SizedBox(width: AppSpacing.xs),
                    Icon(Icons.arrow_forward, size: 16, color: AppColors.accentSoft),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _packageCard(int i) {
    final pkg = _packages[i];
    final selected = _selected == i;
    return InkWell(
      onTap: () => setState(() => _selected = i),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft.withValues(alpha: 0.4) : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (pkg.badge != null)
              Positioned(
                top: -18,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.full)),
                  child: Text(pkg.badge!,
                      style: AppTextStyles.labelSm.copyWith(color: Colors.white, fontSize: 10)),
                ),
              ),
            Row(
              children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? AppColors.accent : AppColors.muted),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pkg.hari, style: AppTextStyles.headlineSm),
                      Text(pkg.dilihat, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
                Text(_rupiah(pkg.harga), style: AppTextStyles.labelMd),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _rupiah(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp$buf';
  }

  Widget _placementTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.accent),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelMd),
                Text(subtitle, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
