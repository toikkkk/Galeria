import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/event.dart';
import '../../models/karya.dart';
import '../../models/komunitas.dart';
import '../../services/komunitas_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/format_waktu.dart';
import '../../widgets/event_widgets.dart';
import '../../widgets/karya_image.dart';
import '../../widgets/pesanan_widgets.dart';

/// Halaman satu komunitas: Diskusi (postingan, foto, suka, komentar), Karya anggota, Event komunitas, dan Anggota.
/// Komunitas tertutup mengunci isi untuk yang bukan anggota. Semua data dari server.
class CommunityDetailScreen extends StatefulWidget {
  const CommunityDetailScreen({
    super.key,
    required this.komunitasId,
    required this.onBack,
    this.onBuatEvent,
    this.onEventTap,
    this.onKaryaTap,
    KomunitasService? service,
  }) : _service = service;

  final String komunitasId;
  final VoidCallback onBack;

  /// Pemilik membuat event atas nama komunitas ini.
  final ValueChanged<Komunitas>? onBuatEvent;
  final ValueChanged<EventInfo>? onEventTap;
  final ValueChanged<Karya>? onKaryaTap;
  final KomunitasService? _service;

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  late final KomunitasService _service = widget._service ?? KomunitasService();
  Komunitas? _k;
  bool _memuat = true;
  String? _error;
  bool _sibuk = false;
  int _tab = 0;

  // tab
  final List<PostKomunitas> _posts = [];
  bool _adaLagi = false;
  bool _memuatPost = false;
  List<Karya>? _karya;
  List<EventInfo>? _event;
  DaftarAnggota? _anggota;
  String? _errorTab;

  // composer
  final _teks = TextEditingController();
  XFile? _foto;
  bool _mengirim = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _teks.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final k = await _service.detail(widget.komunitasId);
      if (!mounted) return;
      setState(() => _k = k);
      await _muatTab();
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat komunitas: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _muatTab({bool lagi = false}) async {
    final k = _k;
    if (k == null || !k.bisaLihatIsi) return;
    setState(() => _errorTab = null);
    try {
      switch (_tab) {
        case 0:
          setState(() => _memuatPost = true);
          final h = await _service.post(k.id, sebelum: lagi && _posts.isNotEmpty ? _posts.where((p) => !p.disematkan).lastOrNull?.waktu : null);
          if (!mounted) return;
          setState(() {
            if (!lagi) _posts.clear();
            _posts.addAll(h.items);
            _adaLagi = h.adaLagi;
          });
        case 1:
          final d = await _service.karya(k.id);
          if (mounted) setState(() => _karya = d);
        case 2:
          final d = await _service.event(k.id);
          if (mounted) setState(() => _event = d);
        case 3:
          final d = await _service.anggota(k.id);
          if (mounted) setState(() => _anggota = d);
      }
    } catch (e) {
      if (mounted) setState(() => _errorTab = e.toString());
    } finally {
      if (mounted) setState(() => _memuatPost = false);
    }
  }

