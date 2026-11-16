import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../services/favorit_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../utils/format_waktu.dart';
import '../../../widgets/favorit_hati.dart';
import '../../../widgets/karya_image.dart';
import '../../../widgets/kolektor/kolektor_bottom_nav.dart';

/// Koleksi Saya: karya yang KAMU MILIKI (setelah pesanan diterima) dan karya FAVORITMU. Semua dari server.
///
/// "Periksa sertifikat" memanggil verifikasi publik (hash + tanda tangan Ed25519) dan menampilkan hasilnya apa adanya.
/// Istilah wajib: "sertifikat digital keaslian" / bukti registrasi kepemilikan digital -- BUKAN "Hak Paten", dan
/// bukan pemeriksaan keaslian fisik lukisan.
class KoleksiSayaScreen extends StatefulWidget {
  const KoleksiSayaScreen({super.key, this.onNavTap, this.onPindai, this.onKaryaTap, FavoritService? service}) : _service = service;

  final ValueChanged<int>? onNavTap;
  final VoidCallback? onPindai;
  final ValueChanged<Karya>? onKaryaTap;
  final FavoritService? _service;

  @override
  State<KoleksiSayaScreen> createState() => _KoleksiSayaScreenState();
}

class _KoleksiSayaScreenState extends State<KoleksiSayaScreen> {
  late final FavoritService _service = widget._service ?? FavoritService();
  List<KoleksiItem>? _milik;
  List<Karya>? _favorit;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _muat();
    FavoritStore.instance.addListener(_favoritBerubah);
  }

  @override
  void dispose() {
    FavoritStore.instance.removeListener(_favoritBerubah);
    super.dispose();
  }

  // hati di tab Favorit diketuk -> daftar disegarkan
  void _favoritBerubah() {
    if (_tab == 1 && mounted) _muatFavorit();
  }

  Future<void> _muatFavorit() async {
    try {
      final f = await _service.daftar();
      if (mounted) setState(() => _favorit = f);
    } catch (_) {}
  }

  Future<void> _muat() async {
    setState(() => _error = null);
    try {
      final hasil = await Future.wait([_service.koleksi(), _service.daftar()]);
      if (!mounted) return;
      setState(() {
        _milik = hasil[0] as List<KoleksiItem>;
        _favorit = hasil[1] as List<Karya>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat koleksi: $e');
    }
  }

  Future<void> _periksa(Karya k) async {
    final id = k.artworkId;
    if (id == null) return;
    final hasil = await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => _SertifikatSheet(artworkId: id, judul: k.title, service: _service),
    );
    return hasil;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text('Koleksi Saya', style: AppTextStyles.headlineMd), actions: [IconButton(onPressed: _muat, icon: const Icon(Icons.refresh))]),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter, vertical: AppSpacing.sm),
          children: [
            SegmentedButton<int>(
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF3E251E),
                selectedBackgroundColor: const Color(0xFF3E251E),
                selectedForegroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              segments: [
                ButtonSegment(value: 0, label: Text('Dimiliki${_milik == null ? '' : ' (${_milik!.length})'}')),
                ButtonSegment(value: 1, label: Text('Favorit${_favorit == null ? '' : ' (${_favorit!.length})'}')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_error != null)
              Column(children: [
                Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                OutlinedButton.icon(onPressed: _muat, icon: const Icon(Icons.refresh, size: 16), label: const Text('Coba Lagi')),
              ])
            else if ((_tab == 0 ? _milik : _favorit) == null)
              const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator()))
            else if (_tab == 0)
              ..._dimiliki()
            else
              ..._favoritList(),
          ],
        ),
      ),
      bottomNavigationBar: KolektorBottomNav(currentIndex: 3, onTap: (i) => widget.onNavTap?.call(i), onPindai: widget.onPindai ?? () {}),
    );
  }

  List<Widget> _dimiliki() {
    final d = _milik!;
    if (d.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text('Kamu belum memiliki karya. Karya muncul di sini setelah pesanan atau lelang yang kamu menangkan diterima.', textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
        ),
      ];
    }
    final total = d.fold<int>(0, (a, x) => a + (x.hargaIdr ?? 0));
    return [
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4D2F26), Color(0xFF2F1B15)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.collections_bookmark_outlined, size: 15, color: Color(0xFFF0C86A)),
            const SizedBox(width: 6),
            Text('NILAI KOLEKSI', style: AppTextStyles.overline.copyWith(fontSize: 10, color: Colors.white70)),
          ]),
          const SizedBox(height: 4),
          Text(formatRupiah(total), style: AppTextStyles.headlineLg.copyWith(fontSize: 26, color: const Color(0xFFF0C86A), fontWeight: FontWeight.w800)),
          Text('Total yang kamu bayarkan untuk semua karya', style: AppTextStyles.bodySm.copyWith(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            _statKoleksi('${d.length}', 'Karya'),
            _statKoleksi('${d.where((x) => x.karya.artworkId != null).length}', 'Bersertifikat'),
            _statKoleksi('${d.map((x) => x.karya.artistName).toSet().length}', 'Seniman'),
          ]),
        ]),
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final x in d)
        GestureDetector(
          onTap: () => widget.onKaryaTap?.call(x.karya),
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(borderRadius: BorderRadius.circular(AppRadius.md), child: SizedBox(width: 92, height: 124, child: KaryaImage(karya: x.karya))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (x.karya.artworkId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF7E7C1), borderRadius: BorderRadius.circular(AppRadius.full)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.verified, size: 12, color: Color(0xFF7A5410)),
                        const SizedBox(width: 3),
                        Text('BERSERTIFIKAT', style: AppTextStyles.overline.copyWith(fontSize: 8.5, color: const Color(0xFF7A5410), fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  const SizedBox(height: 4),
                  Text(x.karya.title, style: AppTextStyles.labelMd.copyWith(fontSize: 15, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(x.karya.artistName, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11.5)),
                  const SizedBox(height: 4),
                  Text('${x.sumber == 'lelang' ? 'Menang lelang' : 'Dibeli'} · ${formatTanggal(x.diperoleh)}', style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted)),
                  if (x.hargaIdr != null) Text(formatRupiah(x.hargaIdr!), style: AppTextStyles.labelMd.copyWith(color: const Color(0xFF3E251E), fontSize: 15.5, fontWeight: FontWeight.w800)),
                  if (x.karya.artworkId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('ID Sertifikat: ${x.karya.artworkId}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm.copyWith(fontSize: 10, fontFamily: 'monospace', color: AppColors.muted)),
                    ),
                  const SizedBox(height: 6),
                  if (x.karya.artworkId != null)
                    GestureDetector(
                      onTap: () => _periksa(x.karya),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF3E251E), borderRadius: BorderRadius.circular(AppRadius.full)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFFF0C86A)),
                          const SizedBox(width: 5),
                          Text('Periksa sertifikat', style: AppTextStyles.labelSm.copyWith(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    )
                  else
                    Text('Belum bersertifikat digital', style: AppTextStyles.bodySm.copyWith(fontSize: 10.5, color: AppColors.muted)),
                ]),
              ),
            ]),
          ),
        ),
    ];
  }

  Widget _statKoleksi(String nilai, String label) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nilai, style: AppTextStyles.headlineSm.copyWith(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w800)),
            Text(label, style: AppTextStyles.bodySm.copyWith(color: Colors.white70, fontSize: 11)),
          ]),
        ),
      );

  List<Widget> _favoritList() {
    final d = _favorit!;
    if (d.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text('Belum ada favorit. Ketuk ikon hati pada karya yang kamu suka.', textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
        ),
      ];
    }
    return [
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: d.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: AppSpacing.sm, mainAxisSpacing: AppSpacing.sm, childAspectRatio: 0.78),
        itemBuilder: (context, i) {
          final k = d[i];
          return GestureDetector(
            onTap: () => widget.onKaryaTap?.call(k),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Stack(fit: StackFit.expand, children: [
                    KaryaImage(karya: k),
                    Positioned(top: 6, right: 6, child: FavoritHati(karya: k)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(k.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.labelMd.copyWith(fontSize: 13, fontWeight: FontWeight.w800)),
                    Text(k.artistName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted)),
                    Text(k.terjual ? 'Terjual' : k.priceFormatted, style: AppTextStyles.labelMd.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: k.terjual ? AppColors.muted : const Color(0xFF3E251E))),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    ];
  }
}

