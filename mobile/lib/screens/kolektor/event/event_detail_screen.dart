import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/event.dart';
import '../../../services/auth_service.dart';
import '../../../services/event_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../utils/format_waktu.dart';
import '../../../widgets/event_widgets.dart';
import '../../../widgets/karya_image.dart';
import '../../../models/karya.dart';
import '../../../widgets/pesanan_widgets.dart';

/// Detail satu event (publik). Kolektor membeli tiket dari sini; penyelenggara melihat statistik & tombol kelola.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.eventId,
    required this.onBack,
    this.onBeli,
    this.onLogin,
    this.onKelola,
    this.onTiketSaya,
    EventService? service,
  }) : _service = service;

  final String eventId;
  final VoidCallback onBack;
  final ValueChanged<EventInfo>? onBeli;
  final VoidCallback? onLogin;
  final ValueChanged<EventInfo>? onKelola;
  final VoidCallback? onTiketSaya;
  final EventService? _service;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final EventService _service = widget._service ?? EventService();
  EventInfo? _e;
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
      final e = await _service.detail(widget.eventId);
      if (mounted) setState(() => _e = e);
    } catch (err) {
      if (mounted) setState(() => _error = 'Gagal memuat event: $err');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  void _beli(EventInfo e) {
    final u = AuthService.instance.user;
    if (u == null || !AuthService.instance.loggedIn) {
      tampilkanPesan(context, 'Masuk dulu untuk membeli tiket.');
      widget.onLogin?.call();
      return;
    }
    if (u.isSeniman) {
      tampilkanPesan(context, 'Akun seniman tidak membeli tiket. Daftar sebagai kolektor untuk ikut event.');
      return;
    }
    widget.onBeli?.call(e);
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Detail Event', style: AppTextStyles.headlineSm),
        actions: [IconButton(onPressed: _memuat ? null : _muat, icon: const Icon(Icons.refresh))],
      ),
      body: _memuat && e == null
          ? const Center(child: CircularProgressIndicator())
          : e == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error ?? 'Event tidak ditemukan.', textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(onPressed: _muat, child: const Text('Coba lagi')),
                    ]),
                  ),
                )
              : RefreshIndicator(onRefresh: _muat, child: _isi(e)),
      bottomNavigationBar: e == null ? null : _aksi(e),
    );
  }

  Widget _isi(EventInfo e) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: [
        Row(children: [StatusEventChip(status: e.status), if (e.tema != null) ...[const SizedBox(width: 6), Text(e.tema!, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted))]]),
        const SizedBox(height: 6),
        Text(e.judul, style: AppTextStyles.headlineLg),
        Text('oleh ${e.penyelenggara}', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
        const SizedBox(height: AppSpacing.sm),
        _info(Icons.event, '${formatTanggal(e.mulai)} · ${jamMenit(e.mulai)} - ${jamMenit(e.selesai)}'),
        _info(e.online ? Icons.videocam_outlined : Icons.place_outlined, e.lokasi),
        if (!e.online && e.alamat != null) _info(Icons.map_outlined, e.alamat!),
        if (e.online)
          e.linkOnline != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    const Icon(Icons.link, size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(child: SelectableText(e.linkOnline!, style: AppTextStyles.bodySm.copyWith(color: AppColors.accent))),
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: e.linkOnline!));
                        if (mounted) tampilkanPesan(context, 'Tautan disalin.');
                      },
                      icon: const Icon(Icons.copy, size: 16),
                    ),
                  ]),
                )
              : _info(Icons.lock_outline, 'Tautan dikirim setelah kamu memiliki tiket.'),
        if (e.deskripsi != null && e.deskripsi!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(e.deskripsi!, style: AppTextStyles.bodyMd),
        ],
        const SizedBox(height: AppSpacing.md),
        Text('Tiket', style: AppTextStyles.headlineSm),
        const SizedBox(height: AppSpacing.xs),
        for (final t in e.tiket)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.nama, style: AppTextStyles.labelMd),
                  if (t.keterangan != null) Text(t.keterangan!, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
                  Text(t.habis ? 'Habis' : 'Sisa ${t.sisa} dari ${t.kuota}', style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: t.habis ? AppColors.error : AppColors.muted)),
                ]),
              ),
              Text(t.gratis ? 'Gratis' : formatRupiah(t.hargaIdr), style: AppTextStyles.labelMd.copyWith(color: AppColors.accent)),
            ]),
          ),
        if (e.karya.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Karya yang Dipamerkan', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: e.karya.length,
              separatorBuilder: (context, i) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, i) {
                final k = e.karya[i];
                return SizedBox(
                  width: 110,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: SizedBox.expand(
                          child: KaryaImage(karya: Karya(
                            assetPath: 'assets/images/catalog/${k.imageFilename ?? ''}', imageUrl: k.imageUrl, title: k.title,
                            artistName: k.artistName, styleName: k.styleName, priceIdr: k.priceIdr, galleryName: e.penyelenggara,
                          )),
                        ),
                      ),
                    ),
                    Text(k.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.labelSm.copyWith(fontSize: 11)),
                  ]),
                );
              },
            ),
          ),
        ],
        if (e.sayaPenyelenggara && e.tiketTerjual != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(children: [
              _stat('${e.tiketTerjual}', 'Tiket terjual'),
              _stat(formatRupiah(e.pendapatanIdr ?? 0), 'Pendapatan'),
              _stat('${e.sudahCheckin}', 'Sudah check-in'),
            ]),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: AppTextStyles.labelMd, textAlign: TextAlign.center),
          Text(l, style: AppTextStyles.bodySm.copyWith(fontSize: 10, color: AppColors.muted), textAlign: TextAlign.center),
        ]),
      );

  Widget _info(IconData i, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: AppTextStyles.bodySm)),
        ]),
      );

  Widget? _aksi(EventInfo e) {
    Widget? b;
    if (e.sayaPenyelenggara) {
      b = ElevatedButton.icon(onPressed: () => widget.onKelola?.call(e), icon: const Icon(Icons.qr_code_scanner, size: 18), label: const Text('Kelola event & check-in'));
    } else if (e.sayaPunyaTiket) {
      b = OutlinedButton.icon(onPressed: widget.onTiketSaya, icon: const Icon(Icons.confirmation_number_outlined, size: 18), label: const Text('Lihat tiket saya'));
    } else if (!e.bisaBeli) {
      b = null;
    } else {
      b = ElevatedButton(
        key: const Key('beli_tiket'),
        onPressed: e.totalSisa <= 0 ? null : () => _beli(e),
        child: Text(e.totalSisa <= 0 ? 'Tiket habis' : (e.gratis ? 'Daftar Gratis' : 'Beli Tiket · mulai ${formatRupiah(e.hargaMulaiIdr)}')),
      );
    }
    if (b == null) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter, AppSpacing.xs, AppSpacing.screenGutter, AppSpacing.sm),
        child: SizedBox(width: double.infinity, child: b),
      ),
    );
  }
}
