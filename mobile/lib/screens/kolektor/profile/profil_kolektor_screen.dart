import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/pesanan.dart';
import '../../../services/auth_service.dart';
import '../../../services/pesanan_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/coming_soon.dart';
import '../../../widgets/kolektor/kolektor_bottom_nav.dart';
import '../../../widgets/pesanan_widgets.dart';

/// Profil kolektor. Identitas dari akun yang login; statistik, pesanan terakhir, dan alamat utama
/// dibaca dari server (`/api/pesanan`, `/api/alamat`). Tidak ada angka atau data contoh.
class ProfilKolektorScreen extends StatefulWidget {
  const ProfilKolektorScreen({
    super.key,
    this.onNavTap,
    this.onPindai,
    this.onLogout,
    this.onPesananTap,
    this.onPesananDetail,
    PesananService? pesananService,
    AlamatService? alamatService,
  })  : _pesanan = pesananService,
        _alamat = alamatService;

  final ValueChanged<int>? onNavTap;
  final VoidCallback? onPindai;
  final VoidCallback? onLogout;
  final VoidCallback? onPesananTap;
  final ValueChanged<Pesanan>? onPesananDetail;
  final PesananService? _pesanan;
  final AlamatService? _alamat;

  @override
  State<ProfilKolektorScreen> createState() => _ProfilKolektorScreenState();
}

class _ProfilKolektorScreenState extends State<ProfilKolektorScreen> {
  late final PesananService _pesananService = widget._pesanan ?? PesananService();
  late final AlamatService _alamatService = widget._alamat ?? AlamatService();
  List<Pesanan> _pesanan = [];
  Alamat? _alamat;
  bool _memuat = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final hasil = await Future.wait([_pesananService.daftar(), _alamatService.daftar()]);
      if (!mounted) return;
      final alamat = hasil[1] as List<Alamat>;
      setState(() {
        _pesanan = hasil[0] as List<Pesanan>;
        _alamat = alamat.where((a) => a.isUtama).firstOrNull ?? alamat.firstOrNull;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat data profil: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _tambahAlamat() async {
    final baru = await tampilkanFormAlamat(context, service: _alamatService);
    if (baru != null && mounted) setState(() => _alamat = _alamat ?? baru);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.user;
    final dimiliki = _pesanan.where((p) => p.status == 'selesai').length;
    final aktif = _pesanan.where((p) => p.status == 'menunggu_pembayaran' || p.status == 'dibayar' || p.status == 'dikonfirmasi').length;
    final terakhir = _pesanan.where((p) => p.status != 'dibatalkan').firstOrNull;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Profil Saya', style: AppTextStyles.headlineMd),
        actions: [
          IconButton(onPressed: () => showComingSoon(context, 'Pengaturan'), icon: const Icon(Icons.settings_outlined)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter, vertical: AppSpacing.sm),
          children: [
            _kartu(
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              user?.inisial ?? '?',
                              style: AppTextStyles.headlineMd.copyWith(color: Colors.white, fontSize: 22),
                            ),
                          ),
                          if (user?.emailVerified ?? false)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
                                child: const Icon(Icons.verified, size: 12, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.displayName ?? 'Tamu', style: AppTextStyles.headlineMd.copyWith(fontSize: 18)),
                            Text(user?.email ?? '', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
                            if (user?.nomorHp != null)
                              Text(user!.nomorHp!, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
                            Text(
                              'ID Kolektor: ${user?.kodeAkun ?? '-'}',
                              style: AppTextStyles.overline.copyWith(fontSize: 9, color: AppColors.outline),
                            ),
                            if (!(user?.emailVerified ?? false))
                              GestureDetector(
                                key: const Key('verifikasi_email_tautan'),
                                onTap: () async {
                                  await context.push('/verifikasi-email');
                                  if (mounted) setState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Text('Email belum diverifikasi · Verifikasi sekarang ›',
                                      style: AppTextStyles.bodySm.copyWith(
                                          fontSize: 10.5, color: const Color(0xFFB26A00), fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Row(
                      children: [
                        Expanded(child: _stat(_memuat ? '-' : '$dimiliki', 'Karya Dimiliki')),
                        Container(width: 1, height: 28, color: AppColors.border),
                        Expanded(child: _stat(_memuat ? '-' : '$aktif', 'Pesanan Aktif')),
                        Container(width: 1, height: 28, color: AppColors.border),
                        Expanded(child: _stat(_memuat ? '-' : '${_pesanan.length}', 'Total Pesanan')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
              TextButton(onPressed: _muat, child: const Text('Coba lagi')),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pesanan Terakhir', style: AppTextStyles.headlineSm),
                TextButton(onPressed: widget.onPesananTap, child: const Text('Lihat Semua')),
              ],
            ),
            if (terakhir == null)
              _kartu(Text(
                _memuat ? 'Memuat...' : 'Belum ada pesanan.',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
              ))
            else
              PesananKartu(pesanan: terakhir, onTap: () => widget.onPesananDetail?.call(terakhir)),
            const SizedBox(height: AppSpacing.sm),
            Text('Alamat Utama', style: AppTextStyles.headlineSm),
            const SizedBox(height: AppSpacing.xs),
            _kartu(
              _alamat == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_memuat ? 'Memuat...' : 'Belum ada alamat pengiriman.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                        if (!_memuat)
                          TextButton.icon(onPressed: _tambahAlamat, icon: const Icon(Icons.add_location_alt_outlined, size: 18), label: const Text('Tambah alamat')),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_alamat!.label, style: AppTextStyles.labelMd),
                        Text('${_alamat!.namaPenerima} · ${_alamat!.telepon}', style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
                        Text(_alamat!.ringkas, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
              label: const Text('Keluar dari Akun Kolektor', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.errorContainer.withValues(alpha: 0.4),
                side: BorderSide.none,
                minimumSize: const Size(double.infinity, 46),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(child: Text('GALERIA', style: AppTextStyles.labelSm.copyWith(color: AppColors.outline))),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
      bottomNavigationBar: KolektorBottomNav(
        currentIndex: 3,
        onTap: (i) => widget.onNavTap?.call(i),
        onPindai: widget.onPindai ?? () {},
      ),
    );
  }

  Widget _kartu(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: child,
      );

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value, style: AppTextStyles.headlineSm.copyWith(fontSize: 16)),
          Text(label.toUpperCase(), style: AppTextStyles.overline.copyWith(fontSize: 7)),
        ],
      );
}
