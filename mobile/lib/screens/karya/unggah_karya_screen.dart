import '../../state/upload_preview.dart';
import '../../models/picked_image.dart';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/digital_art_identity_service.dart';
import '../../services/katalog_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/coming_soon.dart';

/// Konversi dari
/// docs/design/role_seniman_2/.../galeria_unggah_karya_detail_karya_langkah_2_dari_2/code.html
///
/// Field "Panjang (cm)" & "Lebar (cm)" di sini PENTING -- itu metadata
/// ukuran fisik yang dipakai fitur AR Simulation nanti (lihat CLAUDE.md,
/// bukan hasil model, input manual seniman saat upload).
///
/// URUTAN (diubah 2026-11): LANGKAH 1 pilih foto -> sistem memeriksa duplikat (Art-to-Art) dan
/// perkiraan buatan AI (Art-to-AI) lewat `POST /api/verification/check` (pratinjau, tidak disimpan);
/// LANGKAH 2 judul, ukuran, harga, dst baru muncul bila foto LOLOS. Foto yang ditolak / perlu ditinjau
/// tidak bisa dilanjutkan; mengganti foto mengulang pemeriksaan.
///
/// Submit sekarang BENAR-BENAR membuat baris `karya` di database
/// (`POST /api/karya`, lihat [KatalogService.createKarya]), baru lanjut ke
/// [MemverifikasiKeaslianScreen] utk verifikasi RESMI
/// (`POST /api/karya/{id}/verify`) -- bukan lagi mode pratinjau.
///
/// Pemilik karya & nama seniman diambil server dari akun yang login (bukan dari form). Field
/// media, tahun, cerita, dan harga lelang masih UI-only, belum dikirim ke backend (skema `karya`
/// belum punya kolom-kolom itu).
/// Status pemeriksaan foto (langkah 1). Hanya [lolos] membuka form detail.
enum _Cek { belum, memeriksa, lolos, ditolak, perluDitinjau, gagal }

class UnggahKaryaScreen extends StatefulWidget {
  const UnggahKaryaScreen({
    super.key,
    required this.onBack,
    required this.onSubmitted,
    this.pilihFoto,
    this.periksaKeaslian,
  });

  /// Pengganti pemilih galeri (untuk tes). Null = `ImagePicker` bawaan.
  final Future<PickedImage?> Function()? pilihFoto;

  /// Pengganti pemeriksaan ke backend (untuk tes). Null = `POST /api/verification/check`.
  final Future<VerificationResult> Function(PickedImage)? periksaKeaslian;

  final VoidCallback onBack;

  /// Dipanggil setelah karya berhasil dibuat di database -- membawa file
  /// foto asli + `karya_id` baru, supaya layar verifikasi berikutnya
  /// memanggil endpoint verifikasi RESMI (bukan pratinjau).
  final ValueChanged<({PickedImage image, String karyaId})> onSubmitted;

  @override
  State<UnggahKaryaScreen> createState() => _UnggahKaryaScreenState();
}

class _UnggahKaryaScreenState extends State<UnggahKaryaScreen> {
  String _media = 'Cat Minyak pada Kanvas';
  String _genre = 'Klasik Realisme (Renaissance Revival)';
  bool _originalChecked = true;
  bool _termsChecked = true;
  bool _submitting = false;
  PickedImage? _mainPhoto;

  _Cek _cek = _Cek.belum;
  VerificationResult? _hasil;
  String? _cekError;

