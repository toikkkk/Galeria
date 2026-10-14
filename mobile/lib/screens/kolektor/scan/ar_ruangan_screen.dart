
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/karya.dart';
import '../../../services/api_client.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kolektor/ar_artwork_view.dart';
import 'ar_simulasi_manual.dart';

/// "Coba di Ruangan": menempelkan lukisan pada DINDING sungguhan lewat ARCore
/// (deteksi bidang vertikal), dengan ukuran fisik asli karya (cm).
///
/// Bila HP tidak mendukung ARCore / izin kamera ditolak, jatuh ke
/// [ArSimulasiManual] (geser-cubit manual, tanpa klaim skala).
///
/// Kejujuran: ARCore memperkirakan skala dunia dari kamera + sensor (akurasi umumnya
/// beberapa persen, bukan alat ukur); dinding polos tanpa tekstur sulit terdeteksi.
/// Bila ukuran karya belum diisi seniman, dipakai ukuran perkiraan dan dilabeli begitu.
class ArRuanganScreen extends StatefulWidget {
  const ArRuanganScreen({super.key, required this.onClose, this.karya});

  final VoidCallback onClose;
  final Karya? karya;

  @override
  State<ArRuanganScreen> createState() => _ArRuanganScreenState();
}

enum _Mode { memuat, ar, simulasi, gambarGagal }

class _ArRuanganScreenState extends State<ArRuanganScreen> {
  static const _lebarDefaultCm = 60.0;
  static const _tinggiDefaultCm = 80.0;

  _Mode _mode = _Mode.memuat;
  Uint8List? _image;
  String _status = 'mencari';
  ArArtworkController? _controller;
  bool _memotret = false;

  Karya get _karya => widget.karya ?? sampleKarya[3];
  bool get _ukuranPerkiraan => _karya.lebarCm == null || _karya.tinggiCm == null;
  double get _lebarCm => _karya.lebarCm ?? _lebarDefaultCm;
  double get _tinggiCm => _karya.tinggiCm ?? _tinggiDefaultCm;

  @override
  void initState() {
    super.initState();
    _siapkan();
  }

  Future<void> _siapkan() async {
    if (_mode != _Mode.memuat) setState(() => _mode = _Mode.memuat);
    final izin = await Permission.camera.request();
    final dukungan = izin.isGranted ? await cekDukunganAr() : 'unsupported';
    Uint8List? bytes;
    if (dukungan == 'supported') {
      bytes = await _muatGambar();
    }
    if (!mounted) return;
    setState(() {
      _image = bytes;
      _mode = dukungan != 'supported'
          ? _Mode.simulasi
          : (bytes != null ? _Mode.ar : _Mode.gambarGagal);
    });
  }

  Future<Uint8List?> _muatGambar() async {
    try {
      final url = _karya.imageUrl;
      if (url != null) {
        // sama dgn KaryaImage: image_url relatif (`/uploads/...`) diprefix alamat backend
        final resolved = url.startsWith('http') ? url : '$kApiBaseUrl$url';
        final r = await http.get(Uri.parse(resolved)).timeout(const Duration(seconds: 20));
        if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) return r.bodyBytes;
        debugPrint('AR: gambar $resolved -> HTTP ${r.statusCode}');
      }
      final data = await rootBundle.load(_karya.assetPath);
      return data.buffer.asUint8List();
    } catch (_) {
      try {
        final data = await rootBundle.load(_karya.assetPath);
        return data.buffer.asUint8List();
      } catch (_) {
        return null;
      }
    }
  }

  void _onStatus(String s) {
    if (!mounted) return;
    if (s == 'tidak_didukung' || s == 'izin') {
      setState(() => _mode = _Mode.simulasi);
      return;
    }
    setState(() => _status = s);
  }

  String get _petunjuk => switch (_status) {
    'dinding' => 'Dinding terdeteksi (area biru). Ketuk untuk menempelkan karya.',
    'siap_instan' =>
      'Pelacakan siap. Ketuk layar untuk menempel (tanpa deteksi dinding), atau cari dinding bertekstur.',
    'terpasang' => 'Terpasang di dinding. Ketuk titik lain untuk memindahkan; mundur untuk melihat utuh.',
    'terpasang_instan' =>
      'Terpasang (perkiraan jarak). Ketuk titik lain untuk memindahkan; gerakkan HP agar jarak makin akurat.',
    'tak_kena' => 'Belum bisa menempel di titik itu. Gerakkan HP pelan-pelan lalu ketuk lagi.',
    'kurang_fitur' => 'Permukaan terlalu polos. Arahkan ke area bertekstur (poster, tepi pintu, rak).',
    'terlalu_cepat' => 'Gerakan terlalu cepat. Gerakkan HP lebih pelan.',
    'kurang_cahaya' => 'Terlalu gelap. Cari tempat yang lebih terang.',
    'kamera_gagal' => 'Kamera tidak bisa dibuka. Tutup aplikasi kamera lain lalu coba lagi.',
    _ => 'Menginisialisasi pelacakan. Gerakkan HP pelan ke kiri-kanan sambil menghadap dinding.',
  };

  Future<void> _ambilFoto() async {
    final c = _controller;
    if (c == null || _memotret) return;
    setState(() => _memotret = true);
    try {
      final path = await c.ambilFoto();
      if (path != null) {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(path)], text: '${_karya.title} di ruanganku — GALERIA'),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto gagal diambil. Coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _memotret = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_mode) {
      case _Mode.memuat:
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      case _Mode.simulasi:
        return ArSimulasiManual(onClose: widget.onClose, karya: widget.karya);
      case _Mode.gambarGagal:
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenGutter),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 48),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Gambar karya tidak bisa dimuat.\nPeriksa koneksi ke server lalu coba lagi.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySm.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(onPressed: _siapkan, child: const Text('Coba lagi')),
                    TextButton(
                      onPressed: widget.onClose,
                      child: const Text('Kembali', style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case _Mode.ar:
        break;
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: ArArtworkView(
              image: _image!,
              lebarCm: _lebarCm,
              tinggiCm: _tinggiCm,
              onStatus: _onStatus,
              onCreated: (c) => _controller = c,
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
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                        ),
                      ),
                      _pill(
                        Text(
                          'COBA DI RUANGAN (AR)',
                          style: AppTextStyles.overline.copyWith(color: Colors.white, fontSize: 9),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: _pill(
                    Text(
                      _petunjuk,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySm.copyWith(color: Colors.white, fontSize: 12),
                    ),
                    maxWidth: 320,
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.straighten, size: 14, color: AppColors.accent),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${_fmt(_lebarCm)} × ${_fmt(_tinggiCm)} cm'
                              '${_ukuranPerkiraan ? '  (ukuran perkiraan)' : ''}',
                              style: AppTextStyles.labelSm.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _tool(Icons.restart_alt, 'Lepas', onTap: () => _controller?.reset()),
                          _tool(
                            _memotret ? Icons.hourglass_top : Icons.photo_camera,
                            'Ambil Foto',
                            primary: true,
                            onTap: _ambilFoto,
                          ),
                          _tool(Icons.close, 'Tutup', onTap: widget.onClose),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Widget _pill(Widget child, {double? maxWidth}) => Container(
    constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: child,
  );

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
            color: primary ? Colors.white : Colors.white.withValues(alpha: 0.15),
          ),
          child: Icon(icon, color: primary ? Colors.black : Colors.white, size: primary ? 24 : 18),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.labelSm.copyWith(color: Colors.white70, fontSize: 10)),
      ],
    ),
  );
}
