import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../models/pesanan.dart';
import '../../../services/pesanan_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../widgets/commerce_widgets.dart';
import '../../../widgets/pesanan_widgets.dart';

/// (kode, nama, warna merek, singkatan, kelompok)
const _metode = <(String, String, Color, String, String)>[
  ('va_bca', 'BCA Virtual Account', Color(0xFF0060AF), 'BCA', 'Transfer Virtual Account'),
  ('va_mandiri', 'Mandiri Virtual Account', Color(0xFF003D79), 'MDR', 'Transfer Virtual Account'),
  ('va_bni', 'BNI Virtual Account', Color(0xFFF15A23), 'BNI', 'Transfer Virtual Account'),
  ('qris', 'QRIS', Color(0xFFD7263D), 'QR', 'Dompet digital & QR'),
];

/// Pilih metode pembayaran, tampilkan instruksi, dan (mode sandbox) simulasikan pembayaran.
///
/// MODE SANDBOX: tidak ada uang sungguhan dan belum ada gateway di belakangnya. Tombol "Simulasikan
/// pembayaran" meniru notifikasi "pembayaran diterima" dari gateway, supaya seluruh alur pesanan
/// (konfirmasi seniman, pengiriman, penerimaan) bisa dicoba dari awal sampai selesai.
class SelesaikanPembayaranScreen extends StatefulWidget {
  const SelesaikanPembayaranScreen({
    super.key,
    required this.pesanan,
    required this.onBack,
    required this.onSelesai,
    PesananService? service,
  }) : _service = service;

  final Pesanan pesanan;
  final VoidCallback onBack;

  /// Dipanggil dengan pesanan terbaru setelah dibayar atau dibatalkan.
  final ValueChanged<Pesanan> onSelesai;
  final PesananService? _service;

  @override
  State<SelesaikanPembayaranScreen> createState() => _SelesaikanPembayaranScreenState();
}

class _SelesaikanPembayaranScreenState extends State<SelesaikanPembayaranScreen> {
  late final PesananService _service = widget._service ?? PesananService();
  late Pesanan _pesanan = widget.pesanan;
  bool _sibuk = false;
  String? _error;
  final AlamatService _alamatService = AlamatService();
  List<Alamat> _alamat = [];

  @override
  void initState() {
    super.initState();
    if (_pesanan.perluAlamat) _muatAlamat();
  }

  Future<void> _muatAlamat() async {
    try {
      final d = await _alamatService.daftar();
      if (mounted) setState(() => _alamat = d);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat alamat: $e');
    }
  }

  Future<void> _tambahAlamat() async {
    final baru = await tampilkanFormAlamat(context, service: _alamatService);
    if (baru == null || !mounted) return;
    setState(() => _alamat = [..._alamat, baru]);
    await _jalankan(() => _service.pilihAlamat(_pesanan.id, baru.id));
  }

  Future<void> _ubahAlamat() async {
    if (_alamat.isEmpty) return _tambahAlamat();
    final id = await tampilkanPilihAlamat(context, daftar: _alamat, dipilih: null);
    if (id == null || !mounted) return;
    if (id == kAlamatBaru) return _tambahAlamat();
    await _jalankan(() => _service.pilihAlamat(_pesanan.id, id));
  }

