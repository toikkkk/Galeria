import 'package:flutter/material.dart';

import '../models/karya.dart';
import '../services/api_client.dart';

/// Render gambar 1 [Karya] -- otomatis pilih sumber yang benar:
/// - [Karya.imageUrl] terisi (karya ter-upload sungguhan, lihat
///   `POST /api/karya`) -> [Image.network] dari backend (`kApiBaseUrl` +
///   path relatif).
/// - null (karya lama/[sampleKarya], asset dibundling) -> [Image.asset]
///   seperti sebelumnya.
///
/// Dipakai di semua tempat yang sebelumnya `Image.asset(karya.assetPath)`
/// langsung -- lihat karya_grid_card.dart & detail_karya_screen.dart.
class KaryaImage extends StatelessWidget {
  const KaryaImage(this.karya, {super.key, this.fit = BoxFit.cover});

  final Karya karya;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = karya.imageUrl;
    if (url == null) {
      return Image.asset(karya.assetPath, fit: fit);
    }
    return Image.network(
      '$kApiBaseUrl$url',
      fit: fit,
      // JANGAN fallback ke Image.asset(karya.assetPath) di sini -- utk
      // karya ter-upload sungguhan, assetPath dibangun dari nama file UUID
      // yang TIDAK pernah ada sbg asset dibundling, jadi fallback itu akan
      // gagal lagi (dobel error). Placeholder ikon netral lebih jujur.
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.black12,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}