  final _titleCtrl = TextEditingController();
  // UI pakai label "Panjang"/"Lebar" (desain Stitch asli), skema backend
  // `karya.tinggi_cm`/`karya.lebar_cm` (lihat CLAUDE.md) -- dipetakan
  // "Panjang" -> tinggi_cm, "Lebar" -> lebar_cm, lihat pemanggilan
  // createKarya() di _submit().
  final _panjangCtrl = TextEditingController();
  final _lebarCtrl = TextEditingController();
  final _hargaCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _panjangCtrl.dispose();
    _lebarCtrl.dispose();
    _hargaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_mainPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih foto utama karya terlebih dahulu.')),
      );
      return;
    }
    final panjang = double.tryParse(_panjangCtrl.text.trim());
    final lebar = double.tryParse(_lebarCtrl.text.trim());
    // Harga ditampilkan dgn pemisah ribuan ("120.000.000") -- buang titiknya
    // sebelum di-parse ke integer murni (format yg dikirim backend).
    final harga = int.tryParse(_hargaCtrl.text.replaceAll('.', '').trim());
    if (_titleCtrl.text.trim().isEmpty || panjang == null || lebar == null || harga == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul, ukuran, dan harga harus diisi dengan angka yang valid.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final karyaId = await KatalogService().createKarya(
        image: _mainPhoto!,
        title: _titleCtrl.text.trim(),
        styleName: _genre,
        priceIdr: harga,
        // "Panjang" (UI) -> tinggi_cm, "Lebar" (UI) -> lebar_cm (lihat
        // komentar di deklarasi controller).
        tinggiCm: panjang,
        lebarCm: lebar,
      );
      if (!mounted) return;
      UploadPreview.last = UploadPreview(
        image: _mainPhoto!,
        title: _titleCtrl.text.trim(),
        artist: AuthService.instance.user?.displayName ?? '',
        style: _genre,
      );
      widget.onSubmitted((image: _mainPhoto!, karyaId: karyaId));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat karya: $e')),
      );
    }
  }

  Future<void> _pickMainPhoto() async {
    if (_cek == _Cek.memeriksa) return;
    try {
      final PickedImage? foto;
      if (widget.pilihFoto != null) {
        foto = await widget.pilihFoto!();
      } else {
        final XFile? picked = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (picked == null) return;
        foto = PickedImage(bytes: await picked.readAsBytes(), name: picked.name);
      }
      if (foto == null || !mounted) return;
      setState(() => _mainPhoto = foto);
      await _periksa();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka galeri: $e')),
      );
    }
  }

  /// LANGKAH 1: periksa foto SEBELUM form detail dibuka. Hasilnya hanya pratinjau (tidak disimpan);
  /// pemeriksaan RESMI yang menerbitkan sertifikat tetap berjalan setelah karya dibuat.
  Future<void> _periksa() async {
    final foto = _mainPhoto;
    if (foto == null) return;
    setState(() {
      _cek = _Cek.memeriksa;
      _hasil = null;
      _cekError = null;
    });
    try {
      final hasil = await (widget.periksaKeaslian ?? DigitalArtIdentityService().checkImageBytes)(foto);
      if (!mounted || !identical(_mainPhoto, foto)) return; // foto sudah diganti saat menunggu
      setState(() {
        _hasil = hasil;
        _cek = hasil.isTerverifikasi
            ? _Cek.lolos
            : hasil.isDitolak
                ? _Cek.ditolak
                : _Cek.perluDitinjau;
      });
    } catch (e) {
      if (!mounted || !identical(_mainPhoto, foto)) return;
      setState(() {
        _cek = _Cek.gagal;
        _cekError = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Unggah Karya', style: AppTextStyles.headlineSm),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: _cek == _Cek.lolos ? 1 : 0.5,
                minHeight: 4,
                backgroundColor: AppColors.surfaceContainer,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFECC246)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(_cek == _Cek.lolos ? 'Langkah 2 dari 2' : 'Langkah 1 dari 2',
                style: AppTextStyles.overline.copyWith(fontSize: 10.5)),
            const SizedBox(height: 2),
            Text(_cek == _Cek.lolos ? 'Detail Karya' : 'Periksa Keaslian Foto',
                style: AppTextStyles.headlineLg.copyWith(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              _cek == _Cek.lolos
                  ? 'Foto lolos pemeriksaan. Lengkapi data karya untuk mendaftarkannya.'
                  : 'Pilih foto karya dulu. Sebelum mengisi judul dan detail lain, sistem memeriksa apakah ada duplikat di GALERIA dan apakah karya ini kemungkinan buatan AI.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('DOKUMENTASI KARYA',
                    style: AppTextStyles.overline.copyWith(fontSize: 10.5)),
                Text(_mainPhoto == null ? 'Belum ada foto' : '1 foto dipilih',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Foto UTAMA ini yang akan benar-benar diperiksa sistem Art-to-Art & Art-to-AI.',
              style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 130,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  GestureDetector(
                    onTap: _pickMainPhoto,
                    child: _mainPhoto == null
                        ? _addPhotoBtn(label: '+ Pilih Foto Utama')
                        : _photoThumbFile(_mainPhoto!, label: 'UTAMA'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Backend saat ini HANYA terima 1 foto per karya (lihat
                  // POST /api/karya) -- tombol ini kasih feedback jujur,
                  // bukan menampilkan foto palsu kedua yang tidak pernah
                  // benar-benar terkirim. Lihat audit navigasi role
                  // Seniman, 2026-10.
                  GestureDetector(
                    onTap: () => showComingSoon(context, 'Unggah multi-foto'),
                    child: _addPhotoBtn(),
                  ),
                ],
              ),
            ),
            _cekPanel(),
            if (_cek == _Cek.lolos) ..._formFields(),
          ],
        ),
      ),
    );
  }

  Widget _cekPanel() {
    if (_cek == _Cek.belum) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kolom judul, ukuran, dan harga baru terbuka setelah foto lolos pemeriksaan.',
                  key: const Key('cek_info_awal'),
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final h = _hasil;
    final memeriksa = _cek == _Cek.memeriksa;
    final dupOk = h == null ? null : h.artToArtResult == 'lolos';
    final aiOk = h == null ? null : h.aiDetectionResult == 'lolos';
    final aiPersen = h == null ? 0 : (h.aiGeneratedProbability * 100).round();
    final mirip = (h != null && h.duplicateMatches.isNotEmpty) ? h.duplicateMatches.first : null;

    String? pesan;
    Color pesanWarna = AppColors.error;
    if (_cek == _Cek.ditolak) {
      pesan = 'Foto ini sangat mirip dengan karya yang sudah terdaftar di GALERIA, jadi tidak bisa dilanjutkan. Unggah karya milikmu sendiri.';
    } else if (_cek == _Cek.perluDitinjau) {
      final kandidat = <String>[
        if (dupOk == false) 'agak mirip dengan karya lain',
        if (aiOk == false) 'diperkirakan kemungkinan dibuat oleh AI',
      ].join(' dan ');
      pesan = 'Foto ini $kandidat, jadi belum bisa dilanjutkan. Hasil ini perkiraan model, bukan kepastian. Peninjauan manual belum tersedia; coba foto lain.';
    } else if (_cek == _Cek.gagal) {
      pesan = 'Pemeriksaan gagal: $_cekError';
    } else if (_cek == _Cek.lolos) {
      pesan = 'Lolos pemeriksaan. Lengkapi detail karya di bawah ini.';
      pesanWarna = const Color(0xFF2F7A2B);
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        key: const Key('panel_cek'),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HASIL PEMERIKSAAN', style: AppTextStyles.overline.copyWith(fontSize: 10.5)),
            const SizedBox(height: AppSpacing.xs),
            _barisCek(
              judul: 'Duplikat dengan karya lain',
              sub: memeriksa
                  ? 'Memeriksa kemiripan dengan katalog...'
                  : dupOk == null
                      ? '-'
                      : dupOk
                          ? 'Tidak ada karya yang terlalu mirip di GALERIA.'
                          : (mirip != null
                              ? 'Mirip dengan "${mirip.title}" oleh ${mirip.artistName}.'
                              : 'Terdeteksi kemiripan dengan karya lain.'),
              ok: dupOk,
              memeriksa: memeriksa,
            ),
            const SizedBox(height: AppSpacing.xs),
            _barisCek(
              judul: 'Kemungkinan dibuat oleh AI',
              sub: memeriksa
                  ? 'Memeriksa pola karya buatan AI...'
                  : aiOk == null
                      ? '-'
                      : aiOk
                          ? 'Tidak terdeteksi. Ini perkiraan model, bukan kepastian.'
                          : 'Terdeteksi kemungkinan buatan AI (perkiraan $aiPersen%).',
              ok: aiOk,
              memeriksa: memeriksa,
            ),
            if (pesan != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(pesan, key: const Key('pesan_cek'), style: AppTextStyles.bodySm.copyWith(color: pesanWarna, fontWeight: FontWeight.w600)),
            ],
            if (_cek == _Cek.ditolak || _cek == _Cek.perluDitinjau || _cek == _Cek.gagal) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('pilih_foto_lain'),
                    onPressed: _pickMainPhoto,
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: const Text('Pilih Foto Lain'),
                  ),
                  if (_cek == _Cek.gagal)
                    OutlinedButton.icon(
                      key: const Key('coba_lagi_cek'),
                      onPressed: _periksa,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Coba Lagi'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _barisCek({required String judul, required String sub, required bool? ok, required bool memeriksa}) {
    final Widget ikon = memeriksa
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
        : ok == null
            ? const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.muted)
            : ok
                ? const Icon(Icons.check_circle, size: 20, color: Color(0xFF2F7A2B))
                : const Icon(Icons.cancel, size: 20, color: AppColors.error);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: ikon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(judul, style: AppTextStyles.labelMd.copyWith(fontSize: 13)),
              Text(sub, style: AppTextStyles.bodySm.copyWith(fontSize: 11.5, color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }

  /// LANGKAH 2: hanya dibangun setelah foto lolos pemeriksaan.
  List<Widget> _formFields() => [
            const SizedBox(height: AppSpacing.lg),
            _label('Judul Karya', required: true, hint: 'Sesuai dokumen keaslian'),
            _textField(controller: _titleCtrl),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Panjang (cm)', required: true),
                      _textField(controller: _panjangCtrl, suffix: 'cm'),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Lebar (cm)', required: true),
                      _textField(controller: _lebarCtrl, suffix: 'cm'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Media / Cat', required: true),
                      _dropdown(_media, const [
                        'Cat Minyak pada Kanvas',
                        'Cat Akrilik pada Kanvas',
                        'Mixed Media',
                        'Cat Air',
                      ], (v) => setState(() => _media = v!)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Tahun Selesai', required: true),
                      _textField(initial: '2024'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _label('Aliran Seni / Genre', required: true),
            _dropdown(_genre, const [
              'Klasik Realisme (Renaissance Revival)',
              'Kontemporer Figuratif',
              'Impresionisme',
              'Abstrak Ekspresionisme',
            ], (v) => setState(() => _genre = v!)),
            const SizedBox(height: AppSpacing.md),
            _label('Cerita & Konsep Karya', required: true),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: TextField(
                maxLines: 4,
                style: AppTextStyles.bodySm,
                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                controller: TextEditingController(
                  text:
                      "Karya 'Sang Putri Mahkota Renaisans' merekonstruksi keanggunan abad ke-16 dengan pendekatan kontemporer. Gaun beludru burgundi beraksen benang emas mencerminkan keteguhan karakter, sementara tatapan tenang subjek mengundang penikmat merenungkan relasi kekuasaan, keanggunan, dan spiritualitas abadi.",
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text('299 / 1.000 karakter',
                  style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted)),
            ),
            const SizedBox(height: AppSpacing.md),
            _label('Harga Pembukaan Lelang (Reserve Price)', required: true),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: AppColors.border)),
                    ),
                    child: Text('IDR',
                        style: AppTextStyles.labelSm.copyWith(color: AppColors.muted)),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: TextField(
                        controller: _hargaCtrl,
                        style: AppTextStyles.labelMd.copyWith(fontSize: 15),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: AppSpacing.sm),
                    child: Icon(Icons.payments_outlined, size: 20, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Estimasi komisi balai lelang 10% dipotong secara transparan setelah palu diketuk.',
                    style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Text('Integritas & Legalitas Balai Lelang',
                          style: AppTextStyles.labelMd.copyWith(fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CheckboxListTile(
                    value: _originalChecked,
                    onChanged: (v) => setState(() => _originalChecked = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: AppColors.primary,
                    title: Text('Saya menyatakan karya ini asli buatan saya sendiri',
                        style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        'Siap dipasangi sertifikat digital kriptografis GALERIA Provenance ID.',
                        style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
                  ),
                  const Divider(height: 1),
                  CheckboxListTile(
                    value: _termsChecked,
                    onChanged: (v) => setState(() => _termsChecked = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: AppColors.primary,
                    title: Text('Saya menyetujui Syarat Kurasi & Penjualan Lelang GALERIA',
                        style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('Termasuk klausul inspeksi fisik sebelum pengiriman ke kolektor.',
                        style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: (_originalChecked && _termsChecked && !_submitting) ? _submit : null,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('Verifikasi & Daftarkan Karya'),
                        SizedBox(width: AppSpacing.xs),
                        Icon(Icons.arrow_forward, size: 16, color: AppColors.accent),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 14, color: AppColors.muted),
                const SizedBox(width: 6),
                Text('ENKRIPSI PROVENANSI BALAI LELANG GALERIA',
                    style: AppTextStyles.overline.copyWith(fontSize: 9)),
              ],
            ),
      ];

  Widget _photoThumbFile(PickedImage file, {String? label}) => Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.memory(file.bytes, width: 110, height: 130, fit: BoxFit.cover),
          ),
          if (label != null)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ),
          Positioned(
            bottom: 8,
            right: 8,
            child: CircleAvatar(
              radius: 13,
              backgroundColor: Colors.white.withValues(alpha: 0.9),
              child: const Icon(Icons.edit_outlined, size: 14),
            ),
          ),
        ],
      );

  Widget _addPhotoBtn({String label = '+ Tambah Foto'}) => Container(
        width: 110,
        height: 130,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.surfaceContainerHigh,
              child: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: AppTextStyles.labelSm.copyWith(fontSize: 11), textAlign: TextAlign.center),
            Text('(Maks. 5 Foto)',
                style: AppTextStyles.bodySm.copyWith(fontSize: 9, color: AppColors.muted)),
          ],
        ),
      );

  Widget _label(String text, {bool required = false, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text.rich(
              TextSpan(style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurface, fontSize: 12), children: [
                TextSpan(text: text),
                if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.accent)),
              ]),
            ),
            if (hint != null)
              Text(hint, style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      );

  Widget _textField({String? initial, String? suffix, TextEditingController? controller}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: TextField(
          controller: controller ?? (initial != null ? TextEditingController(text: initial) : null),
          style: AppTextStyles.bodyMd,
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            suffixText: suffix,
            suffixStyle: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
          ),
        ),
      );

  Widget _dropdown(String value, List<String> options, ValueChanged<String?> onChanged) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            style: AppTextStyles.bodyMd,
            items: options
                .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      );
}
