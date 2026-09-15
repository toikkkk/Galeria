import 'package:flutter/material.dart';

import '../../models/karya.dart';
import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_1/.../galeria_detail_komunitas_perupa_realis_nusantara/code.html
///
/// Isi feed (postingan, jumlah anggota, dll) semuanya CONTOH -- belum ada
/// fitur komunitas nyata di backend (fitur "PRO", lihat CLAUDE.md).
class CommunityDetailScreen extends StatelessWidget {
  const CommunityDetailScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: false,
                backgroundColor: AppColors.surface,
                expandedHeight: 224,
                leading: const SizedBox.shrink(),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(sampleKarya[2].assetPath, fit: BoxFit.cover),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.5),
                              Colors.transparent,
                              AppColors.primary.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _roundIconBtn(Icons.arrow_back, onBack),
                            Row(
                              children: [
                                _roundIconBtn(Icons.share, () {}),
                                const SizedBox(width: 8),
                                _roundIconBtn(Icons.more_horiz, () {}),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 4),
                    Transform.translate(
                      offset: const Offset(0, -44),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.accent, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('PRN',
                                      style: AppTextStyles.headlineSm
                                          .copyWith(color: AppColors.accent, letterSpacing: 2)),
                                  Text('EST. 2025',
                                      style: AppTextStyles.overline
                                          .copyWith(color: Colors.white54, fontSize: 8)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Flexible(
                                child: Text('Perupa Realis Nusantara',
                                    style: AppTextStyles.headlineMd,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, size: 18, color: AppColors.accent),
                            ],
                          ),
                          Text('Aliran Realis · Nasional · Dibuat Mar 2025',
                              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Wadah kolektif pelukis realis se-Nusantara untuk berbagi studi teknik kuas, palet warna, riset pigmen, dan kurasi pameran bersama.',
                            style: AppTextStyles.bodyMd,
                          ),
                        ],
                      ),
                    ),
                    // Stats
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _statBlock('1.842', 'Anggota')),
                          Container(width: 1, height: 28, color: AppColors.border),
                          Expanded(child: _statBlock('24', 'Diskusi Minggu Ini')),
                          Container(width: 1, height: 28, color: AppColors.border),
                          Expanded(child: _statBlock('8', 'Event')),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.check, size: 16, color: AppColors.accent),
                            label: const Text('Diikuti'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.surfaceContainerHigh,
                              side: BorderSide.none,
                              minimumSize: const Size(0, 40),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.person_add_outlined, size: 16),
                            label: const Text('Undang'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              minimumSize: const Size(0, 40),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          child: const Icon(Icons.notifications_none, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Tabs
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _tab('Diskusi', active: true)),
                          Expanded(child: _tab('Karya')),
                          Expanded(child: _tab('Event')),
                          Expanded(child: _tab('Anggota')),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Composer
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary,
                            child: Text('SR',
                                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Text('Bagikan proses atau karyamu...',
                                  style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                            ),
                          ),
                          IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.photo_library_outlined,
                                  size: 18, color: AppColors.accent)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Pinned post
                    _PostCard(
                      pinned: true,
                      initials: 'AL',
                      name: 'Ayu Larasati',
                      meta: 'Sanggar Cakrawala · Kemarin',
                      body:
                          'Panggilan Terbuka Pameran Bersama "Gema Realisme Nusantara 2026". Kurasi karya terbuka untuk seluruh anggota aktif komunitas hingga 30 April. Formulir pendaftaran resmi telah disematkan di tab Event.',
                      likes: 89,
                      comments: 21,
                      liked: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PostCard(
                      initials: 'BS',
                      name: 'Bimo Setiawan',
                      meta: 'Studio Bentang Alam · 5 jam lalu',
                      body:
                          'Kajian lanskap senja perahu nelayan di pesisir Benoa, Bali (cat minyak 100x70 cm). Mohon masukan rekan-rekan untuk rendering pantulan cahaya keemasan di permukaan air sebelum vernis akhir.',
                      imageAsset: sampleKarya[2].assetPath,
                      likes: 126,
                      comments: 34,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PostCard(
                      initials: 'AL',
                      name: 'Ayu Larasati',
                      meta: 'Sanggar Cakrawala · 2 jam lalu',
                      body:
                          'Sedang mengeksplorasi teknik underpainting grisaille menggunakan raw umber sebelum layering cat minyak transparan. Kuncinya ada pada kontrol medium pengering agar pigmen tidak retak saat glazes tebal diaplikasikan.',
                      likes: 48,
                      comments: 12,
                    ),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: FloatingActionButton(
              onPressed: () {},
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.edit_note, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundIconBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );

  Widget _statBlock(String value, String label) => Column(
        children: [
          Text(value, style: AppTextStyles.labelMd.copyWith(fontSize: 16)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              style: AppTextStyles.overline.copyWith(fontSize: 9)),
        ],
      );

  Widget _tab(String label, {bool active = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: active
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.accent, width: 2)))
            : null,
        child: Text(label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMd.copyWith(
                color: active ? AppColors.onSurface : AppColors.muted,
                fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      );
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.initials,
    required this.name,
    required this.meta,
    required this.body,
    required this.likes,
    required this.comments,
    this.imageAsset,
    this.pinned = false,
    this.liked = false,
  });

  final String initials, name, meta, body;
  final int likes, comments;
  final String? imageAsset;
  final bool pinned;
  final bool liked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pinned) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE08E).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.push_pin, size: 12, color: Color(0xFF584400)),
                      const SizedBox(width: 4),
                      Text('DISEMATKAN',
                          style: AppTextStyles.overline
                              .copyWith(fontSize: 9, color: const Color(0xFF584400))),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz, size: 18, color: AppColors.muted),
              ],
            ),
            const Divider(height: AppSpacing.sm),
          ],
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceContainerHigh,
                child: Text(initials,
                    style: AppTextStyles.labelMd.copyWith(color: AppColors.primary)),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: AppTextStyles.labelMd),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 14, color: AppColors.accent),
                      ],
                    ),
                    Text(meta,
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              if (!pinned) const Icon(Icons.more_horiz, size: 18, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: AppTextStyles.bodyMd),
          if (imageAsset != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.asset(imageAsset!, height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(liked ? Icons.favorite : Icons.favorite_border,
                  size: 18, color: liked ? AppColors.error : AppColors.muted),
              const SizedBox(width: 4),
              Text('$likes', style: AppTextStyles.labelSm.copyWith(color: AppColors.muted)),
              const SizedBox(width: AppSpacing.md),
              const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.muted),
              const SizedBox(width: 4),
              Text('$comments', style: AppTextStyles.labelSm.copyWith(color: AppColors.muted)),
              const Spacer(),
              const Icon(Icons.share_outlined, size: 18, color: AppColors.muted),
            ],
          ),
        ],
      ),
    );
  }
}
