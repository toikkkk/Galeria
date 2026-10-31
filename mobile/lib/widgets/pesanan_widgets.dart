import 'package:flutter/material.dart';

import '../models/karya.dart';
import '../models/pesanan.dart';
import '../services/auth_service.dart';
import '../services/pesanan_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'karya_image.dart';

/// Gambar karya sebuah pesanan (dari R2 bila ada, selain itu asset lokal).
class PesananGambar extends StatelessWidget {
  const PesananGambar({super.key, required this.pesanan, this.ukuran = 64});

  final Pesanan pesanan;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    final karya = Karya(
      assetPath: 'assets/images/catalog/${pesanan.imageFilename ?? ''}',
      imageUrl: pesanan.imageUrl,
      title: pesanan.judul,
      artistName: pesanan.artistName,
      styleName: pesanan.styleName,
      priceIdr: pesanan.hargaIdr,
      galleryName: pesanan.artistName,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(width: ukuran, height: ukuran, child: KaryaImage(karya: karya)),
    );
  }
}

/// Lencana status pesanan (warna mengikuti tahap).
class StatusPesananChip extends StatelessWidget {
  const StatusPesananChip({super.key, required this.pesanan});

  final Pesanan pesanan;

  @override
  Widget build(BuildContext context) {
    final (warna, ikon) = switch (pesanan.status) {
      'menunggu_pembayaran' => (const Color(0xFFB26A00), Icons.schedule),
      'dibayar' => (AppColors.primary, Icons.payments_outlined),
      'dikonfirmasi' => (AppColors.accent, pesanan.sudahDikirim ? Icons.local_shipping_outlined : Icons.inventory_2_outlined),
      'selesai' => (AppColors.success, Icons.check_circle_outline),
      _ => (AppColors.error, Icons.cancel_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: warna.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 12, color: warna),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              pesanan.statusLabel,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSm.copyWith(fontSize: 10.5, color: warna),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu ringkas satu pesanan. [tombol] = aksi cepat di bawah (opsional).
class PesananKartu extends StatelessWidget {
  const PesananKartu({super.key, required this.pesanan, required this.onTap, this.sebagaiPenjual = false, this.tombol});

  final Pesanan pesanan;
  final VoidCallback onTap;
  final bool sebagaiPenjual;
  final Widget? tombol;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PesananGambar(pesanan: pesanan),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pesanan.kode, style: AppTextStyles.overline.copyWith(fontSize: 9, color: AppColors.outline)),
                      Text(pesanan.judul, style: AppTextStyles.labelMd, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        sebagaiPenjual ? 'Pembeli: ${pesanan.pembeliNama}' : pesanan.artistName,
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      StatusPesananChip(pesanan: pesanan),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatRupiah(sebagaiPenjual ? pesanan.pendapatanSenimanIdr : pesanan.hargaIdr),
                      style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                    ),
                    if (sebagaiPenjual)
                      Text('setelah komisi', style: AppTextStyles.bodySm.copyWith(fontSize: 9.5, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
            if (tombol != null) ...[const SizedBox(height: AppSpacing.xs), tombol!],
          ],
        ),
      ),
    );
  }
}

void tampilkanPesan(BuildContext context, String teks) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
}

/// Form tambah alamat (bottom sheet). Mengembalikan alamat yang tersimpan, atau null bila dibatalkan.
Future<Alamat?> tampilkanFormAlamat(BuildContext context, {AlamatService? service}) {
  return showModalBottomSheet<Alamat>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (_) => _FormAlamat(service: service ?? AlamatService()),
  );
}

class _FormAlamat extends StatefulWidget {
  const _FormAlamat({required this.service});

  final AlamatService service;

  @override
  State<_FormAlamat> createState() => _FormAlamatState();
}

class _FormAlamatState extends State<_FormAlamat> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: 'Rumah');
  late final _nama = TextEditingController(text: AuthService.instance.user?.displayName ?? '');
  late final _telepon = TextEditingController(text: AuthService.instance.user?.nomorHp ?? '');
  final _alamat = TextEditingController();
  final _kota = TextEditingController();
  final _pos = TextEditingController();
  bool _kirim = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_label, _nama, _telepon, _alamat, _kota, _pos]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _wajib(String? v, {int min = 1}) => (v == null || v.trim().length < min) ? 'Wajib diisi' : null;

  Future<void> _simpan() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _kirim = true;
      _error = null;
    });
    try {
      final a = await widget.service.tambah(
        label: _label.text.trim(),
        namaPenerima: _nama.text.trim(),
        telepon: _telepon.text.trim(),
        alamatLengkap: _alamat.text.trim(),
        kota: _kota.text.trim(),
        kodePos: _pos.text.trim(),
      );
      if (mounted) Navigator.pop(context, a);
    } catch (e) {
      if (mounted) {
        setState(() {
          _kirim = false;
          _error = e.toString();
        });
      }
    }
  }

  InputDecoration _dekor(String label, {String? hint}) =>
      InputDecoration(labelText: label, hintText: hint, filled: true, fillColor: Colors.white, isDense: true);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenGutter,
        right: AppSpacing.screenGutter,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alamat Pengiriman Baru', style: AppTextStyles.headlineSm),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(controller: _label, decoration: _dekor('Label', hint: 'Rumah / Kantor'), validator: _wajib),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(controller: _nama, decoration: _dekor('Nama penerima'), validator: (v) => _wajib(v, min: 2)),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _telepon,
                keyboardType: TextInputType.phone,
                decoration: _dekor('Nomor telepon', hint: '0812xxxxxxx'),
                validator: (v) => _wajib(v, min: 8),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _alamat,
                maxLines: 2,
                decoration: _dekor('Alamat lengkap', hint: 'Jalan, nomor, kelurahan'),
                validator: (v) => _wajib(v, min: 10),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(controller: _kota, decoration: _dekor('Kota'), validator: (v) => _wajib(v, min: 2)),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _pos,
                      keyboardType: TextInputType.number,
                      decoration: _dekor('Kode pos'),
                      validator: (v) => RegExp(r'^\d{5}$').hasMatch((v ?? '').trim()) ? null : '5 digit',
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _kirim ? null : _simpan,
                  child: _kirim
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Simpan Alamat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
