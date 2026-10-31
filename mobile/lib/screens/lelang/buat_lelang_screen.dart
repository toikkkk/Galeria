import 'package:flutter/material.dart';

import '../../models/karya.dart';
import '../../models/lelang.dart';
import '../../services/katalog_service.dart';
import '../../services/lelang_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/format_waktu.dart';
import '../../widgets/karya_image.dart';

/// Seniman melelang karya terverifikasinya (`POST /api/lelang`).
///
/// Karya yang bisa dilelang: terverifikasi, belum terjual / sedang dipesan, dan belum punya lelang aktif.
/// Karya baru harus lolos verifikasi keaslian dulu ([onUnggahKarya]).
class BuatLelangScreen extends StatefulWidget {
  const BuatLelangScreen({
    super.key,
    required this.onBack,
    required this.onBerhasil,
    this.onUnggahKarya,
    this.onLelangSaya,
    KatalogService? katalog,
    LelangService? lelang,
  })  : _katalog = katalog,
        _lelang = lelang;

  final VoidCallback onBack;
  final ValueChanged<Lelang> onBerhasil;
  final VoidCallback? onUnggahKarya;
  final VoidCallback? onLelangSaya;
  final KatalogService? _katalog;
  final LelangService? _lelang;

  @override
  State<BuatLelangScreen> createState() => _BuatLelangScreenState();
}

class _BuatLelangScreenState extends State<BuatLelangScreen> {
  late final KatalogService _katalog = widget._katalog ?? KatalogService();
  late final LelangService _lelang = widget._lelang ?? LelangService();
  final _hargaAwal = TextEditingController();
  final _kelipatan = TextEditingController();

  static const _durasi = <(String, Duration)>[
    ('1 jam', Duration(hours: 1)),
    ('6 jam', Duration(hours: 6)),
    ('1 hari', Duration(days: 1)),
    ('3 hari', Duration(days: 3)),
    ('7 hari', Duration(days: 7)),
  ];

