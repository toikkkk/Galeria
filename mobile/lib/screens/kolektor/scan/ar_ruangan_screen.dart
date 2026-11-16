import 'dart:math' as math;

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
  bool _kunci = true;
  bool _tampilUkuran = true;
  double? _jarak;

  bool get _terpasang => _status.startsWith('terpasang');

  // Bingkai (kayu + list + passe-partout) menambah 5,6 cm di tiap sisi lukisan; nilai sama dgn renderer native.
  static const _bingkaiCm = 5.6;

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
        final r = await http.get(Uri.parse(resolved), headers: headerTunnel(resolved)).timeout(const Duration(seconds: 20));
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
    'terpasang' => _kunci
        ? 'Terpasang di dinding dan terkunci. Mundur untuk melihat utuh, atau buka kunci untuk memindahkan.'
        : 'Terpasang di dinding. Ketuk titik lain untuk memindahkan.',
    'terpasang_instan' => _kunci
        ? 'Terpasang dan terkunci. Gerakkan HP pelan-pelan agar jarak makin akurat.'
        : 'Terpasang (jarak masih perkiraan). Ketuk titik lain untuk memindahkan.',
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
              onJarak: (d) {
                if (mounted) setState(() => _jarak = d);
              },
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
                _panelBawah(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1).replaceAll('.', ',');

  void _toggleKunci() {
    setState(() => _kunci = !_kunci);
    _controller?.setKunci(_kunci);
  }

  void _toggleUkuran() {
    setState(() => _tampilUkuran = !_tampilUkuran);
    _controller?.setUkuran(_tampilUkuran);
  }

  /// Panel bawah: identitas karya, rincian ukuran fisik (tanpa bingkai), jarak langsung, pengaturan, dan aksi.
  Widget _panelBawah() {
    final luas = _lebarCm * _tinggiCm / 10000; // m²
    final diagonal = math.sqrt(_lebarCm * _lebarCm + _tinggiCm * _tinggiCm);
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter, AppSpacing.sm, AppSpacing.screenGutter, AppSpacing.md),
      decoration: const BoxDecoration(
        color: Color(0xEB2B1913),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_karya.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.headlineSm.copyWith(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(_karya.artistName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm.copyWith(color: Colors.white60, fontSize: 11.5)),
                  ],
                ),
              ),
              if (_terpasang)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kunci ? const Color(0xFFDBA12C) : Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_kunci ? Icons.lock : Icons.lock_open, size: 12, color: _kunci ? const Color(0xFF3E251E) : Colors.white),
                    const SizedBox(width: 4),
                    Text(_kunci ? 'Terkunci' : 'Bisa dipindah', style: AppTextStyles.labelSm.copyWith(fontSize: 10.5, fontWeight: FontWeight.w800, color: _kunci ? const Color(0xFF3E251E) : Colors.white)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _ukur('LEBAR', '${_fmt(_lebarCm)} cm', sorot: true),
              _ukur('TINGGI', '${_fmt(_tinggiCm)} cm', sorot: true),
              _ukur('DIAGONAL', '${_fmt(diagonal.roundToDouble())} cm'),
              _ukur('LUAS', '${luas.toStringAsFixed(2).replaceAll('.', ',')} m²'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.straighten, size: 13, color: Color(0xFFF0C86A)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _ukuranPerkiraan
                      ? 'Ukuran karya belum diisi seniman; memakai perkiraan. Bingkai menambah ±${_fmt(_bingkaiCm)} cm tiap sisi.'
                      : 'Ukuran lukisan tanpa bingkai. Bingkai menambah ±${_fmt(_bingkaiCm)} cm tiap sisi.',
                  style: AppTextStyles.bodySm.copyWith(color: Colors.white60, fontSize: 10.5),
                ),
              ),
              if (_terpasang && _jarak != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)),
                  child: Text('Jarak ±${_jarak!.toStringAsFixed(1).replaceAll('.', ',')} m', style: AppTextStyles.labelSm.copyWith(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _tool(Icons.restart_alt, 'Lepas', onTap: () {
                _controller?.reset();
                setState(() {
                  _jarak = null;
                  _status = 'mencari';
                });
              }),
              _tool(_kunci ? Icons.lock : Icons.lock_open, _kunci ? 'Buka kunci' : 'Kunci', onTap: _toggleKunci, aktif: _kunci),
              _tool(
                _memotret ? Icons.hourglass_top : Icons.photo_camera,
                'Ambil Foto',
                primary: true,
                onTap: _ambilFoto,
              ),
              _tool(Icons.straighten, _tampilUkuran ? 'Sembunyi ukuran' : 'Tampil ukuran', onTap: _toggleUkuran, aktif: _tampilUkuran),
              _tool(Icons.close, 'Tutup', onTap: widget.onClose),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ukur(String label, String nilai, {bool sorot = false}) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: sorot ? const Color(0x33DBA12C) : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sorot ? const Color(0x99DBA12C) : Colors.transparent),
      ),
      child: Column(
        children: [
          Text(label, style: AppTextStyles.overline.copyWith(color: Colors.white60, fontSize: 8.5)),
          const SizedBox(height: 2),
          Text(nilai, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.labelMd.copyWith(color: sorot ? const Color(0xFFF0C86A) : Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );

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
    bool aktif = false,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.full),
    child: SizedBox(
      width: 62,
      child: Column(
        children: [
          Container(
            width: primary ? 56 : 44,
            height: primary ? 56 : 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary ? const Color(0xFFDBA12C) : (aktif ? const Color(0x55DBA12C) : Colors.white.withValues(alpha: 0.15)),
              border: aktif && !primary ? Border.all(color: const Color(0xFFDBA12C), width: 1.5) : null,
            ),
            child: Icon(icon, color: primary ? const Color(0xFF3E251E) : (aktif ? const Color(0xFFF0C86A) : Colors.white), size: primary ? 26 : 19),
          ),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, maxLines: 2, style: AppTextStyles.labelSm.copyWith(color: Colors.white70, fontSize: 9.5, height: 1.15)),
        ],
      ),
    ),
  );
}
