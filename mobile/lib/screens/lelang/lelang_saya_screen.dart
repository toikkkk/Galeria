import 'package:flutter/material.dart';

import '../../models/lelang.dart';
import '../../services/lelang_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/commerce_widgets.dart';
import '../../widgets/lelang_widgets.dart';

/// Lelang milik seniman yang login (`GET /api/lelang/saya`), semua status.
/// Ringkasan di atas, filter status, lalu kartu yang menonjolkan perkembangan tawaran.
class LelangSayaScreen extends StatefulWidget {
  const LelangSayaScreen({super.key, required this.onBack, required this.onDetail, this.onBuat, LelangService? service})
      : _service = service;

  final VoidCallback onBack;
  final ValueChanged<Lelang> onDetail;
  final VoidCallback? onBuat;
  final LelangService? _service;

  @override
  State<LelangSayaScreen> createState() => _LelangSayaScreenState();
}

class _LelangSayaScreenState extends State<LelangSayaScreen> {
  late final LelangService _service = widget._service ?? LelangService();
  List<Lelang> _data = [];
  bool _memuat = true;
  String? _error;
  String _filter = 'semua';

  static const _filters = [
    ('semua', 'Semua'),
    ('berlangsung', 'Berlangsung'),
    ('akan_datang', 'Segera'),
    ('selesai', 'Selesai'),
    ('dibatalkan', 'Dibatalkan'),
  ];

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
      final d = await _service.saya();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat lelang: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  int _jumlah(String f) => f == 'semua' ? _data.length : _data.where((l) => l.statusSekarang == f).length;

  @override
  Widget build(BuildContext context) {
    final tampil = _filter == 'semua' ? _data : _data.where((l) => l.statusSekarang == _filter).toList();
    return Scaffold(
      backgroundColor: kLatarMarketplace,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Lelang Saya', style: AppTextStyles.headlineSm),
        actions: [IconButton(onPressed: widget.onBuat, icon: const Icon(Icons.add), tooltip: 'Buat lelang')],
      ),
      floatingActionButton: _data.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: widget.onBuat,
              backgroundColor: const Color(0xFF3E251E),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.gavel, size: 18),
              label: const Text('Buat Lelang', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 88),
          children: [
            if (_error != null)
              Column(children: [
                Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                OutlinedButton.icon(onPressed: _muat, icon: const Icon(Icons.refresh, size: 16), label: const Text('Coba Lagi')),
              ])
            else if (_memuat && _data.isEmpty)
              const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator()))
            else if (_data.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    const CircleAvatar(radius: 34, backgroundColor: AppColors.surfaceContainerHigh, child: Icon(Icons.gavel, size: 30, color: AppColors.muted)),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Kamu belum membuat lelang.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                    const SizedBox(height: AppSpacing.xs),
                    FilledButton.icon(onPressed: widget.onBuat, icon: const Icon(Icons.gavel), label: const Text('Buat lelang')),
                  ],
                ),
              )
            else ...[
              _Ringkasan(data: _data),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final (kunci, label) = _filters[i];
                    final aktif = _filter == kunci;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = kunci),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: aktif ? const Color(0xFF3E251E) : Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(color: aktif ? const Color(0xFF3E251E) : AppColors.border),
                        ),
                        child: Text(
                          '$label ${_jumlah(kunci)}',
                          style: AppTextStyles.labelMd.copyWith(fontSize: 12.5, color: aktif ? Colors.white : AppColors.onSurface, fontWeight: aktif ? FontWeight.w800 : FontWeight.w600),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (tampil.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: Text('Tidak ada lelang pada status ini.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted))),
                )
              else
                for (final l in tampil) _KartuLelangSaya(lelang: l, onTap: () => widget.onDetail(l), onHabis: _muat),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kartu ringkasan: lelang aktif, total tawaran, dan nilai tawaran tertinggi yang sedang berjalan.
class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.data});

  final List<Lelang> data;

  @override
  Widget build(BuildContext context) {
    final aktif = data.where((l) => l.statusSekarang == 'berlangsung').toList();
    final totalBid = data.fold<int>(0, (a, l) => a + l.jumlahBid);
    final nilai = aktif.fold<int>(0, (a, l) => a + (l.jumlahBid > 0 ? l.hargaSaatIniIdr : 0));
    final segera = data.where((l) => l.statusSekarang == 'akan_datang').length;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4D2F26), Color(0xFF2F1B15)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.gavel, size: 15, color: Color(0xFFF0C86A)),
            const SizedBox(width: 6),
            Text('NILAI TAWARAN AKTIF', style: AppTextStyles.overline.copyWith(color: Colors.white70, fontSize: 10)),
          ]),
          const SizedBox(height: 4),
          Text(formatRupiah(nilai), style: AppTextStyles.headlineSm.copyWith(fontSize: 26, color: const Color(0xFFF0C86A), fontWeight: FontWeight.w800)),
          Text('Jumlah bid tertinggi dari lelang yang sedang berlangsung', style: AppTextStyles.bodySm.copyWith(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            _Stat(nilai: '${aktif.length}', label: 'Berlangsung'),
            _Stat(nilai: '$segera', label: 'Segera'),
            _Stat(nilai: '$totalBid', label: 'Total bid'),
          ]),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.nilai, required this.label});

  final String nilai, label;

  @override
  Widget build(BuildContext context) => Expanded(
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
}