  List<Karya>? _layak;
  Karya? _karya;
  bool _mulaiSekarang = true;
  DateTime? _mulaiJadwal;
  int _durasiIdx = 2;
  bool _kirim = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muatKarya();
  }

  @override
  void dispose() {
    _hargaAwal.dispose();
    _kelipatan.dispose();
    super.dispose();
  }

  Future<void> _muatKarya() async {
    try {
      final semua = await _katalog.fetchKaryaSaya();
      final layak = semua.where((k) => k.statusVerifikasi == 'terverifikasi' && !k.terjual && k.lelangId == null).toList();
      if (mounted) setState(() => _layak = layak);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat karyamu: $e');
    }
  }

  int? _angka(TextEditingController c) => int.tryParse(c.text.replaceAll('.', '').replaceAll(',', '').trim());

  Future<void> _pilihJadwal() async {
    final sekarang = DateTime.now();
    final tgl = await showDatePicker(context: context, initialDate: sekarang, firstDate: sekarang, lastDate: sekarang.add(const Duration(days: 60)));
    if (tgl == null || !mounted) return;
    final jam = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(sekarang.add(const Duration(hours: 1))));
    if (jam == null || !mounted) return;
    setState(() => _mulaiJadwal = DateTime(tgl.year, tgl.month, tgl.day, jam.hour, jam.minute));
  }

  Future<void> _submit() async {
    final k = _karya;
    final awal = _angka(_hargaAwal);
    final klp = _angka(_kelipatan);
    String? err;
    if (k == null) {
      err = 'Pilih karya yang akan dilelang.';
    } else if (awal == null || awal <= 0) {
      err = 'Isi harga awal dengan angka.';
    } else if (klp == null || klp <= 0) {
      err = 'Isi kelipatan tawaran dengan angka.';
    } else if (klp > awal) {
      err = 'Kelipatan tidak boleh lebih besar dari harga awal.';
    } else if (!_mulaiSekarang && _mulaiJadwal == null) {
      err = 'Pilih tanggal dan jam mulai.';
    } else if (!_mulaiSekarang && _mulaiJadwal!.isBefore(DateTime.now())) {
      err = 'Waktu mulai sudah lewat.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    // mulai "sekarang" dikirim 5 detik ke depan agar tidak ditolak karena selisih jam HP dan server
    final mulai = _mulaiSekarang ? DateTime.now().add(const Duration(seconds: 5)) : _mulaiJadwal!;
    setState(() {
      _kirim = true;
      _error = null;
    });
    try {
      final l = await _lelang.buat(
        karyaId: k!.id, hargaAwalIdr: awal!, kelipatanIdr: klp!, mulai: mulai, selesai: mulai.add(_durasi[_durasiIdx].$2),
      );
      if (mounted) widget.onBerhasil(l);
    } catch (e) {
      if (mounted) {
        setState(() {
          _kirim = false;
          _error = e.toString();
        });
      }
    }
  }

  InputDecoration _dekor(String label, {String? hint}) => InputDecoration(
        labelText: label, hintText: hint, prefixText: 'Rp ', filled: true, fillColor: Colors.white, isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    final layak = _layak;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Buat Lelang', style: AppTextStyles.headlineSm),
        actions: [TextButton(onPressed: widget.onLelangSaya, child: const Text('Lelang saya'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: [
          Text('Karya', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.xs),
          if (layak == null && _error == null)
            const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Center(child: CircularProgressIndicator()))
          else if (layak != null && layak.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Column(
                children: [
                  Text(
                    'Belum ada karya yang bisa dilelang. Karya harus sudah terverifikasi, belum terjual, dan belum sedang dilelang.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                  ),
                  if (widget.onUnggahKarya != null)
                    TextButton.icon(onPressed: widget.onUnggahKarya, icon: const Icon(Icons.add), label: const Text('Unggah karya')),
                ],
              ),
            )
          else if (layak != null)
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: layak.length,
                separatorBuilder: (context, i) => const SizedBox(width: AppSpacing.xs),
                itemBuilder: (context, i) {
                  final k = layak[i];
                  final aktif = _karya?.id == k.id;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _karya = k;
                      if (_hargaAwal.text.isEmpty) _hargaAwal.text = k.priceIdr.toString();
                    }),
                    child: Container(
                      width: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: aktif ? AppColors.accent : AppColors.border, width: aktif ? 2 : 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Expanded(child: SizedBox.expand(child: KaryaImage(karya: k))),
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(k.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.labelSm.copyWith(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text('Harga', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.xs),
          TextField(controller: _hargaAwal, keyboardType: TextInputType.number, decoration: _dekor('Harga awal')),
          const SizedBox(height: AppSpacing.xs),
          TextField(controller: _kelipatan, keyboardType: TextInputType.number, decoration: _dekor('Kelipatan tawaran', hint: 'mis. 100000')),
          const SizedBox(height: AppSpacing.md),
          Text('Waktu', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: true, label: Text('Mulai sekarang')), ButtonSegment(value: false, label: Text('Jadwalkan'))],
            selected: {_mulaiSekarang},
            onSelectionChanged: (s) => setState(() => _mulaiSekarang = s.first),
          ),
          if (!_mulaiSekarang)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: OutlinedButton.icon(
                onPressed: _pilihJadwal,
                icon: const Icon(Icons.event, size: 18),
                label: Text(_mulaiJadwal == null
                    ? 'Pilih tanggal & jam mulai'
                    : '${formatTanggal(_mulaiJadwal!)} ${_mulaiJadwal!.hour.toString().padLeft(2, '0')}:${_mulaiJadwal!.minute.toString().padLeft(2, '0')}'),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text('Durasi', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (var i = 0; i < _durasi.length; i++)
                ChoiceChip(label: Text(_durasi[i].$1), selected: _durasiIdx == i, onSelected: (_) => setState(() => _durasiIdx = i)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Text(
              'Setelah lelang dimulai dan ada tawaran, lelang tidak bisa dibatalkan. Penawar tertinggi saat waktu habis otomatis '
              'mendapat pesanan dan harus membayar dalam 24 jam. Komisi platform dihitung dari harga akhir.',
              style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: const Color(0xFF584400)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('terbitkan_lelang'),
              onPressed: _kirim ? null : _submit,
              child: _kirim
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_karya == null ? 'Terbitkan Lelang' : 'Terbitkan Lelang · ${formatRupiah(_angka(_hargaAwal) ?? 0)}'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
