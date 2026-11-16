import '../../models/dashboard_seniman.dart';
import '../../models/langganan.dart';
import '../../models/sentimen_seniman.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/langganan_service.dart';
import '../../services/sentimen_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../utils/coming_soon.dart';
import '../../utils/format.dart';

/// Konversi dari
/// docs/design/role_seniman_1/.../galeria_profil_akun_seniman/code.html
///
/// Statistik (karya aktif, terjual, rating), pendapatan, dan badge PRO diambil dari backend
/// (`/api/dashboard/saya/...`, `/api/langganan/saya`). Bila gagal dimuat, angkanya tampil '-' (bukan angka contoh).
/// Fitur pengikut belum ada di backend, jadi kartu 'Pengikut' diganti 'Terjual'.
///
/// [onLihatProfilToko]/[onDataDiri] -- dua menu yang SUDAH punya layar
/// tujuan nyata di app (`/toko`, `/verifikasi-identitas`), jadi di-thread
/// lewat constructor supaya main.dart yang memutuskan rute (pola konsisten
/// dgn layar lain). Menu lain yang belum punya layar tujuan ditangani
/// langsung di file ini via [showComingSoon] -- lihat audit navigasi role
/// Seniman, 2026-10.
class ProfilScreen extends StatefulWidget {
  const ProfilScreen({
    super.key,
    this.onNavTap,
    this.onLogout,
    this.onLihatProfilToko,
    this.onDataDiri,
    this.dashboard,
    this.sentimen,
    this.langganan,
  });

  final ValueChanged<int>? onNavTap;
  final VoidCallback? onLogout;
  final VoidCallback? onLihatProfilToko;
  final VoidCallback? onDataDiri;

  /// Bisa diganti di tes; default memakai backend sungguhan.
  final DashboardService? dashboard;
  final SentimenService? sentimen;
  final LanggananService? langganan;

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  RingkasanSeniman? _ringkasan;
  SentimenSeniman? _sentimen;
  LanggananSaya? _langganan;

  ValueChanged<int>? get onNavTap => widget.onNavTap;
  VoidCallback? get onLogout => widget.onLogout;
  VoidCallback? get onLihatProfilToko => widget.onLihatProfilToko;
  VoidCallback? get onDataDiri => widget.onDataDiri;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  /// Tiga sumber dimuat terpisah: satu gagal tidak menghapus dua lainnya.
  Future<void> _muat() async {
    Future<T?> aman<T>(Future<T> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return null;
      }
    }