  Future<void> _aksiKomunitas(Future<Komunitas> Function() kerja) async {
    setState(() => _sibuk = true);
    try {
      final k = await kerja();
      if (!mounted) return;
      setState(() => _k = k);
      await _muatTab();
    } catch (e) {
      if (mounted) tampilkanPesan(context, e.toString());
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _gabung(Komunitas k) async {
    // tamu ditolak server (401) dengan pesan "Belum masuk", ditampilkan oleh _aksiKomunitas
    await _aksiKomunitas(() => _service.gabung(k.id));
    final baru = _k;
    if (baru != null && mounted) {
      tampilkanPesan(context, baru.menunggu ? 'Permintaan terkirim. Menunggu persetujuan pemilik.' : 'Kamu bergabung di ${baru.nama}.');
    }
  }

  Future<void> _keluar(Komunitas k) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(k.menunggu ? 'Batalkan permintaan?' : 'Keluar dari komunitas?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya')),
        ],
      ),
    );
    if (ya == true) await _aksiKomunitas(() => _service.keluar(k.id));
  }

  Future<void> _pilihFoto() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000);
      if (f != null && mounted) setState(() => _foto = f);
    } catch (e) {
      if (mounted) tampilkanPesan(context, 'Gagal membuka galeri: $e');
    }
  }

  Future<void> _kirimPost(Komunitas k) async {
    final t = _teks.text.trim();
    if (t.isEmpty) {
      tampilkanPesan(context, 'Tulis sesuatu dulu.');
      return;
    }
    setState(() => _mengirim = true);
    try {
      final foto = _foto;
      final p = foto == null ? await _service.tulisPost(k.id, t) : await _service.tulisPostFoto(k.id, t, await foto.readAsBytes(), foto.name);
      if (!mounted) return;
      setState(() {
        _posts.insert(_posts.where((x) => x.disematkan).length, p);
        _teks.clear();
        _foto = null;
      });
    } catch (e) {
      if (mounted) tampilkanPesan(context, e.toString());
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  Future<void> _like(PostKomunitas p) async {
    try {
      final (saya, n) = await _service.like(p.id);
      if (mounted) {
        setState(() {
          p.sayaLike = saya;
          p.jumlahLike = n;
        });
      }
    } catch (e) {
      if (mounted) tampilkanPesan(context, e.toString());
    }
  }

  Future<void> _hapus(PostKomunitas p) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus postingan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ya != true) return;
    try {
      await _service.hapusPost(p.id);
      if (mounted) setState(() => _posts.removeWhere((x) => x.id == p.id));
    } catch (e) {
      if (mounted) tampilkanPesan(context, e.toString());
    }
  }

  Future<void> _sematkan(PostKomunitas p) async {
    try {
      await _service.sematkan(p.id);
      await _muatTab();
    } catch (e) {
      if (mounted) tampilkanPesan(context, e.toString());
    }
  }

  Future<void> _komentar(PostKomunitas p, Komunitas k) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => _KomentarSheet(post: p, bisaKomentar: k.anggotaAktif, service: _service, onUbah: (n) => setState(() => p.jumlahKomentar = n)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = _k;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text(k?.nama ?? 'Komunitas', style: AppTextStyles.headlineSm, overflow: TextOverflow.ellipsis),
        actions: [IconButton(onPressed: _memuat ? null : _muat, icon: const Icon(Icons.refresh))],
      ),
      body: _memuat && k == null
          ? const Center(child: CircularProgressIndicator())
          : k == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error ?? 'Komunitas tidak ditemukan.', textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                      OutlinedButton(onPressed: _muat, child: const Text('Coba lagi')),
                    ]),
                  ),
                )
              : RefreshIndicator(onRefresh: _muat, child: _isi(k)),
    );
  }

  Widget _isi(Komunitas k) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: [
        _header(k),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (i, label) in const ['Diskusi', 'Karya', 'Event', 'Anggota'].indexed)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: ChoiceChip(
                  label: Text(i == 3 && k.pemilik && (k.jumlahPermintaan ?? 0) > 0 ? 'Anggota (${k.jumlahPermintaan})' : label),
                  selected: _tab == i,
                  onSelected: (_) {
                    setState(() => _tab = i);
                    _muatTab();
                  },
                ),
              ),
          ]),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!k.bisaLihatIsi)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Column(children: [
              const Icon(Icons.lock_outline, size: 32, color: AppColors.muted),
              const SizedBox(height: 6),
              Text(
                k.menunggu ? 'Permintaanmu sedang menunggu persetujuan pemilik.' : 'Komunitas ini tertutup. Ajukan permintaan bergabung untuk melihat isinya.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
              ),
            ]),
          )
        else if (_errorTab != null)
          Column(children: [
            Text(_errorTab!, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
            OutlinedButton(onPressed: _muatTab, child: const Text('Coba lagi')),
          ])
        else
          switch (_tab) {
            0 => _diskusi(k),
            1 => _tabKarya(),
            2 => _tabEvent(k),
            _ => _tabAnggota(k),
          },
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _header(Komunitas k) {
    final String? label = k.pemilik ? null : (k.anggotaAktif ? 'Keluar' : (k.menunggu ? 'Batalkan permintaan' : (k.terbuka ? 'Bergabung' : 'Ajukan bergabung')));
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Text(k.inisial, style: AppTextStyles.headlineMd.copyWith(color: const Color(0xFFECC246))),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k.nama, style: AppTextStyles.headlineSm),
              Text('${k.jumlahAnggota} anggota · ${k.terbuka ? 'Terbuka' : 'Tertutup'} · oleh ${k.pemilikNama}', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
              Text('Dibuat ${formatTanggal(k.dibuat)}', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
            ]),
          ),
        ]),
        if (k.deskripsi != null) ...[const SizedBox(height: AppSpacing.xs), Text(k.deskripsi!, style: AppTextStyles.bodySm)],
        if (k.aliran.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final a in k.aliran)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.accentSoft.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(AppRadius.full)),
                child: Text(a, style: AppTextStyles.bodySm.copyWith(fontSize: 10.5)),
              ),
          ]),
        ],
        if (k.aturan != null && k.aturan!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text('Aturan komunitas', style: AppTextStyles.labelMd.copyWith(fontSize: 12.5)),
              children: [Align(alignment: Alignment.centerLeft, child: Text(k.aturan!, style: AppTextStyles.bodySm))],
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Row(children: [
          if (label != null)
            Expanded(
              child: k.anggotaAktif || k.menunggu
                  ? OutlinedButton(key: const Key('keluar_komunitas'), onPressed: _sibuk ? null : () => _keluar(k), child: Text(label))
                  : ElevatedButton(key: const Key('gabung_komunitas'), onPressed: _sibuk ? null : () => _gabung(k), child: Text(label)),
            ),
          if (k.pemilik)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => widget.onBuatEvent?.call(k),
                icon: const Icon(Icons.event_note_outlined, size: 18),
                label: const Text('Buat event komunitas'),
              ),
            ),
        ]),
      ]),
    );
  }

  // ------------------------------------------------------------- tab Diskusi
  Widget _diskusi(Komunitas k) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (k.anggotaAktif)
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Column(children: [
            TextField(
              key: const Key('teks_post'),
              controller: _teks,
              enabled: !_mengirim,
              maxLines: 3,
              minLines: 1,
              maxLength: 1000,
              decoration: const InputDecoration(hintText: 'Bagikan proses atau karyamu...', border: InputBorder.none, counterText: ''),
            ),
            if (_foto != null)
              Align(
                alignment: Alignment.centerLeft,
                child: InputChip(label: Text(_foto!.name, overflow: TextOverflow.ellipsis), onDeleted: _mengirim ? null : () => setState(() => _foto = null), avatar: const Icon(Icons.image_outlined, size: 16)),
              ),
            Row(children: [
              IconButton(onPressed: _mengirim ? null : _pilihFoto, icon: const Icon(Icons.add_photo_alternate_outlined), tooltip: 'Tambah foto'),
              const Spacer(),
              FilledButton(
                key: const Key('kirim_post'),
                onPressed: _mengirim ? null : () => _kirimPost(k),
                child: _mengirim ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Kirim'),
              ),
            ]),
          ]),
        )
      else
        Text('Bergabunglah untuk ikut berdiskusi.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
      const SizedBox(height: AppSpacing.sm),
      if (_posts.isEmpty && !_memuatPost)
        Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Center(child: Text('Belum ada postingan.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted))))
      else
        for (final p in _posts) _PostKartu(post: p, onLike: () => _like(p), onKomentar: () => _komentar(p, k), onHapus: () => _hapus(p), onSematkan: () => _sematkan(p), bisaLike: k.anggotaAktif),
      if (_memuatPost) const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Center(child: CircularProgressIndicator())),
      if (_adaLagi && !_memuatPost) Center(child: OutlinedButton(onPressed: () => _muatTab(lagi: true), child: const Text('Muat lebih banyak'))),
    ]);
  }

  // ------------------------------------------------------------- tab Karya
  Widget _tabKarya() {
    final d = _karya;
    if (d == null) return const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Center(child: CircularProgressIndicator()));
    if (d.isEmpty) return Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Center(child: Text('Belum ada karya terverifikasi dari anggota.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted))));
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: d.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: AppSpacing.sm, mainAxisSpacing: AppSpacing.sm, childAspectRatio: 0.8),
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => widget.onKaryaTap?.call(d[i]),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: SizedBox.expand(child: KaryaImage(karya: d[i]))),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.labelMd.copyWith(fontSize: 12.5)),
                Text(d[i].artistName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted)),
                Text(d[i].terjual ? 'Terjual' : formatRupiah(d[i].priceIdr), style: AppTextStyles.bodySm.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- tab Event
  Widget _tabEvent(Komunitas k) {
    final d = _event;
    if (d == null) return const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Center(child: CircularProgressIndicator()));
    if (d.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(child: Text(k.pemilik ? 'Belum ada event. Buat event atas nama komunitas ini.' : 'Belum ada event komunitas.', textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted))),
      );
    }
    return Column(children: [
      for (final e in d)
        GestureDetector(
          onTap: () => widget.onEventTap?.call(e),
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  StatusEventChip(status: e.status),
                  Text(e.judul, style: AppTextStyles.labelMd),
                  Text('${formatTanggal(e.mulai)} · ${e.lokasi}', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
                ]),
              ),
              Text(e.gratis ? 'Gratis' : formatRupiah(e.hargaMulaiIdr), style: AppTextStyles.labelMd.copyWith(color: AppColors.accent, fontSize: 12.5)),
            ]),
          ),
        ),
    ]);
  }

  // ------------------------------------------------------------- tab Anggota
  Widget _tabAnggota(Komunitas k) {
    final d = _anggota;
    if (d == null) return const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Center(child: CircularProgressIndicator()));
    Future<void> aksi(Future<void> Function() f) async {
      try {
        await f();
        await _muat();
      } catch (e) {
        if (mounted) tampilkanPesan(context, e.toString());
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (k.pemilik && d.permintaan.isNotEmpty) ...[
        Text('Permintaan bergabung (${d.permintaan.length})', style: AppTextStyles.headlineSm),
        const SizedBox(height: AppSpacing.xs),
        for (final a in d.permintaan)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Row(children: [
              Expanded(child: Text(a.nama, style: AppTextStyles.labelMd.copyWith(fontSize: 13))),
              TextButton(onPressed: () => aksi(() => _service.tolak(k.id, a.userId)), child: const Text('Tolak', style: TextStyle(color: AppColors.error))),
              FilledButton(onPressed: () => aksi(() => _service.setujui(k.id, a.userId)), child: const Text('Setujui')),
            ]),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
      Text('Anggota (${d.anggota.length})', style: AppTextStyles.headlineSm),
      const SizedBox(height: AppSpacing.xs),
      for (final a in d.anggota)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Row(children: [
            CircleAvatar(radius: 16, backgroundColor: AppColors.primary, child: Text(a.nama.isEmpty ? '?' : a.nama[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13))),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(a.nama, style: AppTextStyles.labelMd.copyWith(fontSize: 13))),
            if (a.peran == 'pemilik') Text('PEMILIK', style: AppTextStyles.overline.copyWith(fontSize: 8.5, color: AppColors.accent)),
            if (k.pemilik && a.peran != 'pemilik')
              IconButton(
                onPressed: () => aksi(() => _service.keluarkan(k.id, a.userId)),
                icon: const Icon(Icons.person_remove_outlined, size: 18, color: AppColors.error),
                tooltip: 'Keluarkan',
              ),
          ]),
        ),
    ]);
  }
}

