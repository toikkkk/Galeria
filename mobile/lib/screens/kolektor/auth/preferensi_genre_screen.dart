import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../theme/app_theme.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR UTAMA/.../galeria_preferensi_genre_seni/code.html
/// (Langkah 2 dari 2)
///
/// Pilihan genre di sini memakai 8 kelas gaya (style) WikiArt yang sama
/// dengan yang dipelajari model Visual Search (lihat ml-visual-search/),
/// bukan daftar genre bebas dari mockup asli -- supaya konsisten dengan
/// taksonomi nyata proyek, bukan istilah karangan.
///
/// TODO(backend): kirim preferensi terpilih ke endpoint profil kolektor
/// begitu tersedia -- saat ini hanya disimpan di state lokal layar ini.
class PreferensiGenreScreen extends StatefulWidget {
  const PreferensiGenreScreen({
    super.key,
    required this.onBack,
    required this.onContinue,
    required this.onSkip,
  });

  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  State<PreferensiGenreScreen> createState() => _PreferensiGenreScreenState();
}

class _PreferensiGenreScreenState extends State<PreferensiGenreScreen> {
  // Default 3 pertama terpilih supaya tombol lanjut langsung aktif (match
  // pola docs: "3 terpilih" saat layar pertama kali dibuka).
  final Set<int> _selected = {0, 1, 2};

  @override
  Widget build(BuildContext context) {
    final met = _selected.length >= 3;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          'GALERIA',
          style: AppTextStyles.headlineSm.copyWith(letterSpacing: 2),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: widget.onSkip,
            child: Text(
              'Lewati',
              style: AppTextStyles.labelMd.copyWith(color: AppColors.muted),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenGutter,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          'LANGKAH 2',
                          style: AppTextStyles.overline.copyWith(fontSize: 9),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: met
                              ? AppColors.accentSoft.withValues(alpha: 0.6)
                              : AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              met ? Icons.check_circle : Icons.info_outline,
                              size: 12,
                              color: met ? AppColors.accent : AppColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              met
                                  ? '${_selected.length} terpilih (Memenuhi syarat)'
                                  : '${_selected.length} terpilih (Pilih ${3 - _selected.length} lagi)',
                              style: AppTextStyles.labelSm.copyWith(
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Genre apa yang kamu suka?',
                    style: AppTextStyles.headlineLg,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pilih minimal 3 genre untuk mempersonalisasi rekomendasi lelang dan kurasi karya seni Anda.',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sampleKarya.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSpacing.xs,
                          mainAxisSpacing: AppSpacing.xs,
                          childAspectRatio: 4 / 5,
                        ),
                    itemBuilder: (context, i) {
                      final selected = _selected.contains(i);
                      return _GenreTile(
                        assetPath: sampleKarya[i].assetPath,
                        label: sampleKarya[i].styleName,
                        selected: selected,
                        onTap: () => setState(() {
                          if (selected) {
                            _selected.remove(i);
                          } else {
                            _selected.add(i);
                          }
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Pilihan Anda melatih rekomendasi kurator pintar GALERIA',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.sm,
              AppSpacing.screenGutter,
              AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: ElevatedButton(
              onPressed: met ? widget.onContinue : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Lanjut ke Beranda'),
                  SizedBox(width: AppSpacing.xs),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenreTile extends StatelessWidget {
  const _GenreTile({
    required this.assetPath,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String assetPath;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Image.asset(assetPath, fit: BoxFit.cover),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: selected ? 0.75 : 0.55),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
          if (selected)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.accent, width: 2),
                ),
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? AppColors.accent
                    : Colors.white.withValues(alpha: 0.6),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Text(
              label,
              style: AppTextStyles.headlineSm.copyWith(
                color: Colors.white,
                fontStyle: FontStyle.italic,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
