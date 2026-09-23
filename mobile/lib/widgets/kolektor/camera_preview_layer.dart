import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../theme/app_theme.dart';

/// Lapisan kamera live (full-bleed, cover) dipakai bersama oleh Visual
/// Search & AR Ruangan supaya boilerplate izin + inisialisasi
/// [CameraController] tidak diduplikasi di kedua layar.
///
/// Alur status: loading (spinner) -> preview kamera live (setelah izin
/// diberikan & controller siap) -> pesan izin ditolak (+ tombol buka
/// Pengaturan) -> pesan error lain (mis. tidak ada kamera di device).
class CameraPreviewLayer extends StatefulWidget {
  const CameraPreviewLayer({super.key, this.overlay});

  /// Widget yang ditumpuk DI ATAS preview kamera (reticle, kontrol, dll).
  final Widget? overlay;

  @override
  State<CameraPreviewLayer> createState() => _CameraPreviewLayerState();
}

enum _CamStatus {
  loading,
  ready,
  permissionDenied,
  permissionPermanentlyDenied,
  noCamera,
  error,
}

class _CameraPreviewLayerState extends State<CameraPreviewLayer>
    with WidgetsBindingObserver {
  CameraController? _controller;
  _CamStatus _status = _CamStatus.loading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    setState(() => _status = _CamStatus.loading);
    final permStatus = await Permission.camera.request();
    if (!mounted) return;
    if (permStatus.isPermanentlyDenied) {
      setState(() => _status = _CamStatus.permissionPermanentlyDenied);
      return;
    }
    if (!permStatus.isGranted) {
      setState(() => _status = _CamStatus.permissionDenied);
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _status = _CamStatus.noCamera);
        return;
      }
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _status = _CamStatus.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _CamStatus.error;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _init();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [_buildCamera(), if (widget.overlay != null) widget.overlay!],
      ),
    );
  }

  Widget _buildCamera() {
    switch (_status) {
      case _CamStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      case _CamStatus.ready:
        final controller = _controller!;
        final previewSize = controller.value.previewSize;
        return ClipRect(
          child: OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: FittedBox(
              fit: BoxFit.cover,
              // previewSize dari sensor kamera datang dalam orientasi
              // landscape -- ditukar (width<->height) supaya "cover" pas
              // saat device dipegang portrait (pola umum paket `camera`).
              child: SizedBox(
                width: previewSize?.height ?? 1,
                height: previewSize?.width ?? 1,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      case _CamStatus.permissionDenied:
        return _message(
          icon: Icons.camera_alt_outlined,
          title: 'Izin Kamera Diperlukan',
          message:
              'GALERIA butuh akses kamera untuk fitur Pencarian Visual & Coba di Ruangan (AR).',
          actionLabel: 'Coba Lagi',
          onAction: _init,
        );
      case _CamStatus.permissionPermanentlyDenied:
        return _message(
          icon: Icons.camera_alt_outlined,
          title: 'Izin Kamera Diblokir',
          message:
              'Aktifkan izin kamera secara manual lewat Pengaturan Aplikasi.',
          actionLabel: 'Buka Pengaturan',
          onAction: openAppSettings,
        );
      case _CamStatus.noCamera:
        return _message(
          icon: Icons.camera_alt_outlined,
          title: 'Kamera Tidak Ditemukan',
          message: 'Perangkat ini tidak memiliki kamera yang dapat diakses.',
        );
      case _CamStatus.error:
        return _message(
          icon: Icons.error_outline,
          title: 'Kamera Gagal Dimuat',
          message: _errorMessage ?? 'Terjadi kesalahan saat membuka kamera.',
          actionLabel: 'Coba Lagi',
          onAction: _init,
        );
    }
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.white70),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: AppTextStyles.headlineSm.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: AppTextStyles.bodySm.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
