import 'package:flutter/material.dart';

import '../../models/komunitas.dart';
import '../../services/komunitas_service.dart';
import '../../theme/app_theme.dart';

const aliranKomunitas = [
  'Impresionisme', 'Realisme', 'Ekspresionisme', 'Surealisme', 'Art Nouveau', 'Abstrak', 'Romantisisme', 'Pop Art',
];

/// Halaman "Komunitas": komunitas yang kamu ikuti dan daftar untuk dijelajahi (`GET /api/komunitas`),
/// plus pembuatan komunitas baru (maksimal 3 per akun).
class KomunitasSenimanScreen extends StatefulWidget {
  const KomunitasSenimanScreen({super.key, required this.onBack, required this.onBuka, KomunitasService? service}) : _service = service;

  final VoidCallback onBack;
  final ValueChanged<Komunitas> onBuka;
  final KomunitasService? _service;

  @override
  State<KomunitasSenimanScreen> createState() => _KomunitasSenimanScreenState();
}

class _KomunitasSenimanScreenState extends State<KomunitasSenimanScreen> {
  late final KomunitasService _service = widget._service ?? KomunitasService();
  final _cari = TextEditingController();
  bool _saya = true;
  List<Komunitas> _data = [];
  bool _memuat = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final d = await _service.daftar(saya: _saya, q: _cari.text);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat komunitas: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _buat() async {
    final baru = await showModalBottomSheet<Komunitas>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => _FormKomunitas(service: _service),
    );
    if (baru != null && mounted) widget.onBuka(baru);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Komunitas', style: AppTextStyles.headlineSm),
        actions: [IconButton(onPressed: _memuat ? null : _muat, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('buat_komunitas'),
        onPressed: _buat,
        icon: const Icon(Icons.add),
        label: const Text('Buat Komunitas'),
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter, AppSpacing.sm, AppSpacing.screenGutter, 96),
          children: [
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: true, label: Text('Komunitas Saya')), ButtonSegment(value: false, label: Text('Jelajahi'))],
              selected: {_saya},
              onSelectionChanged: (s) {
                setState(() => _saya = s.first);
                _muat();
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _cari,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _muat(),
              decoration: InputDecoration(
                hintText: 'Cari nama atau deskripsi komunitas',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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
                child: Text(
                  _saya ? 'Kamu belum bergabung di komunitas mana pun. Jelajahi komunitas atau buat sendiri.' : 'Belum ada komunitas yang cocok.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                ),
              )
            else
              for (final k in _data) _Kartu(k: k, onTap: () => widget.onBuka(k)),
          ],
        ),
      ),
    );
  }
}

class _Kartu extends StatelessWidget {
  const _Kartu({required this.k, required this.onTap});

  final Komunitas k;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = switch (k.saya) {
      'pemilik' => ('PEMILIK', AppColors.accent),
      'anggota' => ('ANGGOTA', AppColors.primary),
      'menunggu' => ('MENUNGGU', const Color(0xFFB26A00)),
      _ => null,
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Text(k.inisial, style: AppTextStyles.headlineSm.copyWith(color: const Color(0xFFECC246))),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(k.nama, style: AppTextStyles.labelMd, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (status != null) ...[
                      const SizedBox(width: 6),
                      Text(status.$1, style: AppTextStyles.overline.copyWith(fontSize: 8.5, color: status.$2)),
                    ],
                  ]),
                  Text(
                    '${k.jumlahAnggota} anggota · ${k.terbuka ? 'Terbuka' : 'Tertutup'} · oleh ${k.pemilikNama}',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
                  ),
                  if (k.deskripsi != null) Text(k.deskripsi!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm),
                  if (k.aliran.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(spacing: 4, runSpacing: 4, children: [
                        for (final a in k.aliran.take(3))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.accentSoft.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(AppRadius.full)),
                            child: Text(a, style: AppTextStyles.bodySm.copyWith(fontSize: 10)),
                          ),
                      ]),
                    ),
                ],
              ),
            ),
            if (k.pemilik && (k.jumlahPermintaan ?? 0) > 0)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(AppRadius.full)),
                child: Text('${k.jumlahPermintaan}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }
}

class _FormKomunitas extends StatefulWidget {
  const _FormKomunitas({required this.service});

  final KomunitasService service;

  @override
  State<_FormKomunitas> createState() => _FormKomunitasState();
}

class _FormKomunitasState extends State<_FormKomunitas> {
  final _nama = TextEditingController();
  final _deskripsi = TextEditingController();
  final _aturan = TextEditingController();
  final Set<String> _aliran = {};
  bool _terbuka = true;
  bool _kirim = false;
  String? _error;

  @override
  void dispose() {
    _nama.dispose();
    _deskripsi.dispose();
    _aturan.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_nama.text.trim().length < 3) {
      setState(() => _error = 'Nama komunitas minimal 3 karakter.');
      return;
    }
    setState(() {
      _kirim = true;
      _error = null;
    });
    try {
      final k = await widget.service.buat(
        nama: _nama.text.trim(), aliran: _aliran.toList(), terbuka: _terbuka, deskripsi: _deskripsi.text.trim(), aturan: _aturan.text.trim(),
      );
      if (mounted) Navigator.pop(context, k);
    } catch (e) {
      if (mounted) {
        setState(() {
          _kirim = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.screenGutter, AppSpacing.md, AppSpacing.screenGutter, MediaQuery.of(context).viewInsets.bottom + AppSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Buat Komunitas', style: AppTextStyles.headlineMd),
            const SizedBox(height: AppSpacing.sm),
            TextField(key: const Key('nama_komunitas'), controller: _nama, enabled: !_kirim, decoration: const InputDecoration(labelText: 'Nama komunitas', filled: true, fillColor: Colors.white, isDense: true)),
            const SizedBox(height: AppSpacing.xs),
            TextField(controller: _deskripsi, enabled: !_kirim, maxLines: 2, decoration: const InputDecoration(labelText: 'Deskripsi', filled: true, fillColor: Colors.white, isDense: true)),
            const SizedBox(height: AppSpacing.xs),
            Text('Aliran', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
            Wrap(
              spacing: 6,
              children: [
                for (final a in aliranKomunitas)
                  FilterChip(
                    label: Text(a),
                    selected: _aliran.contains(a),
                    onSelected: _kirim ? null : (v) => setState(() => v ? _aliran.add(a) : _aliran.remove(a)),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _terbuka,
              onChanged: _kirim ? null : (v) => setState(() => _terbuka = v),
              title: const Text('Terbuka untuk umum'),
              subtitle: Text(_terbuka ? 'Siapa pun bisa melihat isi dan langsung bergabung.' : 'Isi hanya untuk anggota; calon anggota perlu kamu setujui.', style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
            ),
            TextField(controller: _aturan, enabled: !_kirim, maxLines: 2, decoration: const InputDecoration(labelText: 'Aturan komunitas (opsional)', filled: true, fillColor: Colors.white, isDense: true)),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('simpan_komunitas'),
                onPressed: _kirim ? null : _simpan,
                child: _kirim ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Buat Komunitas'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