    final hasil = await Future.wait<Object?>([
      aman(() => (widget.dashboard ?? DashboardService()).fetchRingkasan(periode: 365)),
      aman(() => (widget.sentimen ?? SentimenService()).fetchSentimen()),
      aman(() => (widget.langganan ?? LanggananService()).saya()),
    ]);
    if (!mounted) return;
    setState(() {
      _ringkasan = hasil[0] as RingkasanSeniman?;
      _sentimen = hasil[1] as SentimenSeniman?;
      _langganan = hasil[2] as LanggananSaya?;
    });
  }

  String get _ratingTeks {
    final r = _sentimen?.ratingRata2;
    return r == null ? '-' : r.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.user;
    final pendapatan = _ringkasan?.pendapatanBersihIdr ?? 0;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: ListView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter, vertical: AppSpacing.md),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Profil', style: AppTextStyles.headlineLg),
              InkWell(
                onTap: () => showComingSoon(context, 'Pengaturan'),
                customBorder: const CircleBorder(),
                child: Container(
                  width: AppSpacing.touchTarget,
                  height: AppSpacing.touchTarget,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.settings_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Profile card
          _card(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          alignment: Alignment.center,
                          child: Text(user?.inisial ?? '?',
                              style: AppTextStyles.displayMd
                                  .copyWith(color: const Color(0xFFECC246), fontSize: 28)),
                        ),
                        if (user?.emailVerified ?? false)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: AppColors.accent),
                            child: const Icon(Icons.verified, size: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(user?.displayName ?? 'Seniman',
                                    style: AppTextStyles.headlineSm,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (user?.emailVerified ?? false) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.check_circle, size: 16, color: AppColors.accent),
                              ],
                            ],
                          ),
                          Text(user?.email ?? '',
                              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            key: const Key('verifikasi_email_tautan'),
                            // belum terverifikasi -> ketuk untuk membuka layar kode
                            onTap: (user?.emailVerified ?? false)
                                ? null
                                : () async {
                                    await context.push('/verifikasi-email');
                                    if (mounted) setState(() {});
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE08E).withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_user, size: 12, color: Color(0xFF584400)),
                                  const SizedBox(width: 4),
                                  Text((user?.emailVerified ?? false) ? 'Email Terverifikasi' : 'Email Belum Diverifikasi · Verifikasi ›',
                                      style: AppTextStyles.labelSm
                                          .copyWith(fontSize: 10.5, color: const Color(0xFF584400))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
                TextButton.icon(
                  onPressed: onLihatProfilToko ?? () => showComingSoon(context, 'Profil Toko'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Lihat Profil Toko'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onSurface,
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Stats row
          _card(
            child: Row(
              children: [
                Expanded(child: _statBlock('Karya Aktif', _ringkasan == null ? '-' : '${_ringkasan!.karyaTersedia}')),
                Container(width: 1, height: 36, color: AppColors.border),
                Expanded(child: _statBlock('Terjual', _ringkasan == null ? '-' : '${_ringkasan!.karyaTerjualTotal}')),
                Container(width: 1, height: 36, color: AppColors.border),
                Expanded(child: _statBlock('Rating', _ratingTeks, star: _sentimen?.ratingRata2 != null)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _group(context, 'TOKO', [
            _MenuItemData(Icons.storefront_outlined, 'Kelola Galeri', onTap: () => onNavTap?.call(1)),
            _MenuItemData(Icons.account_balance_wallet_outlined, 'Data Rekening & Dompet',
                trailingText: pendapatan > 0 ? formatRupiah(pendapatan) : null, trailingColor: AppColors.accent),
            _MenuItemData(Icons.inventory_2_outlined, 'Pengaturan Pengiriman & Packing'),
            _MenuItemData(Icons.workspace_premium_outlined, 'Langganan',
                badge: (_langganan?.pro ?? false) ? 'PRO' : null),
          ]),
          const SizedBox(height: AppSpacing.sm),
          _group(context, 'AKUN', [
            _MenuItemData(Icons.badge_outlined, 'Data Diri & KTP',
                onTap: onDataDiri),
            _MenuItemData(Icons.lock_outline, 'Ubah Password'),
            _MenuItemData(Icons.notifications_outlined, 'Notifikasi'),
            _MenuItemData(Icons.translate_outlined, 'Bahasa', trailingText: 'Indonesia'),
          ]),
          const SizedBox(height: AppSpacing.sm),
          _group(context, 'BANTUAN', [
            _MenuItemData(Icons.help_outline, 'Pusat Bantuan'),
            _MenuItemData(Icons.description_outlined, 'Syarat & Ketentuan'),
            _MenuItemData(Icons.policy_outlined, 'Kebijakan Privasi'),
          ]),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
            label: const Text('Keluar', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.errorContainer.withValues(alpha: 0.5),
              side: BorderSide.none,
              minimumSize: const Size(double.infinity, 46),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text('GALERIA v1.0.0',
                style: AppTextStyles.labelSm.copyWith(color: AppColors.outline)),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.surface,
        height: AppSpacing.bottomNavHeight,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Expanded(child: _navItem(Icons.dashboard_outlined, 'Dasbor', onTap: () => onNavTap?.call(0))),
            Expanded(child: _navItem(Icons.palette_outlined, 'Karya', onTap: () => onNavTap?.call(1))),
            Expanded(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -18),
                  child: FloatingActionButton(
                    onPressed: () => onNavTap?.call(2),
                    backgroundColor: const Color(0xFFFED255),
                    foregroundColor: AppColors.primary,
                    elevation: 4,
                    child: const Icon(Icons.add),
                  ),
                ),
              ),
            ),
            Expanded(child: _navItem(Icons.receipt_long_outlined, 'Pesanan', onTap: () => onNavTap?.call(3))),
            Expanded(child: _navItem(Icons.person, 'Profil', active: true, onTap: () => onNavTap?.call(4))),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.cardInner),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: child,
      );

  Widget _statBlock(String label, String value, {bool star = false}) => Column(
        children: [
          Text(label, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: AppTextStyles.labelMd.copyWith(fontSize: 16)),
              if (star) ...[
                const SizedBox(width: 2),
                const Icon(Icons.star, size: 14, color: AppColors.accent),
              ],
            ],
          ),
        ],
      );

  Widget _group(BuildContext context, String title, List<_MenuItemData> items) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.cardInner, AppSpacing.sm, AppSpacing.cardInner, 4),
              child: Text(title,
                  style: AppTextStyles.overline.copyWith(color: AppColors.accent)),
            ),
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 1,
                    indent: AppSpacing.cardInner,
                    endIndent: AppSpacing.cardInner),
              _menuTile(context, items[i]),
            ],
          ],
        ),
      );

  Widget _menuTile(BuildContext context, _MenuItemData d) => InkWell(
        onTap: d.onTap ?? () => showComingSoon(context, d.label),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardInner, vertical: AppSpacing.sm),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.surfaceContainer,
                child: Icon(d.icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(d.label,
                    style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
              if (d.trailingText != null)
                Text(d.trailingText!,
                    style: AppTextStyles.bodySm.copyWith(
                        color: d.trailingColor ?? AppColors.muted,
                        fontWeight: FontWeight.w600)),
              if (d.badge != null)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(d.badge!,
                      style: AppTextStyles.labelSm.copyWith(
                          fontSize: 10, color: AppColors.accent)),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
            ],
          ),
        ),
      );

  Widget _navItem(IconData icon, String label, {bool active = false, VoidCallback? onTap}) {
    final color = active ? AppColors.accent : AppColors.muted;
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

class _MenuItemData {
  _MenuItemData(this.icon, this.label,
      {this.trailingText, this.trailingColor, this.badge, this.onTap});

  final IconData icon;
  final String label;
  final String? trailingText;
  final Color? trailingColor;
  final String? badge;

  /// Null = belum ada layar tujuan -- [_menuTile] fallback ke
  /// [showComingSoon].
  final VoidCallback? onTap;
}
