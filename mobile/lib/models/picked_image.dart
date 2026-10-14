import 'dart:typed_data';

/// Gambar hasil pilih dari galeri yang AMAN untuk web maupun mobile.
///
/// Dipakai alih-alih `dart:io` [File]: di Flutter Web `File(path)` /
/// `Image.file` tidak didukung, jadi byte gambar dibaca langsung dari
/// `XFile.readAsBytes()` dan dikirim ke backend sebagai multipart bytes.
class PickedImage {
  const PickedImage({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}
