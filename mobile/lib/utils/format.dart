/// Format angka untuk UI (locale Indonesia: titik ribuan, koma desimal).
library;

String _ribuan(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// 36200000 -> "Rp36.200.000" (sama dengan `Karya.priceFormatted`).
String formatRupiah(int idr) => '${idr < 0 ? '-' : ''}Rp${_ribuan(idr)}';

String _desimal(double v) {
  final s = v.toStringAsFixed(1);
  return (s.endsWith('.0') ? s.substring(0, s.length - 2) : s).replaceAll('.', ',');
}

/// 36200000 -> "Rp36,2 jt"; 1140000000 -> "Rp1,1 M"; di bawah 1 juta pakai format penuh.
String formatRupiahRingkas(int idr) {
  final abs = idr.abs();
  final sign = idr < 0 ? '-' : '';
  if (abs >= 1000000000000) return '${sign}Rp${_desimal(abs / 1000000000000)} T';
  if (abs >= 1000000000) return '${sign}Rp${_desimal(abs / 1000000000)} M';
  if (abs >= 1000000) return '${sign}Rp${_desimal(abs / 1000000)} jt';
  return formatRupiah(idr);
}

/// 12.5 -> "+12,5%", -3.0 -> "-3%", null -> "-" (tidak ada pembanding).
String formatPersen(double? v, {bool tandaPlus = true}) {
  if (v == null) return '-';
  final plus = tandaPlus && v > 0 ? '+' : '';
  return '$plus${_desimal(v)}%';
}

const _bulanSingkat = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// "2026-09-01" -> "Sep".
String namaBulanSingkat(String isoTanggal) {
  final m = int.tryParse(isoTanggal.substring(5, 7)) ?? 0;
  return (m >= 1 && m <= 12) ? _bulanSingkat[m - 1] : '';
}

/// "Post_Impressionism" -> "Post Impressionism".
String rapikanNamaAliran(String s) => s.replaceAll('_', ' ');
