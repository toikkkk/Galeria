import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/karya.dart';
import '../../theme/app_theme.dart';

/// Kartu karya 2-kolom yang dipakai berulang (Beranda, Koleksi Saya, Profil
/// Toko, Karya Serupa) -- disatukan di sini alih-alih ditulis ulang per
/// layar, karena strukturnya identik di banyak layar Kolektor.
class KaryaGridCard extends StatelessWidget {
  const KaryaGridCard({
    super.key,
    required this.karya,
    this.overline,
    this.priceLabel = 'Harga Koleksi',
    this.verified = true,
    this.onTap,
  });

  final Karya karya;

  /// Mis. "Lelang Langsung", "Beli Langsung".
  final String? overline;
  final String priceLabel;
  final bool verified;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        clipBehavior: Clip.antiAlias,
        // Gambar diberi `Expanded` (bukan AspectRatio 4:5 tetap) supaya kartu
        // selalu pas dengan tinggi berapa pun yang diberikan grid/list
        // pembungkusnya -- blok teks di bawah (judul, seniman, harga) punya
        // tinggi tetap sesuai isinya, sisa ruang dipakai gambar. Ini
        // mencegah "bottom overflow" yang muncul kalau AspectRatio dipaksa
        // sementara sel grid tidak cukup tinggi utk menampung teksnya.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(karya.assetPath, fit: BoxFit.cover),
                  if (verified)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _pillBadge(
                        icon: Icons.verified,
                        label: 'Terverifikasi',
                      ),
                    ),
                  if (karya.isPromoted)
                    Positioned(
                      top: verified ? 32 : 8,
                      left: 8,
                      child: _pillBadge(
                        icon: Icons.trending_up,
                        label: 'Dipromosikan',
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _ShareButton(karya: karya),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (overline != null) ...[
                    Text(
                      overline!.toUpperCase(),
                      style: AppTextStyles.overline.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    karya.title,
                    style: AppTextStyles.headlineSm.copyWith(
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    karya.artistName,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    priceLabel.toUpperCase(),
                    style: AppTextStyles.overline.copyWith(fontSize: 8.5),
                  ),
                  Text(
                    karya.priceFormatted,
                    style: AppTextStyles.labelMd.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillBadge({required IconData icon, required String label}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: AppColors.accent),
            const SizedBox(width: 3),
            Text(
              label,
              style: AppTextStyles.overline.copyWith(
                fontSize: 8,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      );
}

/// Tombol bagikan (pojok kanan atas kartu) -- membuka share sheet native
/// OS (ACTION_SEND di Android) berisi link demo ke karya. Ditaruh sebagai
/// widget terpisah (bukan inline) supaya `InkWell` di sini tidak
/// mengaktifkan `onTap` kartu induk (buka detail karya) saat ditekan.
class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.karya});

  final Karya karya;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => SharePlus.instance.share(
          ShareParams(
            text:
                'Lihat "${karya.title}" oleh ${karya.artistName} di GALERIA: ${karya.shareUrl}',
            subject: karya.title,
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(5),
          child: Icon(Icons.ios_share, size: 14, color: AppColors.onSurface),
        ),
      ),
    );
  }
}

/// Badge kecil "Sertifikat digital keaslian" -- istilah wajib per CLAUDE.md,
/// JANGAN pernah diganti jadi "Hak Paten".
class SertifikatDigitalBadge extends StatelessWidget {
  const SertifikatDigitalBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : AppSpacing.xs,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user,
            size: compact ? 11 : 13,
            color: AppColors.accent,
          ),
          const SizedBox(width: 4),
          Text(
            'Sertifikat Digital Keaslian',
            style: AppTextStyles.overline.copyWith(
              fontSize: compact ? 8 : 9,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
