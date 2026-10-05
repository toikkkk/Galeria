import 'package:flutter/material.dart';

import '../../models/dashboard_seniman.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import 'trend_chart.dart';

/// Kartu "Penjualan 12 Bulan": toggle Karya (batang emas) / Omzet (garis hijau),
/// ringkasan (total, rata-rata/bulan, puncak) dan grafik interaktif.
class SalesChartCard extends StatefulWidget {
  const SalesChartCard({super.key, required this.bulanan});

  final List<PenjualanBulan> bulanan;

  @override
  State<SalesChartCard> createState() => _SalesChartCardState();
}

class _SalesChartCardState extends State<SalesChartCard> {
  ChartMode _mode = ChartMode.karya;
  int? _selected; // null = bulan terakhir

  int get _sel {
    final n = widget.bulanan.length;
    if (n == 0) return 0;
    return (_selected ?? n - 1).clamp(0, n - 1);
  }

  double _nilai(PenjualanBulan b) =>
      _mode == ChartMode.karya ? b.nTerjual.toDouble() : b.omzetIdr.toDouble();

  String _fmt(num v) => _mode == ChartMode.karya
      ? '${v.round()} karya'
      : formatRupiahRingkas(v.round());

  @override
  Widget build(BuildContext context) {
    final data = widget.bulanan;
    final values = [for (final b in data) _nilai(b)];
    final labels = [for (final b in data) namaBulanSingkat(b.bulan)];
    final total = values.fold<double>(0, (a, b) => a + b);
    final rata = data.isEmpty ? 0.0 : total / data.length;
    var puncakIdx = 0;
    for (var i = 0; i < values.length; i++) {
      if (values[i] > values[puncakIdx]) puncakIdx = i;
    }
    final warna = _mode.warna;
    final adaPenjualan = total > 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // garis warna penanda mode aktif
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 4,
            color: warna,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Penjualan 12 Bulan',
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.headlineMd,
                          ),
                          Text(
                            _mode == ChartMode.karya
                                ? 'Jumlah karya terjual per bulan'
                                : 'Omzet (Rp) per bulan',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _ModeToggle(
                  mode: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _Kpi(
                        label: 'TOTAL',
                        value: _fmt(total),
                        warna: warna,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _Kpi(
                        label: 'RATA-RATA/BULAN',
                        value: _mode == ChartMode.karya
                            ? '${rata.toStringAsFixed(1).replaceAll('.', ',')} karya'
                            : _fmt(rata),
                        warna: warna,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _Kpi(
                        label: 'PUNCAK',
                        value: adaPenjualan
                            ? '${labels[puncakIdx]} · ${_fmt(values[puncakIdx])}'
                            : '-',
                        warna: warna,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: TrendChart(
                key: ValueKey(_mode),
                values: values,
                labels: labels,
                mode: _mode,
                selected: _sel,
                onSelect: (i) => setState(() => _selected = i),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              'Ketuk atau geser grafik untuk melihat nilai tiap bulan.',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.muted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final ChartMode mode;
  final ValueChanged<ChartMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tombol(ChartMode m, IconData icon, String label) {
      final aktif = m == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(m),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: aktif ? m.warna : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: aktif ? Colors.white : AppColors.muted,
                ),
                const SizedBox(width: 6),
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
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        children: [
          tombol(ChartMode.karya, Icons.bar_chart_rounded, 'Karya terjual'),
          tombol(ChartMode.omzet, Icons.show_chart_rounded, 'Omzet (Rp)'),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.warna});

  final String label, value;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.overline.copyWith(
              fontSize: 8,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTextStyles.labelMd.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
