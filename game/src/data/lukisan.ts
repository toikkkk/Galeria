/**
 * Data lukisan untuk game. Untuk MENAMBAH lukisan: taruh gambarnya di `public/lukisan/`, lalu tambahkan satu
 * objek di `LUKISAN` di bawah (berkas = nama file). Jalankan `npm run cek` untuk memeriksa datanya.
 *
 * CATATAN: keterangan di bawah ditulis dari pengetahuan umum seni rupa, dicocokkan dengan gambar yang dipasok.
 * Periksa ulang sebelum dipakai di pameran (terutama tahun, kolektor/museum, dan nilai jual yang disebut).
 */
export type Lukisan = {
  id: string;
  /** nama berkas di public/lukisan/ */
  berkas: string;
  judul: string;
  pelukis: string;
  tahun: string;
  /** satu istilah aliran yang dipakai sebagai kunci jawaban */
  aliran: string;
  /** keterangan singkat yang tampil setelah menjawab */
  fakta: string;
};

export const LUKISAN: Lukisan[] = [
  {
    id: 'mona-lisa',
    berkas: 'mona-lisa.jpg',
    judul: 'Mona Lisa',
    pelukis: 'Leonardo da Vinci',
    tahun: 'sekitar 1503–1519',
    aliran: 'Renaisans',
    fakta:
      'Tersimpan di Museum Louvre, Paris. Senyumnya yang samar dan teknik sfumato (peralihan warna yang sangat halus) membuatnya termasyhur.',
  },
  {
    id: 'starry-night',
    berkas: 'starry-night.jpg',
    judul: 'The Starry Night (Malam Berbintang)',
    pelukis: 'Vincent van Gogh',
    tahun: '1889',
    aliran: 'Post-Impresionisme',
    fakta:
      'Dilukis saat Van Gogh dirawat di Saint-Rémy-de-Provence, Prancis. Langit yang berputar dan sapuan kuas tebal menjadi ciri khasnya.',
  },
  {
    id: 'jeritan',
    berkas: 'jeritan.png',
    judul: 'Jeritan (The Scream)',
    pelukis: 'Edvard Munch',
    tahun: '1893 (ada beberapa versi)',
    aliran: 'Ekspresionisme',
    fakta:
      'Munch membuat beberapa versi karya ini. Langit merah dan sosok yang menjerit menggambarkan kecemasan, bukan pemandangan yang tampak apa adanya.',
  },
  {
    id: 'gadis-anting-mutiara',
    berkas: 'gadis-anting-mutiara.png',
    judul: 'Gadis dengan Anting Mutiara',
    pelukis: 'Johannes Vermeer',
    tahun: 'sekitar 1665',
    aliran: 'Barok',
    fakta:
      'Tersimpan di Mauritshuis, Den Haag. Karya ini sebuah "tronie" (studi wajah), bukan potret orang tertentu. Cahaya lembutnya menjadi tanda tangan Vermeer.',
  },
  {
    id: 'salvator-mundi',
    berkas: 'salvator-mundi.jpg',
    judul: 'Salvator Mundi (Juru Selamat Dunia)',
    pelukis: 'Leonardo da Vinci',
    tahun: 'sekitar 1500',
    aliran: 'Renaisans',
    fakta:
      'Dikaitkan dengan Leonardo da Vinci (atribusinya masih diperdebatkan sebagian ahli). Pada 2017 lukisan ini terjual sekitar US$450 juta di lelang, rekor untuk karya seni.',
  },
  {
    id: 'penangkapan-diponegoro',
    berkas: 'penangkapan-diponegoro.jpg',
    judul: 'Penangkapan Pangeran Diponegoro',
    pelukis: 'Raden Saleh',
    tahun: '1857',
    aliran: 'Romantisisme',
    fakta:
      'Raden Saleh adalah pelukis Indonesia pertama yang dikenal luas di Eropa. Karya ini menggambarkan penangkapan Pangeran Diponegoro pada akhir Perang Jawa (1830).',
  },
  {
    id: 'interchange',
    berkas: 'interchange.jpg',
    judul: 'Interchange',
    pelukis: 'Willem de Kooning',
    tahun: '1955',
    aliran: 'Ekspresionisme Abstrak',
    fakta:
      'Dilaporkan terjual sekitar US$300 juta pada 2015. Sapuan kuas yang spontan dan penuh tenaga khas gerakan Ekspresionisme Abstrak.',
  },
];

/** Nama pelukis pengecoh (dicampur dengan pelukis dari daftar di atas). */
export const PELUKIS_PENGECOH = [
  'Pablo Picasso',
  'Claude Monet',
  'Rembrandt van Rijn',
  'Salvador Dalí',
  'Frida Kahlo',
  'Affandi',
  'Hendra Gunawan',
  'Basuki Abdullah',
  'Michelangelo',
  'Gustav Klimt',
  'Paul Cézanne',
  'Jackson Pollock',
  'Francisco Goya',
  'Sandro Botticelli',
  'Henri Matisse',
  'Andy Warhol',
];

/** Aliran pengecoh. */
export const ALIRAN_PENGECOH = [
  'Impresionisme',
  'Kubisme',
  'Surealisme',
  'Realisme',
  'Rokoko',
  'Pop Art',
  'Fauvisme',
  'Art Nouveau',
  'Neoklasikisme',
  'Dadaisme',
  'Minimalisme',
  'Seni Naif',
];
