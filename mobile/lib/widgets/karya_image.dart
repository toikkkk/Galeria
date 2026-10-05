import 'package:flutter/material.dart';

import '../models/karya.dart';
import '../theme/app_theme.dart';

/// Gambar karya: dari URL (Cloudflare R2) kalau [Karya.imageUrl] ada, selain
/// itu dari asset lokal [Karya.assetPath]. Gagal muat (mis. `r2.dev` terblokir
/// DNS, atau asset tidak ada) -> ikon gambar-rusak, tidak crash.
class KaryaImage extends StatelessWidget {
  const KaryaImage({super.key, required this.karya, this.fit = BoxFit.cover});

  final Karya karya;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = karya.imageUrl;
    if (url == null) {
      return Image.asset(karya.assetPath, fit: fit, errorBuilder: _error);
    }
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(
          color: AppColors.accentSoft,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: _error,
    );
  }

  static Widget _error(BuildContext context, Object error, StackTrace? stack) =>
      const ColoredBox(
        color: AppColors.accentSoft,
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
        ),
      );
}
