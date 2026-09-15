import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum UserRole { kolektor, seniman }

/// Konversi dari
/// docs/design/role_seniman_1/.../galeria_layar_pilih_peran_role_selection/code.html
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({
    super.key,
    required this.onBack,
    required this.onContinue,
  });

  final VoidCallback onBack;
  final ValueChanged<UserRole> onContinue;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole _selected = UserRole.kolektor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter, vertical: AppSpacing.md),
          child: Column(
            children: [
              // Top bar: back + stepper + step badge
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _stepDot(active: true),
                      const SizedBox(width: 4),
                      _stepDot(active: false),
                      const SizedBox(width: 4),
                      _stepDot(active: false),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                            radius: 3, backgroundColor: AppColors.accent),
                        const SizedBox(width: 6),
                        Text('LANGKAH 1/3', style: AppTextStyles.labelSm),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Header
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daftar sebagai', style: AppTextStyles.displayMd),
                    const SizedBox(height: 4),
                    Text('Kamu bisa mengubah ini nanti',
                        style: AppTextStyles.bodyMd
                            .copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Cards
              _RoleCard(
                selected: _selected == UserRole.kolektor,
                icon: Icons.center_focus_strong_outlined,
                title: 'Kolektor',
                badge: 'Populer',
                description: 'Jelajahi, beli, dan ikut lelang karya seni asli.',
                features: const [
                  'Sertifikat Keaslian Digital',
                  'Akses Ruang Lelang VIP',
                ],
                onTap: () => setState(() => _selected = UserRole.kolektor),
              ),
              const SizedBox(height: AppSpacing.md),
              _RoleCard(
                selected: _selected == UserRole.seniman,
                icon: Icons.palette_outlined,
                title: 'Seniman',
                badge: 'Kreator',
                description: 'Buka galeri, jual karya, dan buat lelang sendiri.',
                features: const [
                  'Kurasi Karya Instan',
                  'Royalti & Pembayaran Otomatis',
                ],
                onTap: () => setState(() => _selected = UserRole.seniman),
              ),
              const Spacer(),
              // Trust footnote
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Akun dapat dialihkan ke mode lain kapan saja dari profil',
                      textAlign: TextAlign.center,
                      style:
                          AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => widget.onContinue(_selected),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('Lanjut'),
                    SizedBox(width: AppSpacing.xs),
                    Icon(Icons.arrow_forward, size: 16, color: AppColors.accent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepDot({required bool active}) => Container(
        width: active ? 28 : 8,
        height: 4,
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.border,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.badge,
    required this.description,
    required this.features,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String badge;
  final String description;
  final List<String> features;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: selected ? 30 : 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accentSoft
                        : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? AppColors.accent.withValues(alpha: 0.25)
                          : AppColors.border,
                    ),
                  ),
                  child: Icon(icon,
                      size: 32,
                      color: selected ? AppColors.accent : AppColors.onSurface),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: AppTextStyles.headlineMd),
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.accent.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              badge.toUpperCase(),
                              style: AppTextStyles.overline.copyWith(
                                fontSize: 10,
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(description,
                          style: AppTextStyles.bodySm
                              .copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? AppColors.accent : AppColors.border,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 4,
              children: [
                for (final f in features)
                  Text('• $f',
                      style: AppTextStyles.bodySm.copyWith(
                        fontSize: 11.5,
                        color: AppColors.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
