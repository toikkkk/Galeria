import 'dart:typed_data';

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
/// Juga menjalankan deteksi area-terang LIVE (mirip kotak hijau di
/// `ml-visual-search/notebooks/03_demo_inference.ipynb::_auto_detect_bbox`,
/// tapi versi ringan murni Dart -- threshold brightness pada grid piksel
/// yang di-downsample, BUKAN Otsu+contour OpenCV penuh, supaya cukup ringan
/// jalan tiap frame di HP) supaya user bisa LIHAT & sesuaikan framing
/// SEBELUM menekan shutter, bukan cuma tau hasilnya setelah submit.
class CameraPreviewLayer extends StatefulWidget {
  const CameraPreviewLayer({
    super.key,
    this.overlay,
    this.onControllerReady,
    this.onLiveDetection,
  });

  /// Widget yang ditumpuk DI ATAS preview kamera (reticle, kontrol, dll).
  final Widget? overlay;

  /// Dipanggil sekali setiap kali [CameraController] siap dipakai (termasuk
  /// setelah re-init pas app resume dari background) -- dipakai layar
  /// pemanggil (mis. Visual Search) untuk ambil foto via
  /// `controller.takePicture()`. Controller BISA berubah/null lagi (lifecycle
  /// pause/resume) -- jangan simpan referensi tanpa cek `.value.isInitialized`.
  final ValueChanged<CameraController>? onControllerReady;

  /// Dipanggil tiap kali kotak area-terang terdeteksi ulang (throttled, lihat
  /// `_detectionInterval`) -- `Rect` dalam koordinat FRAKSIONAL (0..1) siap
  /// pakai `Positioned.fromRect` relatif ke area kamera penuh, atau `null`
  /// kalau tidak ada area yang cukup jelas terdeteksi.
  final ValueChanged<Rect?>? onLiveDetection;

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
  bool _streaming = false;
  DateTime _lastDetectionAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _detectionInterval = Duration(milliseconds: 250);

