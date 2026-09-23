import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/karya.dart';
import '../../../services/visual_search_service.dart';
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
/// Shutter memanggil `POST /api/visual-search` beneran (lewat
/// [VisualSearchService]) -- foto diambil dari [CameraController] yang
/// sama dipakai preview live, dikirim ke backend, hasilnya (verdict +
/// kandidat karya) ditampilkan apa adanya.
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
  bool _scanning = false;
  VisualSearchResult? _result;
  File? _lastScannedPhoto;
  CameraController? _cameraController;
  final _cameraKey = GlobalKey<CameraPreviewLayerState>();

  /// Kotak hijau live-detect TERAKHIR yang tampil di layar (fraksi 0..1) --
  /// disimpan tiap kali [CameraPreviewLayer] mendeteksi ulang, dipakai
  /// [_scan] sebagai hint crop supaya apa yang user LIHAT sudah pas di
  /// layar juga yang BENAR-BENAR dikirim ke backend, bukan diabaikan
  /// (sebelum ini backend selalu proses foto penuh + tebakan sendiri,
  /// terlepas dari kotak hijau yang sudah user konfirmasi visual).
  Rect? _lastLiveRect;

  Future<void> _scan() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _scanning) {
      return;
    }
    // Simpan SEBELUM pause -- pauseLiveDetection menghentikan image stream,
    // rect terakhir yang sempat terlihat user itu yang mau dipakai.
    final hintRect = _lastLiveRect;
    setState(() => _scanning = true);
    try {
      // WAJIB stop image stream (live detection) dulu -- paket `camera`
      // tidak izinkan streaming gambar & takePicture() bersamaan.
      await _cameraKey.currentState?.pauseLiveDetection();
      final photo = await controller.takePicture();
      await _submitPhoto(File(photo.path), hintRect: hintRect);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memindai: $e')),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Pilih gambar dari galeri HP sebagai alternatif motret langsung --
  /// berguna utk cek model dgn gambar bersih (tanpa noise kamera
  /// live/pantulan layar HP lain), atau kalau user sudah punya foto karya
  /// tersimpan.
  Future<void> _pickFromGallery() async {
    if (_scanning) return;
    try {
      // WAJIB di dalam try -- pickImage() SENDIRI bisa throw (mis. plugin
      // image_picker_android crash dgn "Null check operator used on a null
      // value" kalau proses app sempat dibekukan OS Android saat dialog
      // galeri dibuka lama, lalu Activity re-create dgn Intent hasil null).
      // Sebelumnya try/catch cuma membungkus _submitPhoto, bukan pickImage
      // -- exception dari sini lolos jadi crash fatal (red screen), bukan
      // pesan error yang rapi.
      //
      // TANPA `imageQuality` -- dgn parameter itu, plugin lewat jalur
      // kompresi ulang yang juga rawan null-check crash serupa (mis. file
      // dari galeri cloud/Google Photos yang belum ter-download lokal).
      // Kompresi client-side juga tidak perlu -- backend sudah preprocessing
      // sendiri (lihat visual_search_service.py::_preprocess).
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (picked == null || !mounted) return;
      setState(() => _scanning = true);
      // Gambar dari galeri bukan dari live preview kamera -- tidak ada
      // kotak hijau yang relevan (live-detect cuma jalan di stream kamera),
      // jadi tanpa hintRect. Backend tetap coba kandidat crop lain (lihat
      // backend/services/visual_search_service.py::_candidate_crops).
      await _submitPhoto(File(picked.path), hintRect: null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membuka galeri atau memindai gambar: $e. Coba lagi.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Kirim 1 foto (dari kamera ATAU galeri) ke backend, simpan hasilnya.
  /// Dipisah dari [_scan]/[_pickFromGallery] supaya logic submit tidak
  /// diduplikasi utk dua sumber gambar yang beda.
  Future<void> _submitPhoto(File photoFile, {Rect? hintRect}) async {
    // top_k besar (seluruh katalog) -- supaya rekomendasi "gaya serupa" di
    // _ResultCard bisa filter dari daftar lengkap, bukan cuma top-5.
    final result = await VisualSearchService().scanImage(
      photoFile,
      topK: 20,
      hintRect: hintRect,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _lastScannedPhoto = photoFile; // ditampilkan di kartu "belum terdaftar"
    });
  }

  void _closeResult() {
    setState(() => _result = null);
    // Balik ke mode live-detect kotak hijau begitu kartu hasil ditutup.
    _cameraKey.currentState?.resumeLiveDetection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CameraPreviewLayer(
        key: _cameraKey,
        onControllerReady: (c) => _cameraController = c,
        onLiveDetection: (rect) => _lastLiveRect = rect,
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
                      // Bingkai kurasi: 4 bracket sudut (BUKAN border penuh),
                      // lebar 84% area kamera (maks 280) & aspect ratio 4:5
                      // -- persis desain asli (lihat docs/design/.../
                      // galeria_kamera_pencarian_visual_live_capture_deteksi),
                      // supaya bingkai "mengikuti ukuran lukisan" potret pada
                      // umumnya, bukan kotak generik fixed-size.
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final boxWidth = (constraints.maxWidth * 0.84)
                              .clamp(0, 280)
                              .toDouble();
                          final boxHeight = boxWidth * 5 / 4;
                          return SizedBox(
                            width: boxWidth,
                            height: boxHeight,
                            child: Stack(
                              children: [
                                _cornerBracket(top: true, left: true),
                                _cornerBracket(top: true, left: false),
                                _cornerBracket(top: false, left: true),
                                _cornerBracket(top: false, left: false),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.full,
                                        ),
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
                              ],
                            ),
                          );
                        },
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
                          onTap: _pickFromGallery,
                        ),
                        GestureDetector(
                          onTap: _scanning ? null : _scan,
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
                            child: _scanning
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.accent,
                                    ),
                                  )
                                : const Icon(
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
                  onTap: _closeResult,
                  child: Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap:
                          () {}, // menyerap tap supaya tidak menutup saat interaksi kartu
                      child: _ResultCard(
                        result: _result!,
                        scannedPhoto: _lastScannedPhoto,
                        onClose: _closeResult,
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

  /// Satu bracket sudut "L" (bukan border penuh) -- lihat komentar di
  /// pemanggilnya untuk konteks desain asli.
  Widget _cornerBracket({required bool top, required bool left}) {
    const size = 28.0;
    const thickness = 3.0;
    final glow = [
      BoxShadow(
        color: AppColors.accent.withValues(alpha: 0.7),
        blurRadius: 6,
      ),
    ];
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned(
              top: top ? 0 : null,
              bottom: top ? null : 0,
              left: 0,
              right: 0,
              child: Container(
                height: thickness,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  boxShadow: glow,
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: left ? 0 : null,
              right: left ? null : 0,
              child: Container(
                width: thickness,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  boxShadow: glow,
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

/// Kartu hasil, konversi dari 2 layar Stitch terpisah (lebih detail dari
/// versi compact sebelumnya):
/// docs/.../galeria_pencarian_visual_karya_ditemukan_full_screen +
/// docs/.../galeria_pencarian_visual_karya_tidak_ditemukan_rekomendasi_serupa
///
/// Field yang TIDAK ADA di data kita (medium/teknik cat, ukuran fisik cm,
/// nomor lot lelang) SENGAJA dihilangkan dari mockup asli -- bukan di-"karang"
/// -- supaya tidak overclaim data yang tidak benar-benar kita punya. Baris
/// trust ("Provenansi Sah" dkk) tetap dipakai apa adanya karena itu copy
/// pemasaran generik (sama utk semua karya), bukan klaim data spesifik.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.onClose,
    this.scannedPhoto,
    this.onKaryaTap,
  });

  final VisualSearchResult result;
  final VoidCallback onClose;
  final File? scannedPhoto;
  final ValueChanged<Karya>? onKaryaTap;

  @override
  Widget build(BuildContext context) {
    final matches = result.matches;
    final primary = matches.isNotEmpty ? matches.first.karya : null;

    // Logika: "confirmed" -> tampilkan harga & toko karya itu LANGSUNG
    // (yakin itu karyanya). Selain itu (ambiguous / not_found) -- JANGAN
    // tampilkan seolah itu satu match pasti; tampilkan sebagai rekomendasi
    // katalog dengan GAYA yang sama (pakai style karya #1 hasil pencarian
    // sebagai "gaya terdeteksi", lalu filter kandidat lain yang senada).
    final detectedStyle = primary?.styleName;
    final styleMatches = detectedStyle == null
        ? const <VisualSearchMatch>[]
        : matches.where((m) => m.karya.styleName == detectedStyle).toList();

    return Container(
      width: MediaQuery.sizeOf(context).width * 0.9,
      constraints: const BoxConstraints(maxWidth: 380),
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 28)],
      ),
      child: result.isConfirmed && primary != null
          ? _buildFound(context, primary)
          : _buildNotFound(context, detectedStyle, styleMatches),
    );
  }

  // ---------------------------------------------------------------------
  // Karya Ditemukan (confirmed)
  // ---------------------------------------------------------------------

  Widget _buildFound(BuildContext context, Karya karya) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _pillBadge(
                    icon: Icons.verified,
                    label: 'Karya Ditemukan di GALERIA',
                    bg: AppColors.successContainer.withValues(alpha: 0.2),
                    fg: AppColors.success,
                    dotted: true,
                  ),
                  _pillBadge(
                    icon: Icons.sell_outlined,
                    label: 'TERSEDIA UNTUK DIBELI',
                    bg: AppColors.accentSoft.withValues(alpha: 0.4),
                    fg: AppColors.accent,
                    small: true,
                  ),
                ],
              ),
            ),
            _closeButton(),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.asset(
                karya.assetPath,
                width: 80,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aliran ${karya.styleName}',
                    style: AppTextStyles.overline.copyWith(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    karya.title,
                    style: AppTextStyles.headlineMd.copyWith(
                      fontSize: 19,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ESTIMASI NILAI',
                    style: AppTextStyles.overline.copyWith(
                      fontSize: 8.5,
                      color: AppColors.outline,
                    ),
                  ),
                  Text(
                    karya.priceFormatted,
                    style: AppTextStyles.headlineMd.copyWith(fontSize: 17),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.storefront,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DIJUAL RESMI OLEH',
                      style: AppTextStyles.overline.copyWith(
                        fontSize: 8,
                        color: AppColors.outline,
                      ),
                    ),
                    Text(
                      karya.galleryName,
                      style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.verified_user,
                size: 18,
                color: AppColors.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Pesan verdict LANGSUNG dari backend -- jangan ditimpa jadi kalimat
        // yang lebih pasti dari itu (lihat catatan overclaim di atas file).
        Text(
          result.verdictMessage,
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.muted,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onKaryaTap?.call(karya),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('Detail Karya'),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: ElevatedButton.icon(
                // TODO: arahkan ke halaman toko (route "/toko") begitu ada
                // callback terpisah dari layar ini -- sementara sama seperti
                // "Detail Karya".
                onPressed: () => onKaryaTap?.call(karya),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Kunjungi Toko'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: AppSpacing.xs),
        // Wrap (bukan Row) -- supaya kalau tidak muat 1 baris (layar sempit,
        // font besar), otomatis lipat ke baris ke-2, BUKAN overflow/kepotong.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 4,
          children: [
            _trustItem(Icons.verified_outlined, 'Provenansi Sah'),
            _trustItem(Icons.workspace_premium_outlined, 'Sertifikat Kurator'),
            _trustItem(Icons.local_shipping_outlined, 'Pengiriman Khusus'),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Karya Belum Terdaftar (ambiguous / not_found)
  // ---------------------------------------------------------------------

  Widget _buildNotFound(
    BuildContext context,
    String? detectedStyle,
    List<VisualSearchMatch> styleMatches,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // "ambiguous" -> karya KEMUNGKINAN ada di katalog (cuma
                  // belum cukup yakin) -- beda dari "not_found" yang memang
                  // sepertinya tidak ada. Jangan pakai kalimat yang sama,
                  // supaya tidak menyesatkan (karya ambiguous seharusnya
                  // TIDAK terkesan pasti "belum terdaftar").
                  _pillBadge(
                    icon: result.isAmbiguous
                        ? Icons.help_outline
                        : Icons.info_outline,
                    label: result.isAmbiguous
                        ? 'Kemiripan Terdeteksi di GALERIA'
                        : 'Karya Belum Terdaftar di GALERIA',
                    bg: AppColors.accentSoft.withValues(alpha: 0.3),
                    fg: AppColors.accent,
                    dotted: true,
                  ),
                  if (detectedStyle != null)
                    _pillBadge(
                      icon: Icons.auto_awesome,
                      label: 'Aliran: $detectedStyle',
                      bg: AppColors.surfaceContainerHigh,
                      fg: AppColors.onSurfaceVariant,
                      small: true,
                    ),
                ],
              ),
            ),
            _closeButton(),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Foto yang BARU DIPINDAI user (bukan gambar katalog) -- lihat
        // catatan _VisualSearchCameraScreenState._scan(). Judul di sini
        // SENGAJA generik ("Karya Bergaya X"), BUKAN nama karya spesifik --
        // kita tidak tahu judul asli lukisan yang belum terdaftar, jangan
        // "karang" nama supaya tidak overclaim.
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: scannedPhoto != null
                        ? Image.file(
                            scannedPhoto!,
                            width: 56,
                            height: 64,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 56,
                            height: 64,
                            color: AppColors.surfaceContainerHigh,
                          ),
                  ),
                  Positioned(
                    bottom: 2,
                    left: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'DIPINDAI',
                        style: AppTextStyles.overline.copyWith(
                          fontSize: 6.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KOLEKSI TERDETEKSI',
                      style: AppTextStyles.overline.copyWith(
                        fontSize: 8,
                        color: AppColors.outline,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detectedStyle == null
                          ? 'Karya yang Dipindai'
                          : 'Karya Bergaya $detectedStyle',
                      style: AppTextStyles.headlineSm.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.verdictMessage,
                      style: AppTextStyles.bodySm.copyWith(
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Rekomendasi Karakter Serupa', style: AppTextStyles.headlineSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '${styleMatches.length} KARYA TERSEDIA',
                style: AppTextStyles.overline.copyWith(
                  fontSize: 8.5,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          detectedStyle == null
              ? 'Kurasi karya lain di katalog GALERIA.'
              : 'Kurasi karya lain beraliran $detectedStyle di katalog GALERIA.',
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.muted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final m in styleMatches.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () => onKaryaTap?.call(m.karya),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Image.asset(
                            m.karya.assetPath,
                            width: 72,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successContainer.withValues(
                                alpha: 0.9,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                            child: Text(
                              'TERSEDIA',
                              style: AppTextStyles.overline.copyWith(
                                fontSize: 6.5,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.karya.title,
                            style: AppTextStyles.headlineSm.copyWith(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${m.karya.artistName} · ${m.karya.galleryName}',
                            style: AppTextStyles.bodySm.copyWith(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                m.karya.priceFormatted,
                                style: AppTextStyles.labelMd.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Lihat',
                                      style: AppTextStyles.labelSm.copyWith(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.arrow_forward,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (styleMatches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              'Belum ada karya bergaya serupa di katalog GALERIA saat ini.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          onPressed: onClose,
          icon: const Icon(Icons.auto_awesome_motion, size: 16),
          label: const Text('Jelajahi Lukisan Serupa Lainnya'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Helper kecil
  // ---------------------------------------------------------------------

  Widget _closeButton() => IconButton(
    onPressed: onClose,
    style: IconButton.styleFrom(
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const CircleBorder(),
    ),
    icon: const Icon(Icons.close, size: 18),
  );

  Widget _pillBadge({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    bool dotted = false,
    bool small = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotted) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
            ),
            const SizedBox(width: 5),
          ],
          Icon(icon, size: small ? 11 : 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.overline.copyWith(
              fontSize: small ? 8 : 9.5,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trustItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.accent),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTextStyles.labelSm.copyWith(
            fontSize: 9.5,
            color: AppColors.outline,
          ),
        ),
      ],
    );
  }
}
