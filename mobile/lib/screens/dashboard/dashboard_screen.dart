import 'package:flutter/material.dart';

import '../../config/demo_seniman.dart';
import '../../models/dashboard_seniman.dart';
import '../../services/dashboard_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/galeria_logo.dart';
import '../../utils/format.dart';
import '../../widgets/dashboard/dashboard_sections.dart';
import '../../widgets/dashboard/sales_chart_card.dart';
import '../../widgets/dashboard/sentimen_card.dart';
import '../../utils/coming_soon.dart';

/// Konversi dari
/// docs/design/role_seniman_1/.../galeria_dashboard_seniman_galeri/code.html
///
/// Angka penjualan/omzet/aliran/segmen/tren pasar diambil dari backend
/// (`GET /api/dashboard/...`) -- DATA SINTETIS (schema `dummy_rekomendasi`),
/// dilabeli "Data contoh". Tombol Tarik Dana masih placeholder.
/// Dashboard hanya statistik deskriptif, bukan prediksi/saran harga.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.onUploadKarya,
    this.onNavTap,
    this.onKomunitasTap,
    this.onAdakanEvent,
    this.onPromosikanKarya,
    this.onNotifikasiTap,
    this.onBuatLelang,
    this.onRiwayatTap,
    this.service,
  });

  final VoidCallback? onUploadKarya;
  final ValueChanged<int>? onNavTap;
  final VoidCallback? onKomunitasTap;
  final VoidCallback? onAdakanEvent;
  final VoidCallback? onPromosikanKarya;
  final VoidCallback? onNotifikasiTap;
  final VoidCallback? onBuatLelang;
  final VoidCallback? onRiwayatTap;

  /// Untuk testing; default membuat [DashboardService] sendiri.
  final DashboardService? service;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardData {
  const _DashboardData({
    required this.senimanId,
    required this.ringkasan,
    required this.bulanan,
    required this.aliran,
    required this.segmen,
    required this.tren,
  });

  final String senimanId;
  final RingkasanSeniman ringkasan;
  final List<PenjualanBulan> bulanan;
  final List<AliranSeniman> aliran;
  final SegmenPembeliHasil segmen;
  final TrenPasar tren;

  _DashboardData copyWithRingkasan(RingkasanSeniman r) => _DashboardData(
    senimanId: senimanId,
    ringkasan: r,
    bulanan: bulanan,
    aliran: aliran,
    segmen: segmen,
    tren: tren,
  );
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardService _service = widget.service ?? DashboardService();

  bool _balanceHidden = false;
  int _periode = 30;

  bool _loading = true;
  bool _ringkasanLoading = false;
  String? _error;
  _DashboardData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = await resolveDemoSenimanId(_service);
      final results = await Future.wait([
        _service.fetchRingkasan(id, periode: _periode),
        _service.fetchPenjualanBulanan(id),
        _service.fetchAliran(id),
        _service.fetchSegmenPembeli(id),
        _service.fetchTrenPasar(),
      ]);
      if (!mounted) return;
      setState(() {
        _data = _DashboardData(
          senimanId: id,
          ringkasan: results[0] as RingkasanSeniman,
          bulanan: results[1] as List<PenjualanBulan>,
          aliran: results[2] as List<AliranSeniman>,
          segmen: results[3] as SegmenPembeliHasil,
          tren: results[4] as TrenPasar,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _gantiPeriode(int p) async {
    final data = _data;
    if (data == null || p == _periode) return;
    setState(() {
      _periode = p;
      _ringkasanLoading = true;
    });
    try {
      final r = await _service.fetchRingkasan(data.senimanId, periode: p);
      if (!mounted) return;
      setState(() {
        _data = data.copyWithRingkasan(r);
        _ringkasanLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _ringkasanLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(
              child: GaleriaLogo(
                size: 32,
                withWordmark: true,
                textStyle: AppTextStyles.headlineMd,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                'STUDIO',
                style: AppTextStyles.overline.copyWith(color: AppColors.accent),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: widget.onNotifikasiTap,
            icon: const Icon(Icons.notifications_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: InkWell(
              onTap: () => widget.onNavTap?.call(4),
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.person, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _BottomNav(
        onTap: widget.onNavTap,
        onFab: widget.onUploadKarya,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _DashboardSkeleton();
    final data = _data;
    if (data == null) {
      return _ErrorView(
        message: _error ?? 'Data tidak tersedia.',
        onRetry: _load,
      );
    }
    return _buildContent(data);
  }

  Widget _buildContent(_DashboardData data) {
    final r = data.ringkasan;
    final perubahan = r.perubahanOmzetPct;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ErrorBanner(
                message: _error!,
                onRetry: () {
                  setState(() => _error = null);
                  _gantiPeriode(_periode);
                },
              ),
            ),
          Center(
            child: PeriodSelector(value: _periode, onChanged: _gantiPeriode),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Balance card
          Opacity(
            opacity: _ringkasanLoading ? 0.5 : 1,
            child: Container(
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
                    children: [
                      Flexible(
                        child: Text(
                          'PENDAPATAN BERSIH · ${r.periodeHari} HARI',
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.overline.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          _balanceHidden
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 16,
                          color: Colors.white60,
                        ),
                        onPressed: () =>
                            setState(() => _balanceHidden = !_balanceHidden),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _balanceHidden
                        ? 'Rp ••••••••••'
                        : formatRupiah(r.pendapatanBersihIdr),
                    style: AppTextStyles.displayMd.copyWith(
                      color: Colors.white,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        (perubahan ?? 0) < 0
                            ? Icons.trending_down
                            : Icons.trending_up,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          perubahan == null
                              ? 'Belum ada periode pembanding'
                              : '${formatPersen(perubahan)} omzet vs ${r.periodeHari} hari sebelumnya',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Tarik Dana: placeholder (belum ada payout nyata). Riwayat -> riwayat tarik dana.
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => showComingSoon(context, 'Tarik Dana'),
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
                          onPressed: widget.onRiwayatTap,
                          icon: const Icon(
                            Icons.schedule,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Riwayat',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Stat cards
          Opacity(
            opacity: _ringkasanLoading ? 0.5 : 1,
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'KARYA AKTIF',
                    icon: Icons.palette_outlined,
                    value: '${r.karyaTersedia}',
                    unit: 'karya',
                    footer: 'Koleksi Terpasang',
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _StatCard(
                    label: 'TERJUAL',
                    icon: Icons.check_circle_outline,
                    iconColor: AppColors.accent,
                    value: '${r.nTerjual}',
                    unit: 'karya',
                    unitColor: AppColors.accent,
                    footer: 'Dalam ${r.periodeHari} Hari',
                    footerColor: AppColors.accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _StatCard(
                    label: 'PEMBELI',
                    icon: Icons.people_outline,
                    iconColor: AppColors.accent,
                    value: '${r.nPembeliUnik}',
                    unit: 'orang',
                    unitColor: AppColors.accent,
                    footer: 'Pembeli Unik',
                    footerColor: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SizedBox(height: AppSpacing.md),
          // Aksi cepat: satu baris yang bisa digeser (hemat tinggi layar)
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                _QuickAction(
                  icon: Icons.brush_outlined,
                  label: 'Unggah Karya',
                  onTap: widget.onUploadKarya,
                ),
                _QuickAction(
                  icon: Icons.gavel_outlined,
                  label: 'Buat Lelang',
                  onTap: widget.onBuatLelang,
                ),
                _QuickAction(
                  icon: Icons.campaign_outlined,
                  label: 'Promosikan',
                  pro: true,
                  onTap: widget.onPromosikanKarya,
                ),
                _QuickAction(
                  icon: Icons.groups_outlined,
                  label: 'Komunitas',
                  onTap: widget.onKomunitasTap,
                ),
                _QuickAction(
                  icon: Icons.event_note_outlined,
                  label: 'Buat Event',
                  pro: true,
                  onTap: widget.onAdakanEvent,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SalesChartCard(bulanan: data.bulanan),
          const SizedBox(height: AppSpacing.md),
          AnalitikCard(
            aliran: data.aliran,
            segmen: data.segmen,
            tren: data.tren,
          ),
          const SizedBox(height: AppSpacing.md),
          SentimenCard(senimanId: data.senimanId),
          const SizedBox(height: AppSpacing.md),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Dashboard tidak dapat dimuat',
              style: AppTextStyles.headlineSm,
            ),
            const SizedBox(height: 4),
            Text(
              'Periksa koneksi ke backend, lalu coba lagi.\n$message',
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Gagal memperbarui periode: $message',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.error),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  Widget _box(double h) => Container(
    height: h,
    decoration: BoxDecoration(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          _box(48),
          const SizedBox(height: AppSpacing.md),
          _box(150),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _box(96)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: _box(96)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: _box(96)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _box(180),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.unit,
    required this.footer,
    this.iconColor = AppColors.muted,
    this.unitColor = AppColors.muted,
    this.footerColor = AppColors.muted,
  });

  final String label, value, unit, footer;
  final IconData icon;
  final Color iconColor, unitColor, footerColor;

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
                child: Text(
                  label,
                  style: AppTextStyles.overline.copyWith(fontSize: 9),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: AppTextStyles.headlineLg),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: AppTextStyles.bodySm.copyWith(color: unitColor),
                ),
              ],
            ),
          ),
          Text(
            footer,
            style: AppTextStyles.overline.copyWith(
              fontSize: 8.5,
              color: footerColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    this.pro = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool pro;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: SizedBox(
        width: 88,
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4),
              ],
            ),
            child: Stack(
              children: [
                if (pro)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                      Text(
                        label,
                        style: AppTextStyles.labelSm.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
          Expanded(
            child: _navItem(
              Icons.dashboard_outlined,
              'Dashboard',
              active: true,
              onTap: () => onTap?.call(0),
            ),
          ),
          Expanded(
            child: _navItem(
              Icons.palette_outlined,
              'Karya',
              onTap: () => onTap?.call(1),
            ),
          ),
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
          Expanded(
            child: _navItem(
              Icons.receipt_long_outlined,
              'Pesanan',
              onTap: () => onTap?.call(3),
            ),
          ),
          Expanded(
            child: _navItem(
              Icons.storefront_outlined,
              'Profil',
              onTap: () => onTap?.call(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label, {
    bool active = false,
    VoidCallback? onTap,
  }) {
    final color = active ? AppColors.primary : AppColors.muted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSm.copyWith(
              color: color,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
