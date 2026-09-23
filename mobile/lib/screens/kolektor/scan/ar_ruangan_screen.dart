import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kolektor/camera_preview_layer.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR AR VISUAL SEARCH/.../galeria_coba_di_ruangan_ar/code.html
///
/// PENTING: latar belakangnya kamera live sungguhan (CameraPreviewLayer) dan
/// karya bisa digeser/dicubit(scale)/diputar bebas dengan jari di atasnya --
/// tapi ini TETAP simulasi penempatan manual, BUKAN AR sungguhan berbasis
/// plane detection. CLAUDE.md: AR Simulation seharusnya pakai SDK ARCore
/// (Android) / ARKit (iOS) dengan deteksi bidang dinding & estimasi skala
/// otomatis dari ukuran fisik karya (cm) -- itu BELUM diimplementasikan
/// (lihat status proyek: "Belum dikerjakan: implementasi AR"). Di sini
/// posisi/ukuran/rotasi murni dikendalikan gestur pengguna, tidak ada
/// penjangkaran ke bidang dunia nyata, jadi "Skala 1:1" TIDAK diklaim di
/// label (lihat catatan di bawah).
///
/// TODO(mobile): ganti dengan integrasi ARCore/ARKit nyata (mis. paket
/// `ar_flutter_plugin` atau native platform channel) + plane detection +
/// scale estimation otomatis dari ukuran fisik karya (cm) dari form upload,
/// begitu tersedia.
class ArRuanganScreen extends StatefulWidget {
  const ArRuanganScreen({super.key, required this.onClose, this.karya});

  final VoidCallback onClose;
  final Karya? karya;

  @override
  State<ArRuanganScreen> createState() => _ArRuanganScreenState();
}

class _ArRuanganScreenState extends State<ArRuanganScreen> {
  double _scale = 1.0;
  double _rotation = 0.0;
  Offset _offset = Offset.zero;

  double _startScale = 1.0;
  double _startRotation = 0.0;

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _scale;
    _startRotation = _rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_startScale * details.scale).clamp(0.4, 3.0);
      _rotation = _startRotation + details.rotation;
      _offset += details.focalPointDelta;
    });
  }

  void _reset() {
    setState(() {
      _scale = 1.0;
      _rotation = 0.0;
      _offset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final karya = widget.karya ?? sampleKarya[3];
    return Scaffold(
      backgroundColor: Colors.black,
      body: CameraPreviewLayer(
        overlay: Stack(
          children: [
            // Karya yang bisa digeser (1 jari), diperbesar/perkecil & diputar
            // (2 jari) bebas ke posisi mana pun di atas kamera live.
            Center(
              child: GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                child: Transform.translate(
                  offset: _offset,
                  child: Transform.rotate(
                    angle: _rotation,
                    child: Transform.scale(
                      scale: _scale,
                      child: _FramedArtwork(karya: karya),
                    ),
                  ),
                ),
              ),
            ),
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
                        InkWell(
                          onTap: widget.onClose,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            'COBA DI RUANGAN (AR)',
                            style: AppTextStyles.overline.copyWith(
                              color: Colors.white,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.help_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Petunjuk singkat -- hanya tampil selagi belum digeser sama
                  // sekali, supaya tidak menutupi pandangan setelah dipakai.
                  if (_offset == Offset.zero &&
                      _scale == 1.0 &&
                      _rotation == 0.0)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          'Geser 1 jari, cubit 2 jari utk ubah ukuran & putar',
                          style: AppTextStyles.bodySm.copyWith(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenGutter,
                      AppSpacing.sm,
                      AppSpacing.screenGutter,
                      AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _tool(
                          Icons.zoom_in,
                          'Perbesar',
                          onTap: () => setState(
                            () => _scale = (_scale + 0.15).clamp(0.4, 3.0),
                          ),
                        ),
                        _tool(
                          Icons.photo_camera,
                          'Ambil Foto',
                          primary: true,
                          onTap: () {},
                        ),
                        _tool(Icons.restart_alt, 'Reset', onTap: _reset),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tool(
    IconData icon,
    String label, {
    bool primary = false,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.full),
    child: Column(
      children: [
        Container(
          width: primary ? 56 : 44,
          height: primary ? 56 : 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary
                ? Colors.white
                : Colors.white.withValues(alpha: 0.15),
          ),
          child: Icon(
            icon,
            color: primary ? Colors.black : Colors.white,
            size: primary ? 24 : 18,
          ),
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

class _FramedArtwork extends StatelessWidget {
  const _FramedArtwork({required this.karya});

  final Karya karya;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF3E2A1A),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            child: Image.asset(
              karya.assetPath,
              width: 180,
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.straighten,
                    size: 11,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '120 × 90 cm',
                    style: AppTextStyles.overline.copyWith(
                      color: Colors.white,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
