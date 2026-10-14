import 'package:flutter/material.dart';

import '../../services/digital_art_identity_service.dart';
import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_2/.../galeria_karya_perlu_ditinjau/code.html
///
/// [result] (opsional) = hasil ASLI verifikasi. Layar ini bisa dipicu oleh
/// 2 sinyal BERBEDA (lihat DigitalArtIdentityService._decide_status):
/// (a) duplikat borderline (jarak embedding dekat ambang, belum "sangat
/// yakin"), ATAU (b) `ai_detection_result == 'ai_generated_terdeteksi'`
/// (yang TIDAK PERNAH auto-tolak, selalu ke sini). UI harus jelas membedakan
/// kedua kasus -- jangan selalu tampilkan "ditemukan kemiripan" kalau yang
/// sebenarnya terjadi cuma indikasi AI.
class KaryaPerluDitinjauScreen extends StatelessWidget {
  const KaryaPerluDitinjauScreen({
    super.key,
    required this.onClose,
    required this.onAjukanPeninjauan,
    required this.onKembali,
    this.result,
  });

  final VoidCallback onClose;
  final VoidCallback onAjukanPeninjauan;
  final VoidCallback onKembali;
  final VerificationResult? result;

  bool get _karenaDuplikat => result?.artToArtResult == 'duplikat_terdeteksi';
  bool get _karenaAi => result?.aiDetectionResult == 'ai_generated_terdeteksi';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('GALERIA', style: AppTextStyles.headlineSm.copyWith(fontSize: 16)),
            Text('STATUS VERIFIKASI', style: AppTextStyles.overline.copyWith(fontSize: 8)),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.person, size: 16, color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter, vertical: AppSpacing.md),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentSoft.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user, size: 13, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text('AUDIT PROVENANSI & KURASI',
                      style: AppTextStyles.overline.copyWith(fontSize: 9, color: AppColors.accent)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accentSoft),
              child: const Icon(Icons.published_with_changes, color: AppColors.accent, size: 28),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _karenaDuplikat ? 'Ditemukan Kemiripan Dengan Karya Lain' : 'Terindikasi Dibuat oleh AI',
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineLg.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            _karenaDuplikat
                ? 'Kami menemukan karya dengan kemiripan tinggi. Tim kurator akan meninjau dalam 1x24 jam.'
                : 'Sistem mendeteksi indikasi karya dibuat oleh AI generatif. Ini BUKAN tuduhan pasti -- '
                    'tim kurator akan meninjau manual dalam 1x24 jam sebelum ada keputusan apa pun.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardInner),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(_karenaDuplikat ? Icons.pattern : Icons.auto_awesome,
                            size: 18, color: AppColors.muted),
                        const SizedBox(width: 6),
                        Text(_karenaDuplikat ? 'Jarak Embedding Art-to-Art' : 'Probabilitas Art-to-AI',
                            style: AppTextStyles.labelMd),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.accentSoft, borderRadius: BorderRadius.circular(AppRadius.full)),
                      child: Text('Perlu Klarifikasi',
                          style: AppTextStyles.labelSm.copyWith(color: AppColors.accent, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_karenaDuplikat ? 'Jarak ke karya terdekat' : 'Probabilitas AI-generated',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                    Text(
                      _karenaDuplikat
                          ? (result?.duplicateMatches.isNotEmpty == true
                              ? result!.duplicateMatches.first.distance.toStringAsFixed(3)
                              : '--')
                          : '${((result?.aiGeneratedProbability ?? 0) * 100).toStringAsFixed(1)}%',
                      style: AppTextStyles.headlineMd.copyWith(color: AppColors.accent),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: _karenaDuplikat
                        ? (result?.duplicateMatches.isNotEmpty == true
                            ? (1 - (result!.duplicateMatches.first.distance / 0.10).clamp(0, 1)).toDouble()
                            : 0)
                        : (result?.aiGeneratedProbability ?? 0),
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_karenaDuplikat ? 'Ambang duplikat: 0,10' : 'Ambang indikasi: 50%',
                        style: AppTextStyles.labelSm.copyWith(color: AppColors.muted, fontSize: 10)),
                    Text('Batas Audit Terlampaui',
                        style: AppTextStyles.labelSm.copyWith(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_karenaDuplikat && (result?.duplicateMatches.isNotEmpty ?? false)) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Karya Pembanding', style: AppTextStyles.headlineSm),
                    Text('Karya terdaftar dengan jarak embedding terdekat',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                  ],
                ),
                Text('${result!.duplicateMatches.length} TEMUAN',
                    style: AppTextStyles.overline.copyWith(color: AppColors.accent)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 260,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final m in result!.duplicateMatches.take(5))
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: _comparisonCard(
                        asset: 'assets/images/catalog/${m.imageFilename}',
                        simPct: 'jarak ${m.distance.toStringAsFixed(3)}',
                        source: 'Katalog GALERIA',
                        title: m.title,
                        meta: m.artistName,
                        statusLabel: 'Terdaftar di GALERIA',
                      ),
                    ),
                ],
              ),
            ),
          ] else if (_karenaAi) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardInner),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Tidak ada karya pembanding untuk kasus ini -- indikasi datang dari pola piksel '
                      'yang dianggap model mirip hasil AI generatif, bukan dari kecocokan dengan karya lain.',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardInner),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text('Status Penyimpanan Aman', style: AppTextStyles.labelMd),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Karyamu tetap aman dan tersimpan dalam draf kuratorial. Kamu dapat melampirkan dokumentasi proses pembuatan (WIP), foto sertifikat fisik, atau bukti kepemilikan sebelumnya untuk melanjutkan kurasi.',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: onAjukanPeninjauan,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text('Ajukan Peninjauan'),
                SizedBox(width: AppSpacing.xs),
                Icon(Icons.arrow_forward, size: 16, color: AppColors.accent),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: onKembali,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Kembali ke Dashboard'),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerHighest,
              side: BorderSide.none,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, size: 13, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Text('Dukungan Kurator 24/7 · Balai Lelang GALERIA',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('ID TIKET TELAAH: #REV-2024-8902B',
                    style: AppTextStyles.overline.copyWith(fontSize: 8.5, color: AppColors.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparisonCard({
    required String asset,
    required String simPct,
    required String source,
    required String title,
    required String meta,
    required String statusLabel,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Image.asset(asset, height: 130, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.compare, size: 11, color: AppColors.accent),
                      const SizedBox(width: 3),
                      Text(simPct, style: AppTextStyles.labelSm.copyWith(fontSize: 10, color: AppColors.accent)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(Icons.museum_outlined, size: 12, color: AppColors.muted),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(source,
                      style: AppTextStyles.labelSm.copyWith(fontSize: 10, color: AppColors.muted),
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
          Text(title,
              style: AppTextStyles.headlineSm.copyWith(fontSize: 15, fontStyle: FontStyle.italic),
              overflow: TextOverflow.ellipsis),
          Text(meta, style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status Registri', style: AppTextStyles.labelSm.copyWith(fontSize: 10, color: AppColors.muted)),
                Text(statusLabel, style: AppTextStyles.labelSm.copyWith(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
