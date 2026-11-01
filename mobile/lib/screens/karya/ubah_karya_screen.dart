import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/karya.dart';
import '../../services/katalog_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/karya_image.dart';

const _gayaPilihan = [
  'Klasik Realisme (Renaissance Revival)',
  'Kontemporer Figuratif',
  'Impresionisme',
  'Abstrak Ekspresionisme',
];

/// Ubah data karya milikmu (`PATCH /api/karya/{id}`): judul, harga, gaya, ukuran, galeri, deskripsi.
/// Gambar tidak bisa diganti di sini karena gambar adalah dasar sertifikat keaslian (ganti gambar = unggah karya baru).
/// Mengembalikan [Karya] yang sudah diperbarui lewat `Navigator.pop`, atau null bila dibatalkan.
class UbahKaryaScreen extends StatefulWidget {
  const UbahKaryaScreen({super.key, required this.karya, KatalogService? service}) : _service = service;

  final Karya karya;
  final KatalogService? _service;

  @override
  State<UbahKaryaScreen> createState() => _UbahKaryaScreenState();
}

class _UbahKaryaScreenState extends State<UbahKaryaScreen> {
  late final KatalogService _service = widget._service ?? KatalogService();
  final _form = GlobalKey<FormState>();
  late final _judul = TextEditingController(text: widget.karya.title);
  late final _harga = TextEditingController(text: widget.karya.priceIdr.toString());
  late final _lebar = TextEditingController(text: _cm(widget.karya.lebarCm));
  late final _tinggi = TextEditingController(text: _cm(widget.karya.tinggiCm));
  late final _galeri = TextEditingController(text: widget.karya.galleryName);
  late final _deskripsi = TextEditingController(text: widget.karya.deskripsi ?? '');
  late String _gaya = widget.karya.styleName;
  bool _kirim = false;
  String? _error;

  static String _cm(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

  @override
  void dispose() {
    for (final c in [_judul, _harga, _lebar, _tinggi, _galeri, _deskripsi]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _opsiGaya => {..._gayaPilihan, widget.karya.styleName}.toList();

  double? _angka(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  String? _wajib(String? v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null;

  String? _ukuran(String? v) {
    final n = _angka(v ?? '');
    return (n == null || n <= 0 || n > 1000) ? 'Isi 1–1000 cm' : null;
  }

  /// Hanya field yang benar-benar berubah (server menolak body kosong).
  Map<String, dynamic> _perubahan() {
    final k = widget.karya;
    final p = <String, dynamic>{};
    if (_judul.text.trim() != k.title) p['title'] = _judul.text.trim();
    final harga = int.tryParse(_harga.text.trim());
    if (harga != null && harga != k.priceIdr) p['price_idr'] = harga;
    if (_gaya != k.styleName) p['style_name'] = _gaya;
    if (_galeri.text.trim() != k.galleryName) p['gallery_name'] = _galeri.text.trim();
    final l = _angka(_lebar.text), t = _angka(_tinggi.text);
    if (l != null && l != k.lebarCm) p['lebar_cm'] = l;
    if (t != null && t != k.tinggiCm) p['tinggi_cm'] = t;
    if (_deskripsi.text.trim() != (k.deskripsi ?? '')) p['deskripsi'] = _deskripsi.text.trim();
    return p;
  }

  Future<void> _simpan() async {
    if (!_form.currentState!.validate()) return;
    final p = _perubahan();
    if (p.isEmpty) {
      setState(() => _error = 'Belum ada yang diubah.');
      return;
    }
    setState(() {
      _kirim = true;
      _error = null;
    });
    try {
      final baru = await _service.ubahKarya(widget.karya.id, p);
      if (mounted) Navigator.pop(context, baru);
    } catch (e) {
      if (mounted) {
        setState(() {
          _kirim = false;
          _error = e.toString();
        });
      }
    }
  }

  InputDecoration _dekor(String label, {String? hint, String? suffix, String? prefix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        prefixText: prefix,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    final k = widget.karya;
    final terkunci = k.terjual;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text('Ubah Karya', style: AppTextStyles.headlineSm)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter, AppSpacing.md, AppSpacing.screenGutter, AppSpacing.xxl),
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(width: 72, height: 88, child: KaryaImage(karya: k)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Gambar karya tidak bisa diganti karena menjadi dasar sertifikat keaslian. Untuk gambar lain, unggah karya baru.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                  ),
                ),
              ],
            ),
            if (terkunci) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Text('Karya ini sudah terjual atau sedang dipesan, jadi tidak bisa diubah.', style: AppTextStyles.bodySm),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('f_judul'),
              controller: _judul,
              enabled: !terkunci,
              maxLength: 200,
              decoration: _dekor('Judul karya'),
              validator: _wajib,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              key: const Key('f_harga'),
              controller: _harga,
              enabled: !terkunci,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
              decoration: _dekor('Harga', prefix: 'Rp '),
              validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) > 0 ? null : 'Harga harus lebih dari 0',
              onChanged: (_) => setState(() {}),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'Harga tampil: ${formatRupiah(int.tryParse(_harga.text.trim()) ?? 0)}'
                '${k.lelangId != null ? '  ·  harga dikunci selama lelang' : ''}',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _gaya,
              isExpanded: true,
              decoration: _dekor('Aliran seni / genre'),
              items: [for (final g in _opsiGaya) DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis))],
              onChanged: terkunci ? null : (v) => setState(() => _gaya = v ?? _gaya),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('f_lebar'),
                    controller: _lebar,
                    enabled: !terkunci,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dekor('Lebar', suffix: 'cm'),
                    validator: _ukuran,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextFormField(
                    key: const Key('f_tinggi'),
                    controller: _tinggi,
                    enabled: !terkunci,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dekor('Tinggi', suffix: 'cm'),
                    validator: _ukuran,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const Key('f_galeri'),
              controller: _galeri,
              enabled: !terkunci,
              maxLength: 200,
              decoration: _dekor('Nama galeri / sanggar'),
              validator: _wajib,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              key: const Key('f_deskripsi'),
              controller: _deskripsi,
              enabled: !terkunci,
              maxLines: 5,
              maxLength: 2000,
              decoration: _dekor('Deskripsi', hint: 'Bahan, teknik, cerita di balik karya…'),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('simpan_karya'),
                onPressed: (_kirim || terkunci) ? null : _simpan,
                child: _kirim
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Simpan Perubahan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
