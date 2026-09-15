import 'package:flutter/material.dart';

import '../../models/karya.dart';
import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_2/.../galeria_unggah_karya_detail_karya_langkah_2_dari_2/code.html
///
/// Field "Panjang (cm)" & "Lebar (cm)" di sini PENTING -- itu metadata
/// ukuran fisik yang dipakai fitur AR Simulation nanti (lihat CLAUDE.md,
/// bukan hasil model, input manual seniman saat upload).
///
/// TODO(backend): wire ke endpoint upload karya + image picker asli, dan ke
/// alur Digital Art Identity (verifikasi keaslian) setelah submit.
class UnggahKaryaScreen extends StatefulWidget {
  const UnggahKaryaScreen({super.key, required this.onBack, required this.onSubmitted});

  final VoidCallback onBack;
  final VoidCallback onSubmitted;

  @override
  State<UnggahKaryaScreen> createState() => _UnggahKaryaScreenState();
}

class _UnggahKaryaScreenState extends State<UnggahKaryaScreen> {
  String _media = 'Cat Minyak pada Kanvas';
  String _genre = 'Klasik Realisme (Renaissance Revival)';
  bool _originalChecked = true;
  bool _termsChecked = true;
  bool _submitting = false;

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
                Text('3 dari 5 Foto',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 130,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _photoThumb(sampleKarya[3].assetPath, label: 'UTAMA'),
                  const SizedBox(width: AppSpacing.sm),
                  _photoThumb(sampleKarya[3].assetPath, deletable: true),
                  const SizedBox(width: AppSpacing.sm),
                  _photoThumb(sampleKarya[3].assetPath, deletable: true),
                  const SizedBox(width: AppSpacing.sm),
                  _addPhotoBtn(),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _label('Judul Karya', required: true, hint: 'Sesuai dokumen keaslian'),
            _textField(initial: 'Sang Putri Mahkota Renaisans'),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Panjang (cm)', required: true),
                      _textField(initial: '120', suffix: 'cm'),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Lebar (cm)', required: true),
                      _textField(initial: '90', suffix: 'cm'),
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
                        controller: TextEditingController(text: '120.000.000'),
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
              onPressed: (_originalChecked && _termsChecked && !_submitting)
                  ? () async {
                      setState(() => _submitting = true);
                      await Future.delayed(const Duration(milliseconds: 900));
                      if (context.mounted) widget.onSubmitted();
                    }
                  : null,
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

  Widget _photoThumb(String asset, {String? label, bool deletable = false}) => Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.asset(asset, width: 110, height: 130, fit: BoxFit.cover),
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
              child: Icon(deletable ? Icons.delete_outline : Icons.edit_outlined, size: 14),
            ),
          ),
        ],
      );

  Widget _addPhotoBtn() => Container(
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
            Text('+ Tambah Foto',
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

  Widget _textField({String? initial, String? suffix}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: TextField(
          controller: initial != null ? TextEditingController(text: initial) : null,
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
