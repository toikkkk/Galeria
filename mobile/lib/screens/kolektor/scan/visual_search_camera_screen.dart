import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kolektor/camera_preview_layer.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR AR VISUAL SEARCH/.../galeria_kamera_pencarian_visual_live_capture_deteksi/code.html
/// + galeria_pencarian_visual_karya_ditemukan_full_screen + ..._tidak_ditemukan.
///
/// PENTING (lihat backend/schemas/visual_search.py & mobile/README.md):
/// hasil scan SELALU digambarkan lewat 3 status `verdict` --
/// confirmed / ambiguous / not_found -- BUKAN persentase kecocokan pasti
/// seperti "98,4% KECOCOKAN" di mockup asli, karena itu overclaim yang
/// menyesatkan (model bisa salah, terutama utuk kasus ambiguous).
///
/// Viewfinder pakai kamera live sungguhan (CameraPreviewLayer). Yang BELUM
/// nyata: panggilan `POST /api/visual-search` -- shutter masih
/// mensimulasikan salah satu dari 3 hasil demo (bukan hasil model asli),
/// karena integrasi backend↔mobile belum dikerjakan (lihat mobile/README.md).
///
/// TODO(backend): ambil frame dari `CameraController` (mis. `takePicture()`)
/// dan kirim ke backend/routers/visual_search.py begitu endpoint siap
/// dipanggil dari mobile, ganti [_simulateScan] dengan hasil nyata.
enum _ScanVerdict { confirmed, ambiguous, notFound }

class VisualSearchCameraScreen extends StatefulWidget {
  const VisualSearchCameraScreen({
    super.key,
    required this.onBack,
    this.onArTap,
    this.onKaryaTap,
  });

  final VoidCallback onBack;
  final VoidCallback? onArTap;
  final ValueChanged<Karya>? onKaryaTap;

  @override
  State<VisualSearchCameraScreen> createState() =>
      _VisualSearchCameraScreenState();
}

class _VisualSearchCameraScreenState extends State<VisualSearchCameraScreen> {
  bool _flash = false;
  _ScanVerdict? _result;
  int _simCounter = 0;

  void _simulateScan() {
    // Siklus 3 hasil demo secara bergantian supaya ketiga status bisa
    // ditunjukkan tanpa kamera/model sungguhan.
    setState(() {
      _result = _ScanVerdict.values[_simCounter % 3];
      _simCounter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CameraPreviewLayer(
        overlay: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenGutter,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _roundIcon(Icons.arrow_back, onTap: widget.onBack),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            'PENCARIAN VISUAL',
                            style: AppTextStyles.overline.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        _roundIcon(
                          _flash ? Icons.flash_on : Icons.flash_off,
                          onTap: () => setState(() => _flash = !_flash),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 260,
                        height: 320,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.accent, width: 2),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            'Sejajarkan kanvas di dalam bingkai',
                            style: AppTextStyles.bodySm.copyWith(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _labeledIcon(
                          Icons.photo_library_outlined,
                          'Galeri',
                          onTap: () {},
                        ),
                        GestureDetector(
                          onTap: _simulateScan,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: AppColors.accent,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.center_focus_strong,
                              color: Colors.black,
                              size: 26,
                            ),
                          ),
                        ),
                        _labeledIcon(
                          Icons.view_in_ar_outlined,
                          'Coba AR',
                          onTap: widget.onArTap ?? () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_result != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _result = null),
                  child: Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap:
                          () {}, // menyerap tap supaya tidak menutup saat interaksi kartu
                      child: _ResultCard(
                        verdict: _result!,
                        onClose: () => setState(() => _result = null),
                        onKaryaTap: widget.onKaryaTap,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _roundIcon(IconData icon, {required VoidCallback onTap}) => InkWell(
    onTap: onTap,
    customBorder: const CircleBorder(),
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );

  Widget _labeledIcon(
    IconData icon,
    String label, {
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.full),
    child: Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.verdict,
    required this.onClose,
    this.onKaryaTap,
  });

  final _ScanVerdict verdict;
  final VoidCallback onClose;
  final ValueChanged<Karya>? onKaryaTap;

  @override
  Widget build(BuildContext context) {
    final karya = sampleKarya[3];
    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 24)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _verdictBadge(),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (verdict != _ScanVerdict.notFound) ...[
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.asset(
                    karya.assetPath,
                    width: 64,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        karya.styleName,
                        style: AppTextStyles.overline.copyWith(
                          fontSize: 9,
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        karya.title,
                        style: AppTextStyles.headlineSm.copyWith(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      Text(
                        karya.priceFormatted,
                        style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _message(),
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.muted,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
              onPressed: () => onKaryaTap?.call(karya),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: Text(
                verdict == _ScanVerdict.confirmed
                    ? 'Lihat Karya'
                    : 'Periksa Kemiripan Ini',
              ),
            ),
          ] else ...[
            Text('Karya Belum Terdaftar', style: AppTextStyles.headlineSm),
            const SizedBox(height: 4),
            Text(
              'Karya ini belum ada di katalog GALERIA. Berikut rekomendasi kurator dengan gaya serupa:',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.muted,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final k in sampleKarya.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: InkWell(
                  onTap: () => onKaryaTap?.call(k),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.asset(
                          k.assetPath,
                          width: 44,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              k.title,
                              style: AppTextStyles.labelMd.copyWith(
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              k.priceFormatted,
                              style: AppTextStyles.bodySm.copyWith(
                                fontSize: 11,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _message() {
    switch (verdict) {
      case _ScanVerdict.confirmed:
        return 'Kecocokan tinggi dengan katalog GALERIA.';
      case _ScanVerdict.ambiguous:
        return 'Kemiripan terdeteksi, namun bukan kepastian -- periksa detail sebelum yakin ini karya yang sama.';
      case _ScanVerdict.notFound:
        return '';
    }
  }

  Widget _verdictBadge() {
    late final Color bg, fg;
    late final IconData icon;
    late final String label;
    switch (verdict) {
      case _ScanVerdict.confirmed:
        bg = AppColors.successContainer.withValues(alpha: 0.15);
        fg = AppColors.success;
        icon = Icons.verified;
        label = 'Karya Ditemukan';
      case _ScanVerdict.ambiguous:
        bg = AppColors.accentSoft.withValues(alpha: 0.5);
        fg = AppColors.accent;
        icon = Icons.help_outline;
        label = 'Kemiripan Terdeteksi';
      case _ScanVerdict.notFound:
        bg = AppColors.surfaceContainer;
        fg = AppColors.muted;
        icon = Icons.info_outline;
        label = 'Belum Terdaftar';
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSm.copyWith(fontSize: 10.5, color: fg),
          ),
        ],
      ),
    );
  }
}
