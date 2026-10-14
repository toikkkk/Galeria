import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
/// Submit sekarang BENAR-BENAR membuat baris `karya` di database
/// (`POST /api/karya`, lihat [KatalogService.createKarya]), baru lanjut ke
/// [MemverifikasiKeaslianScreen] utk verifikasi RESMI
/// (`POST /api/karya/{id}/verify`) -- bukan lagi mode pratinjau.
///
/// CATATAN JUJUR (lihat backend/routers/karya_upload.py): "Seniman Demo"/
/// "Studio Pribadi Anda" di bawah adalah PLACEHOLDER pengganti identitas
/// user login -- Auth belum dibangun (lihat CLAUDE.md). Field lain (media,
/// tahun, cerita, harga lelang) masih UI-only, belum dikirim ke backend
/// (skema `karya` saat ini belum punya kolom-kolom itu).
class UnggahKaryaScreen extends StatefulWidget {
  const UnggahKaryaScreen({super.key, required this.onBack, required this.onSubmitted});

  final VoidCallback onBack;

  /// Dipanggil setelah karya berhasil dibuat di database -- membawa file
  /// foto asli + `karya_id` baru, supaya layar verifikasi berikutnya
  /// memanggil endpoint verifikasi RESMI (bukan pratinjau).
  final ValueChanged<({File image, String karyaId})> onSubmitted;

  @override
  State<UnggahKaryaScreen> createState() => _UnggahKaryaScreenState();
}

class _UnggahKaryaScreenState extends State<UnggahKaryaScreen> {
  String _media = 'Cat Minyak pada Kanvas';
  String _genre = 'Klasik Realisme (Renaissance Revival)';
  bool _originalChecked = true;
  bool _termsChecked = true;
  bool _submitting = false;
  File? _mainPhoto;

  final _titleCtrl = TextEditingController(text: 'Sang Putri Mahkota Renaisans');
  // UI pakai label "Panjang"/"Lebar" (desain Stitch asli), skema backend
  // `karya.tinggi_cm`/`karya.lebar_cm` (lihat CLAUDE.md) -- dipetakan
  // "Panjang" -> tinggi_cm, "Lebar" -> lebar_cm, lihat pemanggilan
  // createKarya() di _submit().
  final _panjangCtrl = TextEditingController(text: '120');
  final _lebarCtrl = TextEditingController(text: '90');
  final _hargaCtrl = TextEditingController(text: '120.000.000');

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
        // PLACEHOLDER -- lihat catatan jujur di docstring kelas ini (Auth
        // belum ada, belum tahu siapa seniman yang sedang login).
        artistName: 'Seniman GALERIA (Demo)',
        galleryName: 'Studio Pribadi Seniman',
        styleName: _genre,
        priceIdr: harga,
        // "Panjang" (UI) -> tinggi_cm, "Lebar" (UI) -> lebar_cm (lihat
        // komentar di deklarasi controller).
        tinggiCm: panjang,
        lebarCm: lebar,
      );
      if (!mounted) return;
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
    try {
      final XFile? picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      setState(() => _mainPhoto = File(picked.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka galeri: $e')),
      );
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
              child: const LinearProgressIndicator(
                value: 1,
                minHeight: 4,
                backgroundColor: AppColors.surfaceContainer,
                valueColor: AlwaysStoppedAnimation(Color(0xFFECC246)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Katalogisasi Detail Karya',
                style: AppTextStyles.headlineLg.copyWith(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              'Lengkapi data kurasi dan provenansi untuk proses verifikasi Balai Lelang GALERIA.',
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
          ],
        ),
      ),
    );
  }

  Widget _photoThumbFile(File file, {String? label}) => Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.file(file, width: 110, height: 130, fit: BoxFit.cover),
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
