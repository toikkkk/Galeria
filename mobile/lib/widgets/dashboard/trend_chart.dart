import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/format.dart';

/// Dua mode grafik penjualan, satu tone emas GALERIA, dibedakan oleh BENTUK + sumbu:
/// - [karya]: batang emas, sumbu angka bulat (jumlah karya terjual)
/// - [omzet]: garis + area (emas, senada dengan karya; dibedakan oleh bentuk), sumbu Rupiah ringkas
enum ChartMode {
  karya(AppColors.accent),
  omzet(AppColors.accent);

  const ChartMode(this.warna);
  final Color warna;
}

/// Grafik 12 bulan (urut lama -> baru), dilukis dengan CustomPainter (tanpa
/// paket chart). Ketuk / geser untuk memilih bulan; bulan terpilih diberi
/// tooltip nilai.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.values,
    required this.labels,
    required this.mode,
    required this.selected,
    required this.onSelect,
    this.height = 190,
  });

  final List<double> values;
  final List<String> labels;
  final ChartMode mode;
  final int selected;
  final ValueChanged<int> onSelect;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, c) {
          final geo = _ChartGeometry(Size(c.maxWidth, height), values.length);
          void pick(Offset p) {
            if (values.isEmpty) return;
            onSelect(geo.indexAt(p.dx));
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => pick(d.localPosition),
            onHorizontalDragUpdate: (d) => pick(d.localPosition),
            child: CustomPaint(
              painter: TrendChartPainter(
                values: values,
                labels: labels,
                mode: mode,
                selected: selected,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChartGeometry {
  _ChartGeometry(this.size, this.n);

  final Size size;
  final int n;

  static const left = 44.0, right = 6.0, top = 30.0, bottom = 20.0;

  Rect get plot =>
      Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
  double get slot => n == 0 ? plot.width : plot.width / n;
  double centerX(int i) => plot.left + slot * (i + 0.5);

  int indexAt(double dx) => ((dx - plot.left) / slot).floor().clamp(0, n - 1);
}

/// Batas atas sumbu yang "rapi" supaya tick tidak berupa angka aneh.
double _niceMax(double max, ChartMode mode) {
  if (max <= 0) return mode == ChartMode.karya ? 4 : 1000000;
  if (mode == ChartMode.karya) {
    final m = max.ceil();
    return (m.isOdd ? m + 1 : m).clamp(4, 1 << 30).toDouble();
  }
  // omzet: bulatkan ke atas ke 1 / 2 / 5 x 10^k
  var p = 1.0;
  while (p * 10 <= max) {
    p *= 10;
  }
  for (final f in [1, 2, 5, 10]) {
    if (p * f >= max) return p * f;
  }
  return p * 10;
}

class TrendChartPainter extends CustomPainter {
  TrendChartPainter({
    required this.values,
    required this.labels,
    required this.mode,
    required this.selected,
  });

  final List<double> values;
  final List<String> labels;
  final ChartMode mode;
  final int selected;

  TextPainter _text(
    String s, {
    double size = 9,
    Color? color,
    FontWeight? weight,
    double? maxWidth,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: color ?? AppColors.muted,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth ?? double.infinity);
    return tp;
  }

  String _yLabel(double v) => mode == ChartMode.karya
      ? v.round().toString()
      : formatRupiahRingkas(v.round());

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    final geo = _ChartGeometry(size, n);
    final plot = geo.plot;
    final niceMax = _niceMax(
      n == 0 ? 0 : values.reduce((a, b) => a > b ? a : b),
      mode,
    );
    double yOf(double v) =>
        plot.bottom - plot.height * (v / niceMax).clamp(0.0, 1.0);

    // grid + label sumbu Y (0, 1/2, max)
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = plot.bottom - plot.height * f;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final tp = _text(_yLabel(niceMax * f), size: 9, maxWidth: plot.left - 6);
      tp.paint(canvas, Offset(plot.left - 6 - tp.width, y - tp.height / 2));
    }
    if (n == 0) return;

    // label bulan (terpilih ditebalkan)
    for (var i = 0; i < n; i++) {
      final isSel = i == selected;
      final tp = _text(
        i < labels.length ? labels[i] : '',
        size: 8.5,
        color: isSel ? mode.warna : AppColors.muted,
        weight: isSel ? FontWeight.w800 : FontWeight.w500,
        maxWidth: geo.slot + 4,
      );
      tp.paint(canvas, Offset(geo.centerX(i) - tp.width / 2, plot.bottom + 5));
    }

    if (mode == ChartMode.karya) {
      _paintBars(canvas, geo, yOf);
    } else {
      _paintLine(canvas, geo, yOf, size);
    }
    _paintTooltip(canvas, geo, yOf, size);
  }

  void _paintBars(
    Canvas canvas,
    _ChartGeometry geo,
    double Function(double) yOf,
  ) {
    final plot = geo.plot;
    final barW = (geo.slot * 0.58).clamp(4.0, 20.0);
    for (var i = 0; i < values.length; i++) {
      final isSel = i == selected;
      final cx = geo.centerX(i);
      final top = yOf(values[i]);
      final h = (plot.bottom - top).clamp(
        values[i] > 0 ? 3.0 : 0.0,
        plot.height,
      );
      final rect = Rect.fromLTWH(cx - barW / 2, plot.bottom - h, barW, h);
      if (values[i] <= 0) {
        // stub tipis penanda "tidak ada penjualan"
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - barW / 2, plot.bottom - 2, barW, 2),
            const Radius.circular(1),
          ),
          Paint()..color = AppColors.border,
        );
        continue;
      }
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(5),
          topRight: const Radius.circular(5),
        ),
        Paint()
          ..color = isSel ? mode.warna : mode.warna.withValues(alpha: 0.38),
      );
    }
  }

  void _paintLine(
    Canvas canvas,
    _ChartGeometry geo,
    double Function(double) yOf,
    Size size,
  ) {
    final plot = geo.plot;
    final pts = [
      for (var i = 0; i < values.length; i++)
        Offset(geo.centerX(i), yOf(values[i])),
    ];

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final mid = (pts[i - 1].dx + pts[i].dx) / 2;
      line.cubicTo(mid, pts[i - 1].dy, mid, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.dx, plot.bottom)
      ..lineTo(pts.first.dx, plot.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            mode.warna.withValues(alpha: 0.32),
            mode.warna.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, plot.top, size.width, plot.height)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = mode.warna
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final fill = Paint()..color = Colors.white;
    final stroke = Paint()
      ..color = mode.warna
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < pts.length; i++) {
      if (i == selected) continue;
      canvas.drawCircle(pts[i], 3, fill);
      canvas.drawCircle(pts[i], 3, stroke);
    }
  }

  void _paintTooltip(
    Canvas canvas,
    _ChartGeometry geo,
    double Function(double) yOf,
    Size size,
  ) {
    if (selected < 0 || selected >= values.length) return;
    final plot = geo.plot;
    final cx = geo.centerX(selected);
    final cy = yOf(values[selected]);

    // garis bantu putus-putus + titik sorot
    final guide = Paint()
      ..color = mode.warna.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var y = cy + 6; y < plot.bottom; y += 6) {
      canvas.drawLine(
        Offset(cx, y),
        Offset(cx, (y + 3).clamp(0, plot.bottom)),
        guide,
      );
    }
    if (mode == ChartMode.omzet) {
      canvas.drawCircle(
        Offset(cx, cy),
        6,
        Paint()..color = mode.warna.withValues(alpha: 0.25),
      );
      canvas.drawCircle(Offset(cx, cy), 4.5, Paint()..color = mode.warna);
      canvas.drawCircle(
        Offset(cx, cy),
        4.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    final nilai = mode == ChartMode.karya
        ? '${values[selected].round()} karya'
        : formatRupiahRingkas(values[selected].round());
    final bulan = selected < labels.length ? labels[selected] : '';
    final tp = _text(
      '$bulan · $nilai',
      size: 10.5,
      color: Colors.white,
      weight: FontWeight.w700,
    );
    const padH = 8.0, padV = 4.0;
    final w = tp.width + padH * 2, h = tp.height + padV * 2;
    final x = (cx - w / 2).clamp(0.0, size.width - w);
    final y = (cy - h - 8).clamp(0.0, size.height);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = AppColors.primary);
    tp.paint(canvas, Offset(x + padH, y + padV));
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter old) =>
      old.values != values ||
      old.mode != mode ||
      old.selected != selected ||
      old.labels != labels;
}
