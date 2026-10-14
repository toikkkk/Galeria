import '../models/picked_image.dart';

/// Pratinjau karya yang BARU diunggah (gambar + judul + seniman + aliran), dipakai layar hasil
/// verifikasi supaya menampilkan karya yang benar -- bukan contoh tetap. `null` bila layar hasil
/// dibuka tanpa lewat alur unggah (mis. langsung dari menu), lalu layar memakai tampilan contoh.
class UploadPreview {
  const UploadPreview({
    required this.image,
    required this.title,
    required this.artist,
    required this.style,
  });

  final PickedImage image;
  final String title;
  final String artist;
  final String style;

  static UploadPreview? last;
}