  Future<void> _jalankan(Future<Pesanan> Function() kerja, {bool selesai = false}) async {
    setState(() {
      _sibuk = true;
      _error = null;
    });
    try {
      final baru = await kerja();
      if (!mounted) return;
      if (selesai) {
        widget.onSelesai(baru);
        return;
      }
      setState(() => _pesanan = baru);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _batal() async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: const Text('Karya akan tersedia lagi untuk kolektor lain.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, batalkan')),
        ],
      ),
    );
    if (ya == true) await _jalankan(() => _service.batal(_pesanan.id), selesai: true);
  }

  Future<void> _salin(String teks, String pesan) async {
    await Clipboard.setData(ClipboardData(text: teks));
    if (mounted) tampilkanPesan(context, pesan);
  }

  Widget _tileMetode((String, String, Color, String, String) m) {
    final dipilih = _pesanan.metodePembayaranTerpilih == m.$1;
    final terkunci = _sibuk || _pesanan.perluAlamat;
    return InkWell(
      onTap: terkunci ? null : () => _jalankan(() => _service.pilihMetode(_pesanan.id, m.$1)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: m.$3, borderRadius: BorderRadius.circular(6)),
              child: Text(m.$4, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(m.$2, style: AppTextStyles.labelMd.copyWith(fontSize: 13.5))),
            Icon(dipilih ? Icons.radio_button_checked : Icons.radio_button_off, color: dipilih ? AppColors.accent : AppColors.outlineVariant, size: 22),
          ],
        ),
      ),
    );
  }

  List<Widget> _kelompokMetode() {
    final kelompok = <String, List<(String, String, Color, String, String)>>{};
    for (final m in _metode) {
      kelompok.putIfAbsent(m.$5, () => []).add(m);
    }
    return [
      for (final e in kelompok.entries)
        KartuBagian(
          judul: e.key,
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xxs, AppSpacing.md, AppSpacing.xxs),
          child: Column(
            children: [
              for (var i = 0; i < e.value.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _tileMetode(e.value[i]),
              ],
            ],
          ),
        ),
    ];
  }

  Widget _instruksi(InstruksiBayar ins) {
    final qris = ins.metode == 'qris';
    return KartuBagian(
      judul: qris ? 'Pindai Kode QRIS' : 'Nomor ${ins.namaMetode}',
      ikon: qris ? Icons.qr_code_2 : Icons.pin_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (qris)
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
                child: QrImageView(data: ins.nomor, size: 170, padding: EdgeInsets.zero),
              ),
            ),
          if (qris) const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(child: SelectableText(ins.nomor, style: AppTextStyles.headlineSm.copyWith(letterSpacing: qris ? 0.2 : 1.2, fontSize: qris ? 13 : 19))),
              TextButton.icon(
                onPressed: () => _salin(ins.nomor, 'Nomor disalin.'),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Salin'),
              ),
            ],
          ),
          const Divider(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: Text('Jumlah yang harus dibayar', style: AppTextStyles.bodySm)),
              Text(formatRupiah(ins.jumlahIdr), style: AppTextStyles.labelMd.copyWith(fontSize: 14)),
              IconButton(
                onPressed: () => _salin(ins.jumlahIdr.toString(), 'Jumlah disalin.'),
                icon: const Icon(Icons.copy, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: 'Salin jumlah',
              ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text('Cara membayar', style: AppTextStyles.labelMd.copyWith(fontSize: 13)),
            children: [
              for (final (i, l) in (qris
                      ? const ['Buka aplikasi dompet digital atau m-banking yang mendukung QRIS.', 'Pilih menu Bayar / Scan lalu pindai kode di atas.', 'Periksa nominal, lalu konfirmasi pembayaran.']
                      : const ['Buka m-banking atau ATM bank yang dipilih.', 'Pilih menu Transfer / Virtual Account, lalu masukkan nomor di atas.', 'Periksa nama dan nominal, lalu konfirmasi pembayaran.'])
                  .indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(radius: 9, backgroundColor: AppColors.surfaceContainerHigh, child: Text('${i + 1}', style: AppTextStyles.labelSm.copyWith(fontSize: 10))),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(child: Text(l, style: AppTextStyles.bodySm.copyWith(fontSize: 12, color: AppColors.onSurface))),
                    ],
                  ),
                ),
            ],
          ),
          if (ins.sandbox)
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs + 2),
              decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Text(
                'Mode sandbox: nomor ini hanya contoh, tidak ada uang sungguhan. Gunakan tombol di bawah untuk mensimulasikan pembayaran masuk.',
                style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: const Color(0xFF584400)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ins = _pesanan.instruksi;
    final batas = _pesanan.batasBayarAt;
    return Scaffold(
      backgroundColor: kLatarMarketplace,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Selesaikan Pembayaran', style: AppTextStyles.headlineSm),
      ),
      body: Column(
        children: [
          const IndikatorLangkah(aktif: 1),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.sm),
              children: [
                BannerStatus(
                  warna: AppColors.primary,
                  ikon: Icons.schedule,
                  judul: batas != null ? 'Bayar dalam' : 'Menunggu pembayaran',
                  subjudul: '${_pesanan.judul} · ${_pesanan.kode}',
                  trailing: batas == null
                      ? null
                      : HitungMundurBatas(
                          batas: batas,
                          gaya: AppTextStyles.headlineSm.copyWith(color: AppColors.accentSoft, fontSize: 18),
                        ),
                ),
                const SizedBox(height: AppSpacing.xs),
                KartuBagian(
                  child: Row(
                    children: [
                      PesananGambar(pesanan: _pesanan, ukuran: 56),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_pesanan.judul, style: AppTextStyles.labelMd, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('Total pembayaran', style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                      Text(formatRupiah(_pesanan.hargaIdr), style: AppTextStyles.headlineSm.copyWith(fontSize: 17)),
                    ],
                  ),
                ),
                if (_pesanan.perluAlamat)
                  KartuBagian(
                    judul: 'Alamat Pengiriman',
                    ikon: Icons.location_on_outlined,
                    aksi: TextButton(onPressed: _sibuk ? null : _ubahAlamat, child: Text(_alamat.isEmpty ? 'Tambah' : 'Pilih')),
                    child: Text(
                      'Pesanan dari lelang belum punya alamat. Pilih alamat pengiriman sebelum membayar.',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                    ),
                  )
                else if (_pesanan.dariLelang && _pesanan.alamat != null)
                  KartuBagian(
                    judul: 'Dikirim ke',
                    ikon: Icons.location_on_outlined,
                    child: Text(_pesanan.alamatRingkas, style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurface)),
                  ),
                ..._kelompokMetode(),
                ?(ins == null ? null : _instruksi(ins)),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                  ),
                Center(
                  child: TextButton(
                    onPressed: _sibuk ? null : _batal,
                    child: const Text('Batalkan pesanan', style: TextStyle(color: AppColors.error)),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BarBawah(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total', style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
                  Text(formatRupiah(_pesanan.hargaIdr), style: AppTextStyles.headlineMd.copyWith(fontSize: 19, color: AppColors.onSurface)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: (_sibuk || ins == null || !ins.sandbox) ? null : () => _jalankan(() => _service.simulasiBayar(_pesanan.id), selesai: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onSurface,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
                icon: _sibuk
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(ins == null ? 'Pilih metode dulu' : 'Simulasikan bayar (sandbox)', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on Pesanan {
  /// Metode yang sedang dipilih (null bila belum memilih).
  String? get metodePembayaranTerpilih => instruksi?.metode;
}
