import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galeria/models/karya.dart';
import 'package:galeria/models/karya_rekomendasi.dart';
import 'package:galeria/widgets/karya_image.dart';

Map<String, dynamic> _karyaJson({String? imageUrl}) => {
      'id': 'k1',
      'title': 'Tanpa Judul (Impressionism)',
      'artist_name': 'Claude Monet',
      'style_name': 'Impressionism',
      'gallery_name': 'Studio Claude Monet',
      'price_idr': 65000000,
      'is_promoted': false,
      'image_filename': 'wikiart_01234.jpg',
      'image_url': imageUrl,
      'seniman_id': 's1',
    };

void main() {
  test('Karya.fromJson membaca image_url & seniman_id (opsional)', () {
    final k = Karya.fromJson(_karyaJson(imageUrl: 'https://x/y.jpg'));
    expect(k.imageUrl, 'https://x/y.jpg');
    expect(k.senimanId, 's1');
    final lama = Karya.fromJson({..._karyaJson(), 'image_url': null, 'seniman_id': null});
    expect(lama.imageUrl, isNull);
    expect(lama.senimanId, isNull);
  });

  test('RekomendasiResult.fromJson sesuai kontrak (segmen boleh null)', () {
    final r = RekomendasiResult.fromJson({
      'kolektor_id': 'c1',
      'strategi': 'model',
      'segmen': null,
      'items': [
        {
          'peringkat': 1,
          'skor': 0.81,
          'alasan': [
            {'kode': 'gaya_favorit', 'teks': 'Sesuai aliran favoritmu: Impressionism'},
          ],
          'karya': _karyaJson(),
        },
      ],
    });
    expect(r.strategi, 'model');
    expect(r.segmenNama, isNull);
    expect(r.items.single.alasan.first.kode, 'gaya_favorit');
  });

  testWidgets('KaryaImage: URL gagal dimuat -> ikon gambar-rusak, tidak crash', (tester) async {
    final k = Karya.fromJson(_karyaJson(imageUrl: 'http://127.0.0.1:1/tidak-ada.jpg'));
    await tester.pumpWidget(MaterialApp(home: SizedBox(width: 100, height: 100, child: KaryaImage(karya: k))));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