class _SertifikatSheet extends StatefulWidget {
  const _SertifikatSheet({required this.artworkId, required this.judul, required this.service});

  final String artworkId, judul;
  final FavoritService service;

  @override
  State<_SertifikatSheet> createState() => _SertifikatSheetState();
}

class _SertifikatSheetState extends State<_SertifikatSheet> {
  HasilSertifikat? _h;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.service.periksaSertifikat(widget.artworkId).then((h) {
      if (mounted) setState(() => _h = h);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = _h;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sertifikat Digital Keaslian', style: AppTextStyles.headlineMd),
        Text(widget.judul, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
        const SizedBox(height: AppSpacing.sm),
        if (_error != null)
          Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error))
        else if (h == null)
          const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Center(child: CircularProgressIndicator()))
        else ...[
          Row(children: [
            Icon(h.valid ? Icons.verified : Icons.warning_amber_rounded, color: h.valid ? AppColors.accent : AppColors.error, size: 28),
            const SizedBox(width: 8),
            Text(h.valid ? 'VALID' : 'TIDAK VALID', style: AppTextStyles.headlineMd.copyWith(color: h.valid ? AppColors.accent : AppColors.error)),
          ]),
          const SizedBox(height: AppSpacing.xs),
          _baris('Data sertifikat tidak berubah', h.hashCocok),
          _baris('Tanda tangan digital sah', h.signatureValid),
          if (h.keyDicabut) Text('Peringatan: kunci penandatangan sudah dicabut.', style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
          const SizedBox(height: 4),
          Text('ID ${h.artworkId} · diverifikasi ${formatTanggal(h.diverifikasi)} · ${h.jumlahPemilik} catatan kepemilikan', style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: AppSpacing.xs),
          Text('Ini bukti registrasi kepemilikan digital di GALERIA, bukan pemeriksaan keaslian fisik lukisan.', style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted)),
        ],
        const SizedBox(height: AppSpacing.md),
      ]),
    );
  }

  Widget _baris(String teks, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, size: 18, color: ok ? AppColors.accent : AppColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(teks, style: AppTextStyles.bodySm)),
        ]),
      );
}
