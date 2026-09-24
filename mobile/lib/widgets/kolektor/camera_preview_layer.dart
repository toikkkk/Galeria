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
///
/// [CameraPreviewLayerState.screenRectToPreviewFraction] memetakan rect di
/// layar (mis. bingkai panduan) ke fraksi gambar kamera, dipakai utk crop foto.
class CameraPreviewLayer extends StatefulWidget {
  const CameraPreviewLayer({
    super.key,
    this.overlay,
    this.onControllerReady,
    this.zoom,
    this.zoomRange,
  });

  /// Widget yang ditumpuk DI ATAS preview kamera (reticle, kontrol, dll).
  final Widget? overlay;

  /// Dipanggil sekali setiap kali [CameraController] siap dipakai (termasuk
  /// setelah re-init pas app resume dari background) -- dipakai layar
  /// pemanggil (mis. Visual Search) untuk ambil foto via
  /// `controller.takePicture()`. Controller BISA berubah/null lagi (lifecycle
  /// pause/resume) -- jangan simpan referensi tanpa cek `.value.isInitialized`.
  final ValueChanged<CameraController>? onControllerReady;

  /// Level zoom yang diinginkan (opsional). Layar pemanggil (mis. slider)
  /// cukup mengubah `value`-nya -- layer ini yang menerapkannya ke kamera.
  /// Kalau diisi, cubit dua jari di preview juga ikut mengubahnya. Null =
  /// zoom dimatikan (mis. AR Ruangan).
  final ValueNotifier<double>? zoom;

  /// Diisi layer ini setelah kamera siap: zoom minimum & maksimum yang
  /// didukung device (maks dibatasi [_maxUsableZoom] supaya tidak terlalu
  /// pecah), dipakai layar pemanggil untuk rentang slider.
  final ValueNotifier<RangeValues>? zoomRange;

  @override
  State<CameraPreviewLayer> createState() => CameraPreviewLayerState();
}

enum _CamStatus {
  loading,
  ready,
  permissionDenied,
  permissionPermanentlyDenied,
  noCamera,
  error,
}

class CameraPreviewLayerState extends State<CameraPreviewLayer>
    with WidgetsBindingObserver {
  CameraController? _controller;
  _CamStatus _status = _CamStatus.loading;
  String? _errorMessage;

  /// Zoom digital di atas ini kualitas fotonya turun -- merugikan model.
  static const _maxUsableZoom = 5.0;
  double _pinchBaseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.zoom?.addListener(_applyZoom);
    _init();
  }

  Future<void> _applyZoom() async {
    final controller = _controller;
    final zoom = widget.zoom;
    if (controller == null || !controller.value.isInitialized || zoom == null) {
      return;
    }
    try {
      await controller.setZoomLevel(zoom.value);
    } catch (_) {
      // Controller sedang transisi / zoom di luar rentang -- abaikan.
    }
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
      widget.onControllerReady?.call(controller);
      if (widget.zoom != null) {
        final min = await controller.getMinZoomLevel();
        final max = await controller.getMaxZoomLevel();
        final usableMax = max > _maxUsableZoom ? _maxUsableZoom : max;
        widget.zoomRange?.value = RangeValues(min, usableMax);
        // Kamera baru selalu mulai di zoom minimum.
        widget.zoom!.value = min;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _CamStatus.error;
        _errorMessage = e.toString();
      });
    }
  }

  /// Ubah rect di koordinat LAYAR (mis. bingkai panduan, dalam koordinat
  /// global) jadi fraksi 0..1 dari gambar kamera -- foto hasil
  /// `takePicture()` punya rasio & orientasi sama dgn preview, jadi fraksi
  /// ini bisa dipakai langsung utk crop foto. Memperhitungkan `BoxFit.cover`
  /// (preview dipotong kiri-kanan/atas-bawah agar memenuhi layar), bukan
  /// sekadar membagi dgn ukuran layar. `null` kalau kamera belum siap.
  Rect? screenRectToPreviewFraction(Rect globalRect) {
    final controller = _controller;
    final previewSize = controller?.value.previewSize;
    final box = context.findRenderObject();
    if (controller == null ||
        !controller.value.isInitialized ||
        previewSize == null ||
        box is! RenderBox ||
        !box.hasSize) {
      return null;
    }
    // previewSize dari sensor berorientasi landscape -- ditukar utk portrait
    // (sama dgn `_buildCamera`).
    final pw = previewSize.height;
    final ph = previewSize.width;
    final sw = box.size.width;
    final sh = box.size.height;
    final scale = (sw / pw) > (sh / ph) ? sw / pw : sh / ph;
    final dispW = pw * scale;
    final dispH = ph * scale;
    final offX = (sw - dispW) / 2;
    final offY = (sh - dispH) / 2;
    final local = globalRect.shift(-box.localToGlobal(Offset.zero));
    double f(double v) => v.clamp(0.0, 1.0);
    final l = f((local.left - offX) / dispW);
    final t = f((local.top - offY) / dispH);
    final r = f((local.right - offX) / dispW);
    final b = f((local.bottom - offY) / dispH);
    if (r - l <= 0 || b - t <= 0) return null;
    return Rect.fromLTRB(l, t, r, b);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Guard ini HARUS cuma berlaku utk cabang pause/inactive (cegah
      // dispose dobel kalau sudah null) -- sebelumnya guard ini ada di
      // ATAS switch, jadi ikut mem-block cabang `resumed` di bawah begitu
      // _controller null (persis kondisi tiap habis pause). Akibatnya
      // `resumed` tidak pernah panggil _init() lagi -> app nyangkut
      // loading selamanya stlh sekali pause/resume (mis. buka galeri).
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) return;
      controller.dispose();
      _controller = null;
      // WAJIB reset _status juga -- kalau tetap `ready` sementara
      // _controller sudah null, rebuild APAPUN yang terjadi sebelum
      // _init() selesai (mis. tepat saat app resume dari image picker
      // galeri, yang memicu lifecycle inactive/paused lalu resumed dalam
      // waktu singkat) bikin _buildCamera() crash null-check di
      // `_controller!` (case ready).
      if (mounted) setState(() => _status = _CamStatus.loading);
    } else if (state == AppLifecycleState.resumed) {
      // TANPA guard _controller di sini -- resumed HARUS selalu coba
      // re-init, apalagi justru saat _controller null (kasus paling umum:
      // baru saja kembali dari pause).
      _init();
    }
  }

  @override
  void dispose() {
    widget.zoom?.removeListener(_applyZoom);
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stack = ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [_buildCamera(), if (widget.overlay != null) widget.overlay!],
      ),
    );
    final zoom = widget.zoom;
    if (zoom == null) return stack;
    // Cubit dua jari = zoom. Tap tombol di overlay tetap jalan normal
    // (scale hanya menang di arena gesture kalau ada gerakan dua jari).
    return GestureDetector(
      onScaleStart: (_) => _pinchBaseZoom = zoom.value,
      onScaleUpdate: (d) {
        if (d.pointerCount < 2) return;
        final range = widget.zoomRange?.value;
        final min = range?.start ?? 1.0;
        final max = range?.end ?? 1.0;
        zoom.value = (_pinchBaseZoom * d.scale).clamp(min, max);
      },
      child: stack,
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(controller),
                  ],
                ),
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
