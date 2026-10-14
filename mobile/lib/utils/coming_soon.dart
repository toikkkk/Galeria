import 'package:flutter/material.dart';

/// Feedback SnackBar standar utk tombol yang navigasinya/fiturnya SENGAJA
/// belum dibangun (bukan placeholder diam/`() {}` yang terlihat seperti
/// bug) -- pola yang sudah dipakai `main.dart` utk alur pembayaran promosi
/// karya, disatukan di sini supaya konsisten & tidak duplikasi di puluhan
/// tempat (lihat audit navigasi role Seniman, 2026-10).
///
/// [fitur] = nama fitur dalam Bahasa Indonesia, mis. "Tarik dana".
void showComingSoon(BuildContext context, String fitur) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$fitur belum tersedia')),
  );
}
