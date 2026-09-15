import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_1/.../galeria_profil_akun_seniman/code.html
///
/// Data (nama toko, statistik, saldo) masih placeholder -- sama dengan
/// DashboardScreen, sambungkan ke backend nanti (lihat TODO di sana).
class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key, this.onNavTap, this.onLogout});

  final ValueChanged<int>? onNavTap;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Profil', style: AppTextStyles.headlineMd),
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
      body: ListView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter, vertical: AppSpacing.md),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Profil', style: AppTextStyles.headlineLg),
              Container(
                width: AppSpacing.touchTarget,
                height: AppSpacing.touchTarget,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: const Icon(Icons.settings_outlined),
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
                          child: Text('SR',
                              style: AppTextStyles.displayMd
                                  .copyWith(color: const Color(0xFFECC246), fontSize: 28)),
                        ),
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
                                child: Text('Sanggar Rupa Nusantara',
                                    style: AppTextStyles.headlineSm,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.check_circle, size: 16, color: AppColors.accent),
                            ],
                          ),
                          Text('Kurator Terakreditasi · Salon Utama',
                              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                          const SizedBox(height: 6),
                          Container(
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
                                Text('Identitas Terverifikasi',
                                    style: AppTextStyles.labelSm
                                        .copyWith(fontSize: 10.5, color: const Color(0xFF584400))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
                TextButton.icon(
                  onPressed: () {},
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
                Expanded(child: _statBlock('Karya Aktif', '12')),
                Container(width: 1, height: 36, color: AppColors.border),
                Expanded(child: _statBlock('Pengikut', '1.240')),
                Container(width: 1, height: 36, color: AppColors.border),
                Expanded(child: _statBlock('Rating', '4.9', star: true)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _group('TOKO', [
            _MenuItemData(Icons.storefront_outlined, 'Kelola Galeri'),
            _MenuItemData(Icons.account_balance_wallet_outlined, 'Data Rekening & Dompet',
                trailingText: 'Rp 184.750.000', trailingColor: AppColors.accent),
            _MenuItemData(Icons.inventory_2_outlined, 'Pengaturan Pengiriman & Packing'),
            _MenuItemData(Icons.workspace_premium_outlined, 'Langganan', badge: 'PRO'),
          ]),
          const SizedBox(height: AppSpacing.sm),
          _group('AKUN', [
            _MenuItemData(Icons.badge_outlined, 'Data Diri & KTP', badge: 'Terverifikasi', badgeColor: AppColors.success),
            _MenuItemData(Icons.lock_outline, 'Ubah Password'),
            _MenuItemData(Icons.notifications_outlined, 'Notifikasi'),
            _MenuItemData(Icons.translate_outlined, 'Bahasa', trailingText: 'Indonesia'),
          ]),
          const SizedBox(height: AppSpacing.sm),
          _group('BANTUAN', [
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

  Widget _group(String title, List<_MenuItemData> items) => Container(
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
              _menuTile(items[i]),
            ],
          ],
        ),
      );

  Widget _menuTile(_MenuItemData d) => InkWell(
        onTap: () {},
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
                    color: (d.badgeColor ?? AppColors.accent).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(d.badge!,
                      style: AppTextStyles.labelSm.copyWith(
                          fontSize: 10, color: d.badgeColor ?? AppColors.accent)),
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
      {this.trailingText, this.trailingColor, this.badge, this.badgeColor});

  final IconData icon;
  final String label;
  final String? trailingText;
  final Color? trailingColor;
  final String? badge;
  final Color? badgeColor;
}
