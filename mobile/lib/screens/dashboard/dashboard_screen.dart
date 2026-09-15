import 'package:flutter/material.dart';

import '../../models/karya.dart';
import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_1/.../galeria_dashboard_seniman_galeri/code.html
///
/// Angka saldo/statistik/grafik di sini semuanya CONTOH (placeholder) --
/// belum ada data transaksi nyata dari backend.
///
/// TODO(backend): sambungkan ke `GET /api/pemda`-setara utk seniman (saldo,
/// statistik karya/lelang/pesanan) begitu endpoint-nya ada.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.onUploadKarya,
    this.onNavTap,
    this.onKomunitasTap,
  });

  final VoidCallback? onUploadKarya;
  final ValueChanged<int>? onNavTap;
  final VoidCallback? onKomunitasTap;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _balanceHidden = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Text('GALERIA', style: AppTextStyles.headlineMd),
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text('STUDIO',
                  style: AppTextStyles.overline.copyWith(color: AppColors.accent)),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_outlined)),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile bar
            Row(
              children: [
                Stack(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary,
                      child: Text('SR',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: AppColors.accent),
                        child: const Icon(Icons.verified, size: 10, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sanggar Rupa Nusantara', style: AppTextStyles.headlineSm),
                      Row(
                        children: [
                          Text('Kurator Terakreditasi',
                              style: AppTextStyles.labelSm
                                  .copyWith(color: AppColors.muted)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: CircleAvatar(radius: 1.5, backgroundColor: AppColors.accent),
                          ),
                          Text('Salon Utama',
                              style: AppTextStyles.labelSm
                                  .copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                _iconBadge(Icons.chat_bubble_outline, dotColor: AppColors.accent),
                const SizedBox(width: AppSpacing.xs),
                _iconBadge(Icons.notifications_outlined, dotColor: AppColors.error),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Balance card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.cardInner),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('SALDO REKENING KOLEKTOR',
                              style: AppTextStyles.overline
                                  .copyWith(color: Colors.white60)),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                                _balanceHidden
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 16,
                                color: Colors.white60),
                            onPressed: () =>
                                setState(() => _balanceHidden = !_balanceHidden),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text('KLIRING IDR',
                            style: AppTextStyles.overline
                                .copyWith(color: AppColors.accentSoft, fontSize: 9)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _balanceHidden ? 'Rp ••••••••••' : 'Rp 184.750.000',
                    style: AppTextStyles.displayMd
                        .copyWith(color: Colors.white, fontSize: 28),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.trending_up, size: 16, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text('+Rp 36.200.000',
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.accent)),
                      const SizedBox(width: 4),
                      Text('pekan kurasi ini',
                          style: AppTextStyles.bodySm.copyWith(color: Colors.white60)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: const Text('Tarik Dana'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.schedule, size: 18, color: Colors.white),
                          label: const Text('Riwayat',
                              style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Stat cards
            Row(
              children: [
                Expanded(
                    child: _StatCard(
                        label: 'KARYA AKTIF',
                        icon: Icons.palette_outlined,
                        value: '12',
                        unit: 'lot',
                        footer: 'Koleksi Terpasang')),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: _StatCard(
                        label: 'LELANG',
                        icon: Icons.circle,
                        iconColor: AppColors.accent,
                        iconSize: 8,
                        value: '3',
                        unit: 'Live',
                        unitColor: AppColors.accent,
                        footer: '18 Penawar Aktif',
                        footerColor: AppColors.accent)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: _StatCard(
                        label: 'PESANAN',
                        icon: Icons.inventory_2_outlined,
                        iconColor: AppColors.accent,
                        value: '2',
                        unit: 'Baru',
                        unitColor: AppColors.accent,
                        footer: 'Menunggu Kirim',
                        footerColor: AppColors.accent)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Perlu tindakan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Perlu Tindakan', style: AppTextStyles.headlineMd),
                    const SizedBox(width: 6),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: AppColors.primary,
                      child: Text('2',
                          style: AppTextStyles.labelSm.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
                Text('Prioritas Saluran',
                    style: AppTextStyles.labelSm.copyWith(color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionRow(
              dotColor: AppColors.accent,
              title: '2 pesanan perlu dikemas',
              subtitle: 'Batas waktu pengiriman kurir seni besok, 18:00 WIB',
            ),
            const SizedBox(height: AppSpacing.xs),
            _ActionRow(
              dotColor: AppColors.error,
              title: '1 lelang primer berakhir hari ini',
              subtitle: 'Lot #104: Sang Putri Mahkota Renaisans',
            ),
            const SizedBox(height: AppSpacing.lg),
            // Aksi cepat
            Text('Aksi Cepat', style: AppTextStyles.headlineMd),
            const SizedBox(height: AppSpacing.sm),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.xs,
              mainAxisSpacing: AppSpacing.xs,
              childAspectRatio: 1,
              children: [
                _QuickAction(icon: Icons.brush_outlined, label: 'Unggah Karya', onTap: widget.onUploadKarya),
                _QuickAction(icon: Icons.gavel_outlined, label: 'Buat Lelang'),
                _QuickAction(icon: Icons.campaign_outlined, label: 'Promosikan'),
                _QuickAction(icon: Icons.groups_outlined, label: 'Komunitas', pro: true, onTap: widget.onKomunitasTap),
                _QuickAction(icon: Icons.event_note_outlined, label: 'Buat Event', pro: true),
                _QuickAction(icon: Icons.insights_outlined, label: 'Statistik'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Performa 7 hari
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Performa 7 Hari', style: AppTextStyles.headlineMd),
                      Row(
                        children: [
                          Text('7 Hari Terakhir',
                              style: AppTextStyles.labelSm.copyWith(color: AppColors.muted)),
                          const Icon(Icons.expand_more, size: 16, color: AppColors.muted),
                        ],
                      ),
                    ],
                  ),
                  Text.rich(
                    TextSpan(style: AppTextStyles.bodySm.copyWith(color: AppColors.muted), children: [
                      const TextSpan(text: '14.280', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                      const TextSpan(text: ' Kunjungan Galeri  •  '),
                      const TextSpan(text: '4', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                      const TextSpan(text: ' Karya Terjual'),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _legend('Kunjungan Karya', AppColors.accent),
                      const SizedBox(width: AppSpacing.md),
                      _legend('Penjualan Terverifikasi', AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 100,
                    child: CustomPaint(
                      size: const Size(double.infinity, 100),
                      painter: _TrendChartPainter(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final d in const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'])
                        Text(d,
                            style: AppTextStyles.overline.copyWith(
                                color: d == 'Jum' ? AppColors.accent : AppColors.muted,
                                fontWeight: d == 'Jum' ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Spotlight
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.asset(sampleKarya[3].assetPath,
                        width: 56, height: 56, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LOT UNGGULAN BERJALAN',
                            style: AppTextStyles.overline.copyWith(color: AppColors.accent)),
                        Text('Sang Putri Mahkota Renaisans',
                            style: AppTextStyles.headlineSm.copyWith(
                                fontStyle: FontStyle.italic, fontSize: 16),
                            overflow: TextOverflow.ellipsis),
                        Text.rich(TextSpan(
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                            children: const [
                              TextSpan(text: 'Tawaran Tertinggi: '),
                              TextSpan(
                                  text: 'Rp 48.000.000',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                            ])),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.surfaceContainer,
                    child: const Icon(Icons.arrow_forward, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(onTap: widget.onNavTap, onFab: widget.onUploadKarya),
    );
  }

  Widget _iconBadge(IconData icon, {required Color dotColor}) => Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppColors.surfaceContainerLow),
            child: Icon(icon, size: 18),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
            ),
          ),
        ],
      );

  Widget _legend(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 3, color: color),
          const SizedBox(width: 4),
          Text(label.toUpperCase(),
              style: AppTextStyles.overline.copyWith(fontSize: 9, color: AppColors.muted)),
        ],
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.unit,
    required this.footer,
    this.iconColor = AppColors.muted,
    this.iconSize = 16,
    this.unitColor = AppColors.muted,
    this.footerColor = AppColors.muted,
  });

  final String label, value, unit, footer;
  final IconData icon;
  final Color iconColor, unitColor, footerColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label,
                    style: AppTextStyles.overline.copyWith(fontSize: 9),
                    overflow: TextOverflow.ellipsis),
              ),
              Icon(icon, size: iconSize, color: iconColor),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppTextStyles.headlineLg),
              const SizedBox(width: 4),
              Text(unit, style: AppTextStyles.bodySm.copyWith(color: unitColor)),
            ],
          ),
          Text(footer,
              style: AppTextStyles.overline.copyWith(fontSize: 8.5, color: footerColor),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.dotColor, required this.title, required this.subtitle});

  final Color dotColor;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: AppSpacing.xs),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelMd),
                Text(subtitle,
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, this.pro = false, this.onTap});

  final IconData icon;
  final String label;
  final bool pro;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Stack(
          children: [
            if (pro)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text('PRO',
                      style: TextStyle(
                          fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.surfaceContainer,
                    child: Icon(icon, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(height: 6),
                  Text(label, style: AppTextStyles.labelSm.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Offset p(double x, double y) => Offset(x * w / 320, y * h / 120);

    // grid
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    canvas.drawLine(p(0, 20), p(320, 20), gridPaint);
    canvas.drawLine(p(0, 60), p(320, 60), gridPaint);

    // area fill
    final path = Path()
      ..moveTo(p(10, 90).dx, p(10, 90).dy)
      ..quadraticBezierTo(p(50, 85).dx, p(50, 85).dy, p(90, 70).dx, p(90, 70).dy)
      ..quadraticBezierTo(p(130, 60).dx, p(130, 60).dy, p(170, 50).dx, p(170, 50).dy)
      ..quadraticBezierTo(p(200, 35).dx, p(200, 35).dy, p(230, 20).dx, p(230, 20).dy)
      ..quadraticBezierTo(p(270, 24).dx, p(270, 24).dy, p(310, 28).dx, p(310, 28).dy)
      ..lineTo(p(310, 100).dx, p(310, 100).dy)
      ..lineTo(p(10, 100).dx, p(10, 100).dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accent.withValues(alpha: 0.3), AppColors.accent.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // line
    final linePath = Path()
      ..moveTo(p(10, 90).dx, p(10, 90).dy)
      ..quadraticBezierTo(p(50, 85).dx, p(50, 85).dy, p(90, 70).dx, p(90, 70).dy)
      ..quadraticBezierTo(p(130, 60).dx, p(130, 60).dy, p(170, 50).dx, p(170, 50).dy)
      ..quadraticBezierTo(p(200, 35).dx, p(200, 35).dy, p(230, 20).dx, p(230, 20).dy)
      ..quadraticBezierTo(p(270, 24).dx, p(270, 24).dy, p(310, 28).dx, p(310, 28).dy);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // bars (penjualan)
    final barPaint = Paint()..color = AppColors.primary.withValues(alpha: 0.8);
    for (final bar in [(85.0, 85.0, 15.0), (165.0, 70.0, 30.0), (225.0, 55.0, 45.0), (305.0, 75.0, 25.0)]) {
      final rect = Rect.fromLTWH(p(bar.$1, 0).dx - 4, p(0, bar.$2).dy, 8, bar.$3 * h / 120);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), barPaint);
    }

    // points
    final dotFill = Paint()..color = Colors.white;
    final dotStroke = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final pt in [(10.0, 90.0), (60.0, 80.0), (115.0, 65.0), (170.0, 50.0), (275.0, 24.0), (310.0, 28.0)]) {
      final o = p(pt.$1, pt.$2);
      canvas.drawCircle(o, 3, dotFill);
      canvas.drawCircle(o, 3, dotStroke);
    }
    // peak point (highlighted)
    final peak = p(230, 20);
    canvas.drawCircle(peak, 4.5, Paint()..color = AppColors.accent);
    canvas.drawCircle(peak, 4.5, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({this.onTap, this.onFab});

  final ValueChanged<int>? onTap;
  final VoidCallback? onFab;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: AppColors.surface,
      height: AppSpacing.bottomNavHeight,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(child: _navItem(Icons.dashboard_outlined, 'Dashboard', active: true, onTap: () => onTap?.call(0))),
          Expanded(child: _navItem(Icons.palette_outlined, 'Karya', onTap: () => onTap?.call(1))),
          Expanded(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -18),
                child: FloatingActionButton(
                  onPressed: onFab,
                  backgroundColor: AppColors.accent,
                  elevation: 4,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ),
          ),
          Expanded(child: _navItem(Icons.receipt_long_outlined, 'Pesanan', onTap: () => onTap?.call(3))),
          Expanded(child: _navItem(Icons.storefront_outlined, 'Profil', onTap: () => onTap?.call(4))),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, {bool active = false, VoidCallback? onTap}) {
    final color = active ? AppColors.primary : AppColors.muted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.labelSm.copyWith(
                  color: color, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }
}
