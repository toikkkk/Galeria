import 'package:flutter/material.dart';

import '../../models/komunitas.dart';
import '../../services/komunitas_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/commerce_widgets.dart';

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
      backgroundColor: kLatarMarketplace,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Komunitas', style: AppTextStyles.headlineSm),
        actions: [IconButton(onPressed: _memuat ? null : _muat, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('buat_komunitas'),
        onPressed: _buat,
        backgroundColor: const Color(0xFF3E251E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Buat Komunitas', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 96),
          children: [
            SegmentedButton<bool>(
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF3E251E),
                selectedBackgroundColor: const Color(0xFF3E251E),
                selectedForegroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
      'anggota' => ('ANGGOTA', AppColors.success),
      'menunggu' => ('MENUNGGU', const Color(0xFFB26A00)),
      _ => null,
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // kepala gelap: avatar inisial + nama + status
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF4D2F26), Color(0xFF2F1B15)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFDBA12C), borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Text(k.inisial, style: AppTextStyles.headlineSm.copyWith(color: const Color(0xFF3E251E), fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(k.nama, style: AppTextStyles.headlineSm.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(k.terbuka ? Icons.public : Icons.lock_outline, size: 13, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(k.terbuka ? 'Terbuka' : 'Tertutup', style: AppTextStyles.bodySm.copyWith(color: Colors.white70, fontSize: 11)),
                            if (status != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: status.$1 == 'PEMILIK' ? const Color(0xFFDBA12C) : Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(AppRadius.full)),
                                child: Text(status.$1, style: AppTextStyles.overline.copyWith(fontSize: 8.5, color: status.$1 == 'PEMILIK' ? const Color(0xFF3E251E) : Colors.white, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (k.pemilik && (k.jumlahPermintaan ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(AppRadius.full)),
                      child: Text('${k.jumlahPermintaan}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (k.deskripsi != null) Text(k.deskripsi!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm.copyWith(fontSize: 12.5, color: AppColors.onSurface)),
                  if (k.aliran.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(spacing: 4, runSpacing: 4, children: [
                        for (final a in k.aliran.take(3))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFF7E7C1), borderRadius: BorderRadius.circular(AppRadius.full)),
                            child: Text(a, style: AppTextStyles.bodySm.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF7A5410))),
                          ),
                      ]),
                    ),
                  const Divider(height: AppSpacing.md),
                  Row(
                    children: [
                      const Icon(Icons.groups_2_outlined, size: 17, color: Color(0xFF3E251E)),
                      const SizedBox(width: 5),
                      Text('${k.jumlahAnggota} anggota', style: AppTextStyles.labelMd.copyWith(fontSize: 12.5, fontWeight: FontWeight.w800, color: const Color(0xFF3E251E))),
                      const Spacer(),
                      Flexible(child: Text('oleh ${k.pemilikNama}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm.copyWith(fontSize: 11.5, color: AppColors.muted))),
                    ],
                  ),
                ],
              ),
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
