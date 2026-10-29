/// Aturan & kekuatan password -- harus sejalan dengan validasi server (`backend/schemas/auth.py`):
/// minimal 8 karakter, mengandung huruf DAN angka, maksimal 72 byte (batas bcrypt).
const kPasswordMin = 8;
const kPasswordMaksByte = 72;

/// Pesan galat bila password tidak memenuhi syarat server, atau null bila lolos.
String? validasiPassword(String pw) {
  if (pw.length < kPasswordMin) return 'Kata sandi minimal $kPasswordMin karakter.';
  if (!RegExp(r'[A-Za-z]').hasMatch(pw) || !RegExp(r'\d').hasMatch(pw)) {
    return 'Kata sandi harus mengandung huruf dan angka.';
  }
  if (_byteUtf8(pw) > kPasswordMaksByte) {
    return 'Kata sandi terlalu panjang.';
  }
  return null;
}

int _byteUtf8(String s) {
  var n = 0;
  for (final r in s.runes) {
    n += r < 0x80 ? 1 : r < 0x800 ? 2 : r < 0x10000 ? 3 : 4;
  }
  return n;
}

/// Tingkat kekuatan 0 (kosong) .. 4 (sangat kuat) untuk indikator saat mengetik. Ini panduan visual,
/// bukan jaminan keamanan; syarat minimal yang mengikat tetap [validasiPassword].
int kekuatanPassword(String pw) {
  if (pw.isEmpty) return 0;
  var skor = 0;
  if (pw.length >= kPasswordMin) skor++;
  if (pw.length >= 12) skor++;
  if (RegExp(r'[a-z]').hasMatch(pw) && RegExp(r'[A-Z]').hasMatch(pw)) skor++;
  if (RegExp(r'\d').hasMatch(pw) && RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) skor++;
  // di bawah syarat minimal tidak pernah dianggap lebih dari "lemah"
  if (validasiPassword(pw) != null) return skor.clamp(1, 1);
  return skor.clamp(1, 4);
}

const labelKekuatan = ['', 'Lemah', 'Cukup', 'Kuat', 'Sangat Kuat'];