/// Kartu lelang untuk sudut pandang penjual: harga awal -> tertinggi, kenaikan, progres waktu, pemenang.
class _KartuLelangSaya extends StatelessWidget {
  const _KartuLelangSaya({required this.lelang, required this.onTap, this.onHabis});

  final Lelang lelang;
  final VoidCallback onTap;
  final VoidCallback? onHabis;

  double get _progres {
    final total = lelang.selesai.difference(lelang.mulai).inSeconds;
    if (total <= 0) return 1;
    return (lelang.sekarangServer.difference(lelang.mulai).inSeconds / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final l = lelang;
    final st = l.statusSekarang;
    final info = infoStatusLelang(st);
    final mendesak = st == 'berlangsung' && l.sisa < const Duration(hours: 1);
    final adaBid = l.jumlahBid > 0;
    final naik = adaBid && l.hargaAwalIdr > 0 ? ((l.hargaSaatIniIdr - l.hargaAwalIdr) * 100 / l.hargaAwalIdr) : 0.0;
    const kopi = Color(0xFF3E251E);
    const emas = Color(0xFFB07D12);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SizedBox(
              height: 148,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 112,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        LelangGambar(lelang: l),
                        Positioned(
                          left: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: info.warna, borderRadius: BorderRadius.circular(AppRadius.full)),
                            child: Text(info.label, style: AppTextStyles.overline.copyWith(fontSize: 8, color: info.warna == AppColors.accent ? AppColors.onSurface : Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.judul, style: AppTextStyles.labelMd.copyWith(fontSize: 15, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 1),
                          Text(
                            [l.styleName, if (l.lebarCm != null && l.tinggiCm != null) '${l.lebarCm!.round()}×${l.tinggiCm!.round()} cm'].join(' · '),
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Text(adaBid ? 'Bid tertinggi' : 'Harga awal', style: AppTextStyles.bodySm.copyWith(fontSize: 10.5, color: AppColors.muted)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(formatRupiah(l.hargaSaatIniIdr),
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.headlineSm.copyWith(fontSize: 19, color: kopi, fontWeight: FontWeight.w800)),
                              ),
                              if (adaBid) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFF7E7C1), borderRadius: BorderRadius.circular(AppRadius.full)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.trending_up, size: 12, color: Color(0xFF7A5410)),
                                    const SizedBox(width: 2),
                                    Text('+${naik.round()}%', style: AppTextStyles.labelSm.copyWith(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF7A5410))),
                                  ]),
                                ),
                              ],
                            ],
                          ),
                          if (adaBid) Text('Awal ${formatRupiah(l.hargaAwalIdr)}', style: AppTextStyles.bodySm.copyWith(fontSize: 10.5, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // dasar kartu: bid, waktu/pemenang, dan progres
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 8, AppSpacing.sm, 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Column(
                children: [
                  Row(children: [
                    const Icon(Icons.groups_2_outlined, size: 16, color: kopi),
                    const SizedBox(width: 5),
                    Text('${l.jumlahBid} bid', style: AppTextStyles.labelMd.copyWith(fontSize: 12.5, fontWeight: FontWeight.w800, color: kopi)),
                    const Spacer(),
                    if (st == 'selesai' || st == 'dibatalkan')
                      Flexible(
                        child: Text(
                          st == 'dibatalkan' ? 'Dibatalkan' : (l.pemenangNama != null ? 'Pemenang: ${l.pemenangNama}' : 'Berakhir tanpa pemenang'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelMd.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: st == 'dibatalkan' ? AppColors.error : emas),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: mendesak ? AppColors.error : kopi, borderRadius: BorderRadius.circular(AppRadius.full)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.timer_outlined, size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          HitungMundur(lelang: l, onHabis: onHabis, style: AppTextStyles.labelSm.copyWith(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                  ]),
                  if (st == 'berlangsung') ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: _progres,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE6DFD5),
                        valueColor: AlwaysStoppedAnimation(mendesak ? AppColors.error : const Color(0xFFDBA12C)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
