import 'package:flutter/material.dart';

import '../../services/ulasan_service.dart';
import '../../theme/app_theme.dart';

const _minChar = 10;
const _maxChar = 500;

/// Buka formulir "Tulis ulasan". Mengembalikan `true` bila ulasan berhasil terkirim.
Future<bool> tampilkanTulisUlasan(BuildContext context, {required String karyaId, required String judulKarya, UlasanService? service}) async {
  final hasil = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (_) => TulisUlasanSheet(karyaId: karyaId, judulKarya: judulKarya, service: service),
  );
  return hasil ?? false;
}

class TulisUlasanSheet extends StatefulWidget {
  const TulisUlasanSheet({super.key, required this.karyaId, required this.judulKarya, this.service});

  final String karyaId, judulKarya;
  final UlasanService? service;

  @override
  State<TulisUlasanSheet> createState() => _TulisUlasanSheetState();
}

class _TulisUlasanSheetState extends State<TulisUlasanSheet> {
  late final UlasanService _service = widget.service ?? UlasanService();
  final _teks = TextEditingController();
  int _rating = 0;
  bool _kirim = false;
  String? _error;

  @override
  void dispose() {
    _teks.dispose();
    super.dispose();
  }

  int get _panjang => _teks.text.trim().length;
  bool get _valid => _rating > 0 && _panjang >= _minChar && _panjang <= _maxChar;

  Future<void> _submit() async {
    setState(() {
      _kirim = true;
      _error = null;
    });
    try {
      await _service.kirim(karyaId: widget.karyaId, rating: _rating, teks: _teks.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _kirim = false;
        _error = pesanGagalUlasan(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.screenGutter, AppSpacing.md, AppSpacing.screenGutter,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tulis ulasan', style: AppTextStyles.headlineMd),
            const SizedBox(height: 2),
            Text(widget.judulKarya, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
            const SizedBox(height: AppSpacing.sm),
            Text('Penilaianmu', style: AppTextStyles.bodySm),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    key: Key('bintang_$i'),
                    onPressed: _kirim ? null : () => setState(() => _rating = i),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: i <= _rating ? AppColors.accent : AppColors.outlineVariant, size: 32),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              key: const Key('isi_ulasan'),
              controller: _teks,
              enabled: !_kirim,
              minLines: 3,
              maxLines: 6,
              maxLength: _maxChar,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Ceritakan alasanmu: kualitas lukisan, pengiriman, kemasan, komunikasi dengan seniman…',
                helperText: _panjang < _minChar ? 'Minimal $_minChar karakter' : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(_error!, key: const Key('error_ulasan'), style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('kirim_ulasan'),
                onPressed: _valid && !_kirim ? _submit : null,
                child: _kirim
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Kirim ulasan'),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Ulasanmu akan dibaca otomatis untuk menilai sentimennya, jadi baru terhitung di ringkasan setelah dianalisis.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