  /// Dalam fraksi SizedBox yang SAMA dipakai `CameraPreview` (lihat
  /// `_buildCamera`) -- digambar sebagai sibling `CameraPreview` supaya
  /// otomatis kena transform `BoxFit.cover` yang identik, BUKAN dihitung
  /// manual ulang (rawan meleset kalau container/preview aspect beda).
  Rect? _liveDetectionRect;

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
      widget.onControllerReady?.call(controller);
      await _startLiveDetection();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _CamStatus.error;
        _errorMessage = e.toString();
      });
    }
  }

  /// Panggil dari layar pemanggil SEBELUM `controller.takePicture()` --
  /// paket `camera` tidak boleh streaming gambar & ambil foto bersamaan.
  Future<void> pauseLiveDetection() async {
    final controller = _controller;
    if (controller == null || !_streaming) return;
    _streaming = false;
    try {
      await controller.stopImageStream();
    } catch (_) {
      // Sudah berhenti / controller sedang transisi -- aman diabaikan.
    }
  }

  /// Panggil lagi setelah selesai `takePicture()` kalau mau live detection
  /// jalan lagi (opsional -- boleh dibiarkan pause kalau overlay hasil
  /// sedang tampil).
  Future<void> resumeLiveDetection() async {
    if (_streaming) return;
    await _startLiveDetection();
  }

  Future<void> _startLiveDetection() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _streaming) {
      return;
    }
    _streaming = true;
    try {
      await controller.startImageStream(_onFrame);
    } catch (_) {
      _streaming = false;
    }
  }

  void _onFrame(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastDetectionAt) < _detectionInterval) return;
    _lastDetectionAt = now;

    final sensorOrientation = _controller?.description.sensorOrientation ?? 90;
    final sensorRect = _detectBrightRegion(image);
    final displayRect = sensorRect == null
        ? null
        : _sensorRectToDisplayRect(sensorRect, sensorOrientation);
    if (mounted) setState(() => _liveDetectionRect = displayRect);
    widget.onLiveDetection?.call(displayRect);
  }

  /// Deteksi ringan: downsample plane Y (luminance) ke grid kecil, cari
  /// kotak pembungkus area jauh lebih terang dari rata-rata frame. Setara
  /// tujuan dgn Otsu+contour OpenCV di backend/notebook, tapi versi murni
  /// Dart yang cukup murah dijalankan tiap ~250ms di HP.
  Rect? _detectBrightRegion(CameraImage image) {
    if (image.planes.isEmpty) return null;
    final Uint8List bytes = image.planes[0].bytes;
    final int rowStride = image.planes[0].bytesPerRow;
    final int width = image.width;
    final int height = image.height;
    if (width <= 0 || height <= 0) return null;

    const gridCols = 32;
    const gridRows = 24;
    final brightness = List<double>.filled(gridCols * gridRows, 0);

    for (int gy = 0; gy < gridRows; gy++) {
      final py = ((gy + 0.5) * height / gridRows).floor().clamp(0, height - 1);
      for (int gx = 0; gx < gridCols; gx++) {
        final px = ((gx + 0.5) * width / gridCols).floor().clamp(0, width - 1);
        final idx = py * rowStride + px;
        brightness[gy * gridCols + gx] = idx < bytes.length
            ? bytes[idx].toDouble()
            : 0;
      }
    }

    final mean = brightness.reduce((a, b) => a + b) / brightness.length;
    final maxV = brightness.reduce((a, b) => a > b ? a : b);
    if (maxV - mean < 12) return null; // frame nyaris rata -- tidak ada objek jelas
    final threshold = mean + (maxV - mean) * 0.4;

    // Frame bisa punya BEBERAPA area terang yang tidak nyambung (mis. status
    // bar terang di atas + video terang di bawah + lukisan di tengah) --
    // union bounding box dari SEMUA titik terang akan menghasilkan kotak
    // raksasa yang salah (pernah terjadi: garis hijau melebar penuh
    // selebar layar). Jadi kelompokkan dulu jadi connected components
    // (flood-fill 4-arah), lalu pilih SATU klaster yang paling masuk akal
    // (ukuran wajar & paling dekat ke tengah frame -- user diarahkan untuk
    // menaruh objek di tengah bracket).
    final visited = List<bool>.filled(gridCols * gridRows, false);
    Rect? bestRect;
    double bestScore = double.negativeInfinity;
    const centerGx = (gridCols - 1) / 2;
    const centerGy = (gridRows - 1) / 2;

    for (int gy = 0; gy < gridRows; gy++) {
      for (int gx = 0; gx < gridCols; gx++) {
        final startIdx = gy * gridCols + gx;
        if (visited[startIdx] || brightness[startIdx] < threshold) continue;

        // BFS untuk satu komponen.
        int minCx = gx, maxCx = gx, minCy = gy, maxCy = gy, cCount = 0;
        final queue = <int>[startIdx];
        visited[startIdx] = true;
        while (queue.isNotEmpty) {
          final idx = queue.removeLast();
          final cx = idx % gridCols;
          final cy = idx ~/ gridCols;
          cCount++;
          if (cx < minCx) minCx = cx;
          if (cx > maxCx) maxCx = cx;
          if (cy < minCy) minCy = cy;
          if (cy > maxCy) maxCy = cy;
          for (final n in [
            if (cx > 0) idx - 1,
            if (cx < gridCols - 1) idx + 1,
            if (cy > 0) idx - gridCols,
            if (cy < gridRows - 1) idx + gridCols,
          ]) {
            if (!visited[n] && brightness[n] >= threshold) {
              visited[n] = true;
              queue.add(n);
            }
          }
        }

        final cArea = cCount / (gridCols * gridRows);
        // Terlalu kecil (noise) atau terlalu besar (nyaris seluruh frame,
        // mis. dinding putih polos) -- lewati klaster ini.
        if (cArea < 0.03 || cArea > 0.85) continue;

        final cCenterGx = (minCx + maxCx) / 2;
        final cCenterGy = (minCy + maxCy) / 2;
        final distFromCenter =
            ((cCenterGx - centerGx).abs() / gridCols) +
            ((cCenterGy - centerGy).abs() / gridRows);
        // Skor: lebih besar & lebih dekat ke tengah = lebih baik.
        final score = cArea - distFromCenter * 0.5;
        if (score > bestScore) {
          bestScore = score;
          bestRect = Rect.fromLTWH(
            minCx / gridCols,
            minCy / gridRows,
            (maxCx - minCx + 1) / gridCols,
            (maxCy - minCy + 1) / gridRows,
          );
        }
      }
    }

    return bestRect;
  }

  /// Konversi rect fraksional dari koordinat SENSOR (orientasi landscape
  /// mentah, lihat `image.width`/`image.height` di [_onFrame]) ke koordinat
  /// fraksional DISPLAY (SizedBox yang sama dipakai `CameraPreview`, lihat
  /// `_buildCamera` -- width=previewSize.height, height=previewSize.width).
  /// `sensorOrientation` dari `CameraDescription` (biasanya 90 utk kamera
  /// belakang) menentukan arah rotasinya -- BUKAN ditebak, diambil dari
  /// metadata device sungguhan.
  Rect _sensorRectToDisplayRect(Rect s, int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return Rect.fromLTWH(1 - s.top - s.height, s.left, s.height, s.width);
      case 270:
        return Rect.fromLTWH(s.top, 1 - s.left - s.width, s.height, s.width);
      case 180:
        return Rect.fromLTWH(1 - s.left - s.width, 1 - s.top - s.height, s.width, s.height);
      default: // 0 -- tanpa rotasi
        return s;
    }
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
      _streaming = false;
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
    WidgetsBinding.instance.removeObserver(this);
    _streaming = false;
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(controller),
                    if (_liveDetectionRect != null)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _LiveDetectionPainter(_liveDetectionRect!),
                        ),
                      ),
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

/// Kotak hijau LIVE (mirip `_auto_detect_bbox` di notebook demo) -- `rect`
/// dalam fraksi 0..1 relatif ke `canvas.size` (SizedBox yang sama dipakai
/// `CameraPreview`, lihat pemanggilnya) -- `CustomPainter` dipakai (bukan
/// widget biasa) supaya scaling ke ukuran canvas otomatis tanpa perlu
/// `LayoutBuilder` terpisah.
class _LiveDetectionPainter extends CustomPainter {
  const _LiveDetectionPainter(this.rect);

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Rect.fromLTWH(
      rect.left * size.width,
      rect.top * size.height,
      rect.width * size.width,
      rect.height * size.height,
    );
    final paint = Paint()
      ..color = const Color(0xFF4CD964)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(6)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LiveDetectionPainter oldDelegate) =>
      oldDelegate.rect != rect;
}
