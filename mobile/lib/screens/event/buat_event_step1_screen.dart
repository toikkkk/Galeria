import 'package:flutter/material.dart';

import '../../models/karya.dart';
import '../../theme/app_theme.dart';
import '../../utils/coming_soon.dart';
import '../../widgets/event_stepper.dart';

/// Konversi dari
/// docs/design/role_seniman_2/.../galeria_buat_event_langkah_1_dari_3/code.html
///
/// Semua isian di sini masih placeholder/demo (belum tersambung form state
/// atau backend) -- fokusnya menirukan tata letak & interaksi dasar dari
/// desain Stitch.
class BuatEventStep1Screen extends StatefulWidget {
  const BuatEventStep1Screen({super.key, required this.onClose, required this.onLanjut});

  final VoidCallback onClose;
  final VoidCallback onLanjut;

  @override
  State<BuatEventStep1Screen> createState() => _BuatEventStep1ScreenState();
}

class _BuatEventStep1ScreenState extends State<BuatEventStep1Screen> {
  final _selectedGenre = <String>{'Realis', 'Kemaritiman'};
  static const _genres = ['Realis', 'Abstrak', 'Kontemporer', 'Kemaritiman', 'Batik Klasik', 'Fotografi'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close)),
        title: Text('Buat Event', style: AppTextStyles.headlineSm),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.md),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium, size: 13, color: AppColors.accent),
                const SizedBox(width: 4),
                Text('PRO ARTIST', style: AppTextStyles.overline.copyWith(color: AppColors.accent)),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter, AppSpacing.sm, AppSpacing.screenGutter, AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EventStepper(currentStep: 1),
            const SizedBox(height: AppSpacing.lg),
            // Poster upload
            InkWell(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('TODO: pilih berkas poster'))),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                      child: const Icon(Icons.add_photo_alternate_outlined,
                          color: AppColors.accent, size: 28),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Unggah Poster Utama', style: AppTextStyles.headlineSm),
                    const SizedBox(height: 4),
                    Text('Format JPG, PNG, atau WebP dengan resolusi kurasi tinggi',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Informasi Kurasi
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.palette_outlined, size: 20, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text('Informasi Kurasi', style: AppTextStyles.headlineSm),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _label('Nama Event *'),
                  _textField('Tuliskan judul pameran...',
                      initial: 'Pameran Tunggal: Jejak Cahaya Nusantara'),
                  const SizedBox(height: AppSpacing.sm),
                  _label('Jenis Event *'),
                  _dropdownLike('Pameran Galeri Fisik'),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Tersedia sertifikasi katalog cetak resmi untuk tipe Galeri.',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _label('Deskripsi Konsep Kuratorial'),
                  _textField(
                    'Uraikan diskursus artistik...',
                    initial:
                        'Eksplorasi spektrum pigmen alami dan artikulasi siluet kemaritiman Nusantara.',
                    maxLines: 4,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _label('Aliran & Klasifikasi Tema'),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in _genres)
                        ChoiceChip(
                          label: Text(g),
                          selected: _selectedGenre.contains(g),
                          onSelected: (v) => setState(
                              () => v ? _selectedGenre.add(g) : _selectedGenre.remove(g)),
                          selectedColor: AppColors.primary,
                          labelStyle: AppTextStyles.labelMd.copyWith(
                            color: _selectedGenre.contains(g) ? Colors.white : AppColors.onSurface,
                          ),
                          backgroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.full)),
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Karya yang dipamerkan
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Karya yang Dipamerkan', style: AppTextStyles.headlineSm),
                          Text('3 karya terpilih dari galeri studio Anda',
                              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(AppRadius.sm)),
                        child: Text('TERKURASI',
                            style: AppTextStyles.overline.copyWith(color: AppColors.accent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 96,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final k in sampleKarya.take(3))
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                            child: SizedBox(
                              width: 80,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    child: Image.asset(k.assetPath,
                                        width: 80, height: 80, fit: BoxFit.cover),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(k.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodySm
                                          .copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        Column(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              onTap: () => showComingSoon(context, 'Tambah karya ke event'),
                              child: Container(
                                width: 80,
                                height: 80,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                child: const Icon(Icons.add, color: AppColors.accent),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text('Tambah', style: AppTextStyles.bodySm.copyWith(fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Penyelenggara
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary,
                    child: Text('SR', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PENYELENGGARA EVENT',
                            style: AppTextStyles.overline.copyWith(color: AppColors.muted)),
                        Row(children: [
                          Text('Sanggar Rupa Nusantara', style: AppTextStyles.labelMd),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: AppColors.accent),
                        ]),
                        Text('Identitas Terverifikasi · Kurator Terakreditasi',
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Draf disimpan (demo)'))),
                  icon: const Icon(Icons.bookmark_outline, size: 18),
                  label: const Text('Simpan Draf'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: widget.onLanjut,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('Lanjut ke Jadwal'),
                      SizedBox(width: AppSpacing.xs),
                      Icon(Icons.arrow_forward, size: 16, color: AppColors.accentSoft),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: AppTextStyles.labelMd),
      );

  Widget _textField(String hint, {String? initial, int maxLines = 1}) => TextField(
        controller: TextEditingController(text: initial),
        maxLines: maxLines,
        style: AppTextStyles.bodyMd,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        ),
      );

  Widget _dropdownLike(String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        decoration:
            BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value, style: AppTextStyles.bodyMd),
            const Icon(Icons.expand_more, size: 20, color: AppColors.muted),
          ],
        ),
      );
}
