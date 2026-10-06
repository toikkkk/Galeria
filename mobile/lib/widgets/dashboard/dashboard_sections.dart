import 'package:flutter/material.dart';

import '../../models/dashboard_seniman.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';

/// Kartu putih standar dashboard dengan judul section.
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.headlineMd),
          if (subtitle != null)
            Text(
              subtitle!,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
            ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Label kecil penanda data sintetis / elemen contoh.
class DataContohBadge extends StatelessWidget {
  const DataContohBadge({super.key, this.label = 'DATA CONTOH'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: AppTextStyles.overline.copyWith(
          fontSize: 9,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

/// Segmented control periode 30 / 90 / 365 hari.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: 30, label: Text('30 hari')),
        ButtonSegment(value: 90, label: Text('90 hari')),
        ButtonSegment(value: 365, label: Text('365 hari')),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

Widget _kosong(String teks) => Padding(
  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
  child: Text(
    teks,
    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
  ),
);

enum _Tab { aliran, pembeli, pasar }

/// Satu kartu bertab yang menggabungkan "Aliran Terlaris", "Siapa Pembelimu"
/// dan "Sedang Ramai di Pasar" supaya halaman tidak terlalu panjang.
/// Tab "Pembeli" disembunyikan bila segmen belum tersedia (`tersedia: false`).
/// Hanya statistik deskriptif -- bukan saran harga / prediksi.
class AnalitikCard extends StatefulWidget {
  const AnalitikCard({
    super.key,
    required this.aliran,
    required this.segmen,
    required this.tren,
  });

  final List<AliranSeniman> aliran;
  final SegmenPembeliHasil segmen;
  final TrenPasar tren;

  @override
  State<AnalitikCard> createState() => _AnalitikCardState();
}

class _AnalitikCardState extends State<AnalitikCard> {
  _Tab _tab = _Tab.aliran;

  List<_Tab> get _tabs => [
    _Tab.aliran,
    if (widget.segmen.tersedia) _Tab.pembeli,
    _Tab.pasar,
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final aktif = tabs.contains(_tab) ? _tab : tabs.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analitik Penjualan', style: AppTextStyles.headlineMd),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              children: [
                for (final t in tabs)
                  Expanded(
                    child: _TabButton(
                      icon: switch (t) {
                        _Tab.aliran => Icons.palette_outlined,
                        _Tab.pembeli => Icons.people_outline,
                        _Tab.pasar => Icons.trending_up,
                      },
                      label: switch (t) {
                        _Tab.aliran => 'Aliran',
                        _Tab.pembeli => 'Pembeli',
                        _Tab.pasar => 'Pasar',
                      },
                      aktif: t == aktif,
                      onTap: () => setState(() => _tab = t),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: switch (aktif) {
              _Tab.aliran => _AliranTab(items: widget.aliran),
              _Tab.pembeli => _PembeliTab(hasil: widget.segmen),
              _Tab.pasar => _PasarTab(tren: widget.tren),
            },
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.aktif,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: aktif ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: aktif ? AppColors.accent : AppColors.muted,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMd.copyWith(
                  color: aktif ? Colors.white : AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip kecil berwarna (mis. selisih harga vs pasar, lonjakan).
class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.warna});

  final String text;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.overline.copyWith(
          fontSize: 9.5,
          color: warna,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.nilai, required this.warna});

  final double nilai; // 0..1
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: LinearProgressIndicator(
        value: nilai.clamp(0.0, 1.0),
        minHeight: 6,
        backgroundColor: AppColors.surfaceContainer,
        color: warna,
      ),
    );
  }
}

/// Tab "Aliran": aliran terlaris + selisih harga rata-rata vs rata-rata pasar (deskriptif).
class _AliranTab extends StatelessWidget {
  const _AliranTab({required this.items});

  final List<AliranSeniman> items;

  @override
  Widget build(BuildContext context) {
    final tampil = items.take(4).toList();
    if (tampil.isEmpty) return _kosong('Belum ada penjualan.');
    final maks = tampil.map((a) => a.nTerjual).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final a in tampil)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rapikanNamaAliran(a.styleName),
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelMd,
                      ),
                    ),
                    Text('${a.nTerjual} terjual', style: AppTextStyles.labelSm),
                  ],
                ),
                const SizedBox(height: 4),
                _Bar(
                  nilai: maks == 0 ? 0 : a.nTerjual / maks,
                  warna: AppColors.accent,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Harga rata-rata ${formatRupiahRingkas(a.hargaRata2Idr)}',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (a.selisihPct != null)
                      _Chip(
                        text: '${formatPersen(a.selisihPct)} vs pasar',
                        warna: a.selisihPct! >= 0
                            ? AppColors.success
                            : AppColors.muted,
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tab "Pembeli": ringkasan segmen pembeli (bukan profil pasti per orang).
class _PembeliTab extends StatelessWidget {
  const _PembeliTab({required this.hasil});

  final SegmenPembeliHasil hasil;

  @override
  Widget build(BuildContext context) {
    final items = hasil.items;
    if (items.isEmpty) return _kosong('Belum ada pembeli.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pembelimu didominasi ${items.first.segmenNama}. Segmen hanya ringkasan deskriptif, bukan profil pasti per orang.',
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.muted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final s in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.segmenNama,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelMd,
                      ),
                    ),
                    Text(
                      '${s.nPembeli} · ${formatPersen(s.porsiPct, tandaPlus: false)}',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _Bar(nilai: (s.porsiPct ?? 0) / 100, warna: AppColors.primary),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tab "Pasar": 3 pelukis & aliran paling ramai 30 hari terakhir (seluruh seniman).
class _PasarTab extends StatelessWidget {
  const _PasarTab({required this.tren});

  final TrenPasar tren;

  @override
  Widget build(BuildContext context) {
    final seniman = tren.senimanRamai.take(3).toList();
    final aliran = tren.aliranRamai.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '30 hari terakhir, seluruh seniman',
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.muted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'PELUKIS RAMAI',
          style: AppTextStyles.overline.copyWith(color: AppColors.accent),
        ),
        if (seniman.isEmpty) _kosong('Belum ada data.'),
        for (var i = 0; i < seniman.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: i == 0
                      ? AppColors.accent
                      : AppColors.surfaceContainer,
                  child: Text(
                    '${i + 1}',
                    style: AppTextStyles.labelSm.copyWith(
                      color: i == 0 ? Colors.white : AppColors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seniman[i].displayName,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelMd,
                      ),
                      Text(
                        '${seniman[i].nTerjual30Hari} terjual · ${formatRupiahRingkas(seniman[i].hargaRata2Idr)}',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _Chip(
                  text:
                      '${seniman[i].lonjakan >= 1 ? '↑' : '↓'} ${seniman[i].lonjakan.toStringAsFixed(1).replaceAll('.', ',')}x',
                  warna: seniman[i].lonjakan >= 1
                      ? AppColors.success
                      : AppColors.muted,
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'ALIRAN RAMAI',
          style: AppTextStyles.overline.copyWith(color: AppColors.accent),
        ),
        const SizedBox(height: 6),
        if (aliran.isEmpty) _kosong('Belum ada data.'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final a in aliran)
              _Chip(
                text:
                    '${rapikanNamaAliran(a.styleName)} · ${formatPersen(a.porsiPct, tandaPlus: false)}',
                warna: AppColors.primary,
              ),
          ],
        ),
      ],
    );
  }
}
