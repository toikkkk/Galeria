import 'package:flutter/material.dart';

import '../models/karya.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Gambar karya: dari URL (Cloudflare R2) kalau [Karya.imageUrl] ada, selain
/// itu dari asset lokal [Karya.assetPath]. Gagal muat (mis. `r2.dev` terblokir
/// DNS, atau asset tidak ada) -> ikon gambar-rusak, tidak crash.
class KaryaImage extends StatelessWidget {
  const KaryaImage({super.key, required this.karya, this.fit = BoxFit.cover});

  final Karya karya;
  final BoxFit fit;

  /// Lebar decode gambar sesuai ukuran tampil x kepadatan layar. Tanpa ini gambar katalog beresolusi besar
  /// didecode penuh untuk thumbnail kecil -> memori boros dan scroll patah-patah. Dibatasi 64..1400 px.
  static int? _lebarCache(BuildContext context, BoxConstraints c) {
    if (!c.hasBoundedWidth || c.maxWidth.isInfinite) return null;
    final px = (c.maxWidth * MediaQuery.devicePixelRatioOf(context)).round();
    return px.clamp(64, 1400);
  }

  /// Minta versi kecil dari backend (`?w=`) untuk gambar yang dilayani backend kita (`/api/gambar/`, `/api/media/`).
  /// Gambar asli ~300-700 KB; di kartu cukup 30-70 KB, jadi muat jauh lebih cepat. Lebar dibulatkan ke nilai
  /// yang diizinkan server (240/360/480/720/1080). URL lain (mis. langsung `r2.dev`) dibiarkan.
  static String _versiKecil(String url, int? lebarPx) {
    if (!url.contains('/api/gambar/') && !url.contains('/api/media/')) return url;
    final uri = Uri.parse(url);
    if (uri.queryParameters.containsKey('w')) return url;
    final w = lebarPx == null ? 720 : (lebarPx <= 240 ? 240 : lebarPx <= 360 ? 360 : lebarPx <= 480 ? 480 : lebarPx <= 720 ? 720 : 1080);
    return uri.replace(queryParameters: {...uri.queryParameters, 'w': '$w'}).toString();
  }

  @override
  Widget build(BuildContext context) {
    final url = karya.imageUrl;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cacheWidth = _lebarCache(context, constraints);
        if (url == null) {
          return Image.asset(karya.assetPath, fit: fit, cacheWidth: cacheWidth, errorBuilder: _error);
        }
        // Karya ter-upload lewat backend: image_url relatif (`/uploads/...`),
        // diprefix kApiBaseUrl. Karya R2: sudah URL absolut.
        final resolved = _versiKecil(url.startsWith('http') ? url : '$kApiBaseUrl$url', cacheWidth);
        return Image.network(
          resolved,
          fit: fit,
          headers: headerTunnel(resolved),
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const ColoredBox(
              color: AppColors.accentSoft,
              child: Center(
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            );
          },
          errorBuilder: _error,
        );
      },
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
