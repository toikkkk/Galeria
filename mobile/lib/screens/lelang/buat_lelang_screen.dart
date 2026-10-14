import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/karya.dart';
import '../../state/studio_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/format_waktu.dart';
import '../../widgets/karya_image.dart';
import '../../widgets/karya_picker.dart';

/// Seniman membuat lelang untuk karya terverifikasinya.
///
/// Karya dipilih dari katalog terverifikasi, atau seniman bisa mengunggah
/// karya baru dulu lewat [onUnggahKarya] (karya baru baru bisa dilelang
/// setelah lolos verifikasi keaslian).
///
/// Lelang disimpan di [StudioStore] (in-memory) -- belum ada tabel/endpoint
/// lelang di backend.
class BuatLelangScreen extends StatefulWidget {
  const BuatLelangScreen({super.key, required this.onBack, this.onUnggahKarya});

  final VoidCallback onBack;
  final VoidCallback? onUnggahKarya;

  @override
  State<BuatLelangScreen> createState() => _BuatLelangScreenState();
}

class _BuatLelangScreenState extends State<BuatLelangScreen> {
  final _store = StudioStore.instance;
  final _hargaAwal = TextEditingController();
  final _kelipatan = TextEditingController(text: '500000');
  final _catatan = TextEditingController();

  Karya? _karya;
  DateTime? _mulaiTgl;
  TimeOfDay? _mulaiJam;
  DateTime? _selesaiTgl;
  TimeOfDay? _selesaiJam;
  String? _error;

  @override
  void dispose() {
    _hargaAwal.dispose();
    _kelipatan.dispose();
    _catatan.dispose();
    super.dispose();
  }

  int _angka(TextEditingController c) => int.tryParse(c.text.replaceAll('.', '').trim()) ?? 0;

  DateTime? _gabung(DateTime? tgl, TimeOfDay? jam) =>
      tgl == null || jam == null ? null : DateTime(tgl.year, tgl.month, tgl.day, jam.hour, jam.minute);

  Future<void> _pilihKarya() async {
    final hasil = await showKaryaPicker(
      context,
      onUnggahBaru: widget.onUnggahKarya,
    );
    if (hasil == null || hasil.isEmpty) return;
    setState(() {
      _karya = hasil.first;
      if (_hargaAwal.text.isEmpty) _hargaAwal.text = hasil.first.priceIdr.toString();
    });
  }

