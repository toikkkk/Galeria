import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Bottom nav bersama untuk seluruh layar utama Kolektor (Beranda, Lelang,
/// Pesanan, Profil) + FAB tengah "Pindai" ke Visual Search/AR -- konsisten
/// dengan pola `_BottomNav` di DashboardScreen (Seniman), disatukan di sini
/// karena dipakai berulang di banyak layar Kolektor.
class KolektorBottomNav extends StatelessWidget {
  const KolektorBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onPindai,
  });

  /// 0=Beranda, 1=Lelang, 2=Pesanan, 3=Profil.
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onPindai;

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
              Icons.storefront_outlined,
              'Beranda',
              active: currentIndex == 0,
              onTap: () => onTap(0),
            ),
          ),
          Expanded(
            child: _navItem(
              Icons.gavel_outlined,
              'Lelang',
              active: currentIndex == 1,
              onTap: () => onTap(1),
            ),
          ),
          Expanded(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -18),
                child: FloatingActionButton(
                  onPressed: onPindai,
                  backgroundColor: AppColors.accent,
                  elevation: 4,
                  child: const Icon(
                    Icons.view_in_ar_outlined,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _navItem(
              Icons.receipt_long_outlined,
              'Pesanan',
              active: currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ),
          Expanded(
            child: _navItem(
              Icons.person_outline,
              'Profil',
              active: currentIndex == 3,
              onTap: () => onTap(3),
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
