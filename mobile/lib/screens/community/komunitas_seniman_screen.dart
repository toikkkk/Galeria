import 'package:flutter/material.dart';

import '../../state/studio_store.dart';
import '../../theme/app_theme.dart';

/// Halaman "Komunitas" seniman.
///
/// Belum punya komunitas -> penjelasan bahwa seniman bisa membuat komunitas
/// untuk pengguna + form pembuatan. Sudah punya -> ringkasan komunitas dan
/// pintasan ke halaman komunitas & membuat event.
///
/// Disimpan in-memory di [StudioStore] (belum ada tabel/endpoint komunitas).
class KomunitasSenimanScreen extends StatefulWidget {
  const KomunitasSenimanScreen({
    super.key,
    required this.onBack,
    this.onLihatKomunitas,
    this.onBuatEvent,
  });

  final VoidCallback onBack;
  final VoidCallback? onLihatKomunitas;
  final VoidCallback? onBuatEvent;

  @override
  State<KomunitasSenimanScreen> createState() => _KomunitasSenimanScreenState();
}

class _KomunitasSenimanScreenState extends State<KomunitasSenimanScreen> {
  static const _aliran = [
    'Impresionisme', 'Realisme', 'Ekspresionisme', 'Surealisme',
    'Art Nouveau', 'Abstrak', 'Romantisisme', 'Pop Art',
  ];

  final _store = StudioStore.instance;
  final _nama = TextEditingController();
  final _deskripsi = TextEditingController();
  final _aturan = TextEditingController();
  final Set<String> _dipilih = {};
  bool _terbuka = true;
  bool _form = false;
  String? _error;

  @override
  void dispose() {
    _nama.dispose();
    _deskripsi.dispose();
    _aturan.dispose();
    super.dispose();
  }

  void _buat() {
    if (_nama.text.trim().length < 3) {
      setState(() => _error = 'Nama komunitas minimal 3 karakter.');
      return;
    }
    if (_deskripsi.text.trim().isEmpty) {
      setState(() => _error = 'Tulis deskripsi singkat komunitasmu.');
      return;
    }
    _store.buatKomunitas(
      KomunitasSeniman(
        nama: _nama.text.trim(),
        deskripsi: _deskripsi.text.trim(),
        aliran: _dipilih.toList(),
        terbuka: _terbuka,
        aturan: _aturan.text.trim(),
      ),
    );
    setState(() {
      _error = null;
      _form = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Komunitas berhasil dibuat.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final k = _store.komunitas;
        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
            title: Text('Komunitas', style: AppTextStyles.headlineSm),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenGutter),
            children: [
              if (k != null)
                ..._punyaKomunitas(k)
              else if (_form)
                ..._formBuat()
              else
                ..._intro(),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _intro() => [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.groups_outlined, color: AppColors.accentSoft, size: 40),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Bangun komunitasmu sendiri',
                style: AppTextStyles.headlineMd.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Sebagai seniman, kamu bisa membuat komunitas untuk pengguna GALERIA: '
                'kolektor dan pecinta seni bisa bergabung, mengikuti karya terbarumu, '
                'dan menerima undangan pameran serta lelang.',
                style: AppTextStyles.bodyMd.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _Poin(Icons.person_add_alt_1_outlined, 'Anggota bergabung langsung atau lewat persetujuanmu'),
        const _Poin(Icons.campaign_outlined, 'Umumkan karya baru, lelang, dan pameran ke anggota'),
        const _Poin(Icons.event_outlined, 'Adakan event pameran khusus komunitas (Seniman PRO)'),
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton.icon(
          onPressed: () => setState(() => _form = true),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Buat Komunitas'),
        ),
      ];

  List<Widget> _formBuat() => [
        Text('Buat Komunitas', style: AppTextStyles.headlineMd),
        const SizedBox(height: AppSpacing.sm),
        Text('Nama komunitas', style: AppTextStyles.labelMd),
        const SizedBox(height: 6),
        TextField(controller: _nama, decoration: _dekor('mis. Pecinta Impresionisme Nusantara')),
        const SizedBox(height: AppSpacing.sm),
        Text('Deskripsi', style: AppTextStyles.labelMd),
        const SizedBox(height: 6),
        TextField(
          controller: _deskripsi,
          maxLines: 4,
          decoration: _dekor('Ceritakan tentang komunitas ini'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Aliran seni', style: AppTextStyles.labelMd),
        const SizedBox(height: 6),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final a in _aliran)
              FilterChip(
                label: Text(a),
                selected: _dipilih.contains(a),
                onSelected: (v) => setState(() => v ? _dipilih.add(a) : _dipilih.remove(a)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _terbuka,
          onChanged: (v) => setState(() => _terbuka = v),
          title: Text(_terbuka ? 'Terbuka untuk semua' : 'Anggota perlu disetujui'),
          subtitle: const Text('Atur siapa yang boleh bergabung'),
        ),
        Text('Aturan komunitas (opsional)', style: AppTextStyles.labelMd),
        const SizedBox(height: 6),
        TextField(controller: _aturan, maxLines: 3, decoration: _dekor('mis. Saling menghargai karya')),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: AppSpacing.md),
        ElevatedButton(onPressed: _buat, child: const Text('Buat Komunitas')),
        TextButton(
          onPressed: () => setState(() => _form = false),
          child: const Text('Batal'),
        ),
      ];

  List<Widget> _punyaKomunitas(KomunitasSeniman k) => [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.groups_outlined, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(k.nama, style: AppTextStyles.headlineSm)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(k.deskripsi, style: AppTextStyles.bodyMd),
              if (k.aliran.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final a in k.aliran) Chip(label: Text(a), visualDensity: VisualDensity.compact)],
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(k.terbuka ? Icons.public : Icons.lock_outline, size: 16, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    k.terbuka ? 'Terbuka untuk semua' : 'Anggota perlu disetujui',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                  ),
                  const Spacer(),
                  Text('1 anggota (kamu)', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: widget.onLihatKomunitas,
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Lihat Halaman Komunitas'),
        ),
        const SizedBox(height: AppSpacing.xs),
        ElevatedButton.icon(
          onPressed: widget.onBuatEvent,
          icon: const Icon(Icons.event_note_outlined, size: 18),
          label: const Text('Adakan Event Pameran'),
        ),
      ];

  InputDecoration _dekor(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );
}

class _Poin extends StatelessWidget {
  const _Poin(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.bodyMd)),
        ],
      ),
    );
  }
}