  Future<DateTime?> _pilihTanggal(DateTime? awal) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: awal ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
  }

  void _terbitkan() {
    final karya = _karya;
    final awal = _angka(_hargaAwal);
    final step = _angka(_kelipatan);
    final mulai = _gabung(_mulaiTgl, _mulaiJam);
    final selesai = _gabung(_selesaiTgl, _selesaiJam);

    String? err;
    if (karya == null) {
      err = 'Pilih karya yang akan dilelang.';
    } else if (awal <= 0) {
      err = 'Harga awal harus lebih dari 0.';
    } else if (step <= 0) {
      err = 'Kelipatan bid harus lebih dari 0.';
    } else if (mulai == null || selesai == null) {
      err = 'Lengkapi tanggal dan jam mulai serta selesai.';
    } else if (!selesai.isAfter(mulai)) {
      err = 'Waktu selesai harus setelah waktu mulai.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    _store.tambahLelang(
      LelangSeniman(
        karya: karya!,
        hargaAwalIdr: awal,
        kelipatanBidIdr: step,
        mulai: mulai!,
        selesai: selesai!,
        catatan: _catatan.text.trim(),
      ),
    );
    setState(() {
      _error = null;
      _karya = null;
      _hargaAwal.clear();
      _catatan.clear();
      _mulaiTgl = _mulaiJam = _selesaiTgl = _selesaiJam = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lelang berhasil dibuat dan dijadwalkan.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
          title: Text('Buat Lelang', style: AppTextStyles.headlineSm),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.md,
            AppSpacing.screenGutter,
            AppSpacing.xxl,
          ),
          children: [
            _label('Karya yang dilelang'),
            _karyaCard(),
            const SizedBox(height: AppSpacing.md),
            _label('Harga awal (Rp)'),
            _angkaField(_hargaAwal, 'mis. 5000000'),
            const SizedBox(height: AppSpacing.sm),
            _label('Kelipatan bid (Rp)'),
            _angkaField(_kelipatan, 'mis. 500000'),
            const SizedBox(height: AppSpacing.md),
            _label('Lelang dimulai'),
            _waktuRow(
              tgl: _mulaiTgl,
              jam: _mulaiJam,
              onTgl: () async {
                final d = await _pilihTanggal(_mulaiTgl);
                if (d != null) setState(() => _mulaiTgl = d);
              },
              onJam: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: _mulaiJam ?? const TimeOfDay(hour: 10, minute: 0),
                );
                if (t != null) setState(() => _mulaiJam = t);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _label('Lelang berakhir'),
            _waktuRow(
              tgl: _selesaiTgl,
              jam: _selesaiJam,
              onTgl: () async {
                final d = await _pilihTanggal(_selesaiTgl ?? _mulaiTgl);
                if (d != null) setState(() => _selesaiTgl = d);
              },
              onJam: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: _selesaiJam ?? const TimeOfDay(hour: 20, minute: 0),
                );
                if (t != null) setState(() => _selesaiJam = t);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _label('Catatan untuk peserta (opsional)'),
            TextField(
              controller: _catatan,
              maxLines: 3,
              decoration: _dekor('Kondisi karya, pengiriman, dll'),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: _terbitkan,
              icon: const Icon(Icons.gavel_outlined, size: 18),
              label: const Text('Jadwalkan Lelang'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Lelang tersimpan sementara di aplikasi (belum tersinkron ke server).',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
            ),
            if (_store.lelang.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Lelang yang kamu buat', style: AppTextStyles.headlineMd),
              const SizedBox(height: AppSpacing.sm),
              for (final l in _store.lelang) _lelangTile(l),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: AppTextStyles.labelMd),
      );

  InputDecoration _dekor(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );

  Widget _angkaField(TextEditingController c, String hint) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _dekor(hint).copyWith(prefixText: 'Rp '),
      );

  Widget _karyaCard() {
    final k = _karya;
    return InkWell(
      onTap: _pilihKarya,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: k == null
            ? Row(
                children: [
                  const Icon(Icons.add_photo_alternate_outlined, color: AppColors.accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Pilih karya terverifikasi', style: AppTextStyles.bodyMd),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              )
            : Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: SizedBox(width: 64, height: 64, child: KaryaImage(karya: k)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(k.title, style: AppTextStyles.labelMd, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          'Harga katalog ${k.priceFormatted}',
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: _pilihKarya, child: const Text('Ganti')),
                ],
              ),
      ),
    );
  }

  Widget _waktuRow({
    required DateTime? tgl,
    required TimeOfDay? jam,
    required VoidCallback onTgl,
    required VoidCallback onJam,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: OutlinedButton.icon(
            onPressed: onTgl,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(tgl == null ? 'Pilih tanggal' : formatTanggal(tgl)),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed: onJam,
            icon: const Icon(Icons.access_time, size: 16),
            label: Text(jam == null ? 'Jam' : formatJam(jam)),
          ),
        ),
      ],
    );
  }

  Widget _lelangTile(LelangSeniman l) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(width: 56, height: 56, child: KaryaImage(karya: l.karya)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.karya.title, style: AppTextStyles.labelMd, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  'Mulai ${formatRupiah(l.hargaAwalIdr)} · bid +${formatRupiah(l.kelipatanBidIdr)}',
                  style: AppTextStyles.bodySm.copyWith(fontSize: 11),
                ),
                Text(
                  '${formatTanggalJam(l.mulai)} → ${formatTanggalJam(l.selesai)}',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
