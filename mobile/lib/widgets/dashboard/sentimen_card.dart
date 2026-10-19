import 'package:flutter/material.dart';

import '../../models/sentimen_seniman.dart';
import '../../services/sentimen_service.dart';
import '../../theme/app_theme.dart';
import 'dashboard_sections.dart';

const _warna = {
  'positif': AppColors.success,
  'netral': AppColors.muted,
  'negatif': AppColors.error,
};

String _label(String s) => switch (s) {
      'positif' => 'Positif',
      'netral' => 'Netral',
      _ => 'Negatif',
    };

const _namaBulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String _bulanPendek(String iso) {
  final m = int.tryParse(iso.substring(5, 7)) ?? 1;
  return _namaBulan[m - 1];
}

/// Kartu "Sentimen Ulasan" di dashboard seniman. Memuat datanya sendiri dan TIDAK menjatuhkan
/// dashboard bila gagal: kalau backend/tabel hasil belum ada, tampil pesan singkat.
class SentimenCard extends StatefulWidget {
  const SentimenCard({super.key, required this.senimanId, this.service});

  final String senimanId;
  final SentimenService? service;

  @override
  State<SentimenCard> createState() => _SentimenCardState();
}

class _SentimenCardState extends State<SentimenCard> {
  late final SentimenService _service = widget.service ?? SentimenService();
  SentimenSeniman? _data;
  bool _loading = true;
  bool _gagal = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _gagal = false;
    });
    try {
      final d = await _service.fetchSentimen(widget.senimanId);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gagal = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Sentimen Ulasan',
      subtitle: 'Dibaca otomatis oleh IndoBERT dari ulasan kolektor',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(alignment: Alignment.centerRight, child: DataContohBadge()),
          const SizedBox(height: AppSpacing.xs),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_gagal || _data == null)
            _Pesan(teks: 'Analisis sentimen belum tersedia.', aksi: _muat)
          else if (_data!.nUlasan == 0)
            const _Pesan(teks: 'Belum ada ulasan untuk seniman ini.')
          else
            _Isi(data: _data!),
        ],
      ),
    );
  }
}

class _Pesan extends StatelessWidget {
  const _Pesan({required this.teks, this.aksi});

  final String teks;
  final VoidCallback? aksi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(teks, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted))),
          if (aksi != null) TextButton(onPressed: aksi, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.data});

  final SentimenSeniman data;

  @override
  Widget build(BuildContext context) {
    final indeks = data.indeksSentimen;
    final rating = data.ratingRata2 == null ? '' : ' · rating ${data.ratingRata2!.toStringAsFixed(1)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              indeks == null ? '-' : '${indeks > 0 ? '+' : ''}${indeks.toStringAsFixed(0)}',
              style: AppTextStyles.headlineMd.copyWith(
                fontSize: 32,
                color: indeks != null && indeks < 0 ? AppColors.error : AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'indeks sentimen · ${data.nUlasan} ulasan$rating',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _BarProporsi(hitung: data.hitung),
        const SizedBox(height: AppSpacing.md),
        Text('6 bulan terakhir', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
        const SizedBox(height: AppSpacing.xs),
        _Tren(bulan: data.trenBulanan),
        if (data.ulasanTerbaru.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Ulasan terbaru', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
          const SizedBox(height: AppSpacing.xs),
          for (final u in data.ulasanTerbaru.take(3)) _Ulasan(u: u),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Ulasan dan labelnya sintetis; hasil model belum diuji pada ulasan pengguna sungguhan.',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _BarProporsi extends StatelessWidget {
  const _BarProporsi({required this.hitung});

  final List<SentimenHitung> hitung;

  @override
  Widget build(BuildContext context) {
    final total = hitung.fold<int>(0, (a, h) => a + h.jumlah);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (final h in hitung)
                  if (h.jumlah > 0)
                    Expanded(flex: h.jumlah, child: ColoredBox(color: _warna[h.sentimen]!, child: const SizedBox.expand())),
                if (total == 0) const Expanded(child: ColoredBox(color: AppColors.surfaceContainer, child: SizedBox.expand())),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.md,
          children: [
            for (final h in hitung)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: _warna[h.sentimen], shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('${_label(h.sentimen)} ${h.persen.toStringAsFixed(0)}% (${h.jumlah})', style: AppTextStyles.bodySm),
              ]),
          ],
        ),
      ],
    );
  }
}

class _Tren extends StatelessWidget {
  const _Tren({required this.bulan});

  final List<SentimenBulan> bulan;

  @override
  Widget build(BuildContext context) {
    final maks = bulan.fold<int>(1, (a, b) => b.total > a ? b.total : a);
    return SizedBox(
      height: 84,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in bulan)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (b.total > 0)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: SizedBox(
                          height: 56 * b.total / maks,
                          child: Column(
                            children: [
                              if (b.negatif > 0)
                                Expanded(flex: b.negatif, child: const ColoredBox(color: AppColors.error, child: SizedBox.expand())),
                              if (b.netral > 0)
                                Expanded(flex: b.netral, child: const ColoredBox(color: AppColors.muted, child: SizedBox.expand())),
                              if (b.positif > 0)
                                Expanded(flex: b.positif, child: const ColoredBox(color: AppColors.success, child: SizedBox.expand())),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(height: 2, color: AppColors.surfaceContainer),
                    const SizedBox(height: 4),
                    Text(_bulanPendek(b.bulan), style: AppTextStyles.bodySm.copyWith(fontSize: 10, color: AppColors.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Ulasan extends StatelessWidget {
  const _Ulasan({required this.u});

  final UlasanContoh u;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3, right: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _warna[u.sentimen]!.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(_label(u.sentimen), style: AppTextStyles.overline.copyWith(fontSize: 9, color: _warna[u.sentimen])),
          ),
          Expanded(child: Text(u.teks, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm)),
        ],
      ),
    );
  }
}
