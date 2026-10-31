import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/lelang.dart';
import '../../../services/auth_service.dart';
import '../../../services/lelang_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../utils/format_waktu.dart';
import '../../../widgets/lelang_widgets.dart';
import '../../../widgets/pesanan_widgets.dart';
import 'pasang_bid_sheet.dart';

/// Detail satu lelang: karya, hitung mundur (jam server), riwayat tawaran, dan tombol tawar.
/// Data disegarkan tiap 5 detik selama lelang berlangsung supaya tawaran orang lain muncul.
/// Dipakai kolektor (menawar) dan seniman pemilik (melihat, membatalkan bila belum ada tawaran).
class DetailLelangScreen extends StatefulWidget {
  const DetailLelangScreen({
    super.key,
    required this.lelangId,
    required this.onBack,
    this.onLihatPesanan,
    this.onLogin,
    LelangService? service,
  }) : _service = service;

  final String lelangId;
  final VoidCallback onBack;

  /// Pemenang/penjual membuka pesanan hasil lelang.
  final ValueChanged<String>? onLihatPesanan;
  final VoidCallback? onLogin;
  final LelangService? _service;

  @override
  State<DetailLelangScreen> createState() => _DetailLelangScreenState();
}

class _DetailLelangScreenState extends State<DetailLelangScreen> {
  late final LelangService _service = widget._service ?? LelangService();
  Lelang? _l;
  bool _memuat = true;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _muat();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      final l = _l;
      if (l != null && (l.statusSekarang == 'berlangsung' || l.statusSekarang == 'akan_datang')) _muat(senyap: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _muat({bool senyap = false}) async {
    if (!senyap) {
      setState(() {
        _memuat = true;
        _error = null;
      });
    }
    try {
      final l = await _service.detail(widget.lelangId);
      if (mounted) setState(() => _l = l);
    } catch (e) {
      if (mounted && !senyap) setState(() => _error = 'Gagal memuat lelang: $e');
    } finally {
      if (mounted && !senyap) setState(() => _memuat = false);
    }
  }

  Future<void> _tawar(Lelang l) async {
    final user = AuthService.instance.user;
    if (user == null || !AuthService.instance.loggedIn) {
      tampilkanPesan(context, 'Masuk dulu untuk menawar.');
      widget.onLogin?.call();
      return;
    }
    if (user.isSeniman) {
      tampilkanPesan(context, 'Akun seniman tidak bisa menawar. Daftar sebagai kolektor untuk ikut lelang.');
      return;
    }
    final baru = await tampilkanPasangBid(context, l, service: _service);
    if (baru == null || !mounted) return;
    setState(() => _l = baru);
    tampilkanPesan(context, 'Tawaranmu tercatat. Kamu penawar tertinggi!');
  }

  Future<void> _batalkan(Lelang l) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan lelang?'),
        content: const Text('Lelang belum punya tawaran, jadi bisa dibatalkan. Karya bisa dilelang lagi atau dijual langsung.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, batalkan')),
        ],
      ),
    );
    if (ya != true) return;
    try {
      final baru = await _service.batal(l.id);
      if (mounted) {
        setState(() => _l = baru);
        tampilkanPesan(context, 'Lelang dibatalkan.');
      }
    } catch (e) {
      if (mounted) tampilkanPesan(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Detail Lelang', style: AppTextStyles.headlineSm),
        actions: [IconButton(onPressed: _memuat ? null : () => _muat(), icon: const Icon(Icons.refresh))],
      ),
      body: _memuat && l == null
          ? const Center(child: CircularProgressIndicator())
          : l == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'Lelang tidak ditemukan.', textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(onPressed: _muat, child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(onRefresh: _muat, child: _isi(l)),
      bottomNavigationBar: l == null ? null : _aksi(l),
    );
  }

  Widget _isi(Lelang l) {
    final info = infoStatusLelang(l.statusSekarang);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        AspectRatio(aspectRatio: 4 / 3, child: LelangGambar(lelang: l)),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: info.warna.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)),
                    child: Text(info.label, style: AppTextStyles.overline.copyWith(fontSize: 9, color: info.warna)),
                  ),
                  const Spacer(),
                  const Icon(Icons.timer_outlined, size: 16, color: AppColors.muted),
                  const SizedBox(width: 4),
                  HitungMundur(lelang: l, onHabis: () => _muat(senyap: true), style: AppTextStyles.labelMd),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(l.judul, style: AppTextStyles.headlineLg),
              Text('${l.artistName} · ${l.styleName}', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
              Text('Dilelang oleh ${l.senimanNama}', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
              if (l.lebarCm != null && l.tinggiCm != null)
                Text('Ukuran ${_cm(l.lebarCm!)} × ${_cm(l.tinggiCm!)} cm', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.jumlahBid == 0 ? 'HARGA AWAL' : 'TAWARAN TERTINGGI', style: AppTextStyles.overline.copyWith(color: Colors.white60)),
                    Text(formatRupiah(l.hargaSaatIniIdr), style: AppTextStyles.displayMd.copyWith(color: Colors.white, fontSize: 28)),
                    const SizedBox(height: 2),
                    Text('${l.jumlahBid} tawaran · kelipatan ${formatRupiah(l.kelipatanIdr)}', style: AppTextStyles.bodySm.copyWith(color: Colors.white70)),
                    if (l.berlangsung && l.sayaTertinggi)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Kamu penawar tertinggi', style: AppTextStyles.labelMd.copyWith(color: AppColors.accentSoft)),
                      ),
                  ],
                ),
              ),
              if (l.statusSekarang == 'selesai') ...[
                const SizedBox(height: AppSpacing.sm),
                _hasil(l),
              ],
              const SizedBox(height: AppSpacing.md),
              Text('Riwayat Tawaran', style: AppTextStyles.headlineSm),
              const SizedBox(height: AppSpacing.xs),
              if (l.bids.isEmpty)
                Text('Belum ada tawaran. Jadilah yang pertama.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted))
              else
                for (var i = 0; i < l.bids.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
                    decoration: BoxDecoration(
                      color: i == 0 ? AppColors.accentSoft.withValues(alpha: 0.35) : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.bids[i].saya ? '${l.bids[i].nama} (kamu)' : l.bids[i].nama,
                            style: AppTextStyles.bodySm.copyWith(fontWeight: l.bids[i].saya ? FontWeight.w600 : null),
                          ),
                        ),
                        Text(formatRupiah(l.bids[i].jumlahIdr), style: AppTextStyles.labelMd),
                      ],
                    ),
                  ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hasil(Lelang l) {
    final String teks;
    if (l.jumlahBid == 0) {
      teks = 'Lelang berakhir tanpa tawaran.';
    } else if (l.sayaPemenang) {
      teks = 'Selamat, kamu memenangkan lelang ini! Pesanan sudah dibuat: pilih alamat lalu bayar dalam 24 jam.';
    } else {
      teks = 'Lelang berakhir. Pemenang: ${l.pemenangNama ?? '-'}.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(color: l.sayaPemenang ? AppColors.accentSoft.withValues(alpha: 0.4) : AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Text(teks, style: AppTextStyles.bodySm),
    );
  }

  Widget? _aksi(Lelang l) {
    final user = AuthService.instance.user;
    final st = l.statusSekarang;
    Widget? tombol;
    if (l.pesananId != null) {
      tombol = ElevatedButton.icon(
        onPressed: () => widget.onLihatPesanan?.call(l.pesananId!),
        icon: const Icon(Icons.receipt_long_outlined, size: 18),
        label: Text(l.sayaPemenang ? 'Lanjutkan ke pembayaran' : 'Lihat pesanan'),
      );
    } else if (l.bisaDibatalkan) {
      tombol = OutlinedButton(onPressed: () => _batalkan(l), child: const Text('Batalkan lelang', style: TextStyle(color: AppColors.error)));
    } else if (st == 'berlangsung' && !(user?.isSeniman ?? false)) {
      tombol = ElevatedButton(
        key: const Key('tombol_tawar'),
        onPressed: l.sayaTertinggi ? null : () => _tawar(l),
        child: Text(l.sayaTertinggi ? 'Kamu penawar tertinggi' : 'Tawar · min ${formatRupiah(l.bidMinimumIdr)}'),
      );
    } else if (st == 'akan_datang') {
      tombol = ElevatedButton(onPressed: null, child: Text('Dimulai ${formatTanggal(l.mulai)}'));
    }
    if (tombol == null) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter, AppSpacing.xs, AppSpacing.screenGutter, AppSpacing.sm),
        child: SizedBox(width: double.infinity, child: tombol),
      ),
    );
  }

  static String _cm(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');
}