class _PostKartu extends StatelessWidget {
  const _PostKartu({required this.post, required this.onLike, required this.onKomentar, required this.onHapus, required this.onSematkan, required this.bisaLike});

  final PostKomunitas post;
  final VoidCallback onLike, onKomentar, onHapus, onSematkan;
  final bool bisaLike;

  @override
  Widget build(BuildContext context) {
    final p = post;
    final karya = p.imageUrl == null
        ? null
        : Karya(assetPath: '', imageUrl: p.imageUrl, title: '', artistName: '', styleName: '', priceIdr: 0, galleryName: '');
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: p.disematkan ? Border.all(color: AppColors.accent.withValues(alpha: 0.6)) : null,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (p.disematkan)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              const Icon(Icons.push_pin, size: 12, color: AppColors.accent),
              const SizedBox(width: 4),
              Text('DISEMATKAN', style: AppTextStyles.overline.copyWith(fontSize: 8.5, color: AppColors.accent)),
            ]),
          ),
        Row(children: [
          CircleAvatar(radius: 15, backgroundColor: AppColors.primary, child: Text(p.penulisNama.isEmpty ? '?' : p.penulisNama[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(p.penulisNama, style: AppTextStyles.labelMd.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis)),
                if (p.penulisPemilik) ...[const SizedBox(width: 4), const Icon(Icons.verified, size: 13, color: AppColors.accent)],
              ]),
              Text(waktuRelatif(p.waktu), style: AppTextStyles.bodySm.copyWith(fontSize: 10.5, color: AppColors.muted)),
            ]),
          ),
          if (p.bisaHapus || p.bisaSematkan)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'hapus' ? onHapus() : onSematkan(),
              itemBuilder: (_) => [
                if (p.bisaSematkan) PopupMenuItem(value: 'sematkan', child: Text(p.disematkan ? 'Lepas sematan' : 'Sematkan')),
                if (p.bisaHapus) const PopupMenuItem(value: 'hapus', child: Text('Hapus')),
              ],
            ),
        ]),
        const SizedBox(height: 6),
        Text(p.teks, style: AppTextStyles.bodyMd),
        if (karya != null) ...[
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(AppRadius.sm), child: AspectRatio(aspectRatio: 4 / 3, child: SizedBox.expand(child: KaryaImage(karya: karya)))),
        ],
        const SizedBox(height: 4),
        Row(children: [
          InkWell(
            onTap: bisaLike ? onLike : null,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(children: [
                Icon(p.sayaLike ? Icons.favorite : Icons.favorite_border, size: 18, color: p.sayaLike ? AppColors.error : AppColors.muted),
                const SizedBox(width: 4),
                Text('${p.jumlahLike}', style: AppTextStyles.labelSm.copyWith(color: AppColors.muted)),
              ]),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          InkWell(
            onTap: onKomentar,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(children: [
                const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.muted),
                const SizedBox(width: 4),
                Text('${p.jumlahKomentar}', style: AppTextStyles.labelSm.copyWith(color: AppColors.muted)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _KomentarSheet extends StatefulWidget {
  const _KomentarSheet({required this.post, required this.bisaKomentar, required this.service, required this.onUbah});

  final PostKomunitas post;
  final bool bisaKomentar;
  final KomunitasService service;
  final ValueChanged<int> onUbah;

  @override
  State<_KomentarSheet> createState() => _KomentarSheetState();
}

class _KomentarSheetState extends State<_KomentarSheet> {
  final _teks = TextEditingController();
  List<KomentarKomunitas>? _data;
  bool _kirim = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _teks.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final d = await widget.service.komentar(widget.post.id);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _kirimKomentar() async {
    final t = _teks.text.trim();
    if (t.isEmpty) return;
    setState(() => _kirim = true);
    try {
      final c = await widget.service.tulisKomentar(widget.post.id, t);
      if (!mounted) return;
      setState(() {
        _data = [...?_data, c];
        _teks.clear();
        _error = null;
      });
      widget.onUbah(_data!.length);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _kirim = false);
    }
  }

  Future<void> _hapus(KomentarKomunitas c) async {
    try {
      await widget.service.hapusKomentar(c.id);
      if (!mounted) return;
      setState(() => _data = _data!.where((x) => x.id != c.id).toList());
      widget.onUbah(_data!.length);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.screenGutter, AppSpacing.md, AppSpacing.screenGutter, MediaQuery.of(context).viewInsets.bottom + AppSpacing.md),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Komentar', style: AppTextStyles.headlineMd),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: _data == null
                ? const Center(child: CircularProgressIndicator())
                : _data!.isEmpty
                    ? Center(child: Text('Belum ada komentar.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)))
                    : ListView(children: [
                        for (final c in _data!)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(c.penulisNama, style: AppTextStyles.labelMd.copyWith(fontSize: 13)),
                            subtitle: Text('${c.teks}\n${waktuRelatif(c.waktu)}', style: AppTextStyles.bodySm),
                            isThreeLine: true,
                            trailing: c.bisaHapus ? IconButton(onPressed: () => _hapus(c), icon: const Icon(Icons.delete_outline, size: 18)) : null,
                          ),
                      ]),
          ),
          if (_error != null) Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
          if (widget.bisaKomentar)
            Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('teks_komentar'),
                  controller: _teks,
                  enabled: !_kirim,
                  maxLength: 500,
                  decoration: const InputDecoration(hintText: 'Tulis komentar...', counterText: '', isDense: true, filled: true, fillColor: Colors.white),
                ),
              ),
              IconButton(key: const Key('kirim_komentar'), onPressed: _kirim ? null : _kirimKomentar, icon: const Icon(Icons.send)),
            ])
          else
            Text('Bergabunglah untuk berkomentar.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
        ]),
      ),
    );
  }
}
