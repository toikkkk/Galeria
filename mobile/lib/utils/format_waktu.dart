import 'package:flutter/material.dart';

const _bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// 14 Oktober 2026
String formatTanggal(DateTime d) => '${d.day} ${_bulan[d.month - 1]} ${d.year}';

/// 09.30
String formatJam(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';

/// 14 Oktober 2026 · 09.30
String formatTanggalJam(DateTime d) =>
    '${formatTanggal(d)} · ${formatJam(TimeOfDay.fromDateTime(d))}';
