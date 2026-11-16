// Memeriksa data lukisan: berkas ada, kolom lengkap, id unik, dan cukup pengecoh untuk 4 pilihan.
// Pakai: npm run cek
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const akar = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sumber = fs.readFileSync(path.join(akar, 'src/data/lukisan.ts'), 'utf8');

const ambil = (nama) => {
  const m = sumber.match(new RegExp(`export const ${nama}[^=]*=\\s*\\[([\\s\\S]*?)\\n\\];`));
  return m ? m[1] : '';
};

const blok = ambil('LUKISAN');
const objek = [...blok.matchAll(/\{\s*id:\s*'([^']+)',\s*berkas:\s*'([^']+)',\s*judul:\s*'([^']+)',\s*pelukis:\s*'([^']+)',\s*tahun:\s*'([^']+)',\s*aliran:\s*'([^']+)',\s*fakta:\s*'([\s\S]*?)',?\s*\}/g)].map((m) => ({
  id: m[1], berkas: m[2], judul: m[3], pelukis: m[4], tahun: m[5], aliran: m[6], fakta: m[7],
}));
const daftar = (nama) => [...ambil(nama).matchAll(/'([^']+)'/g)].map((m) => m[1]);

let salah = 0;
const gagal = (pesan) => { console.error('X ' + pesan); salah++; };

if (objek.length === 0) gagal('Tidak ada lukisan terbaca di src/data/lukisan.ts');
const id = new Set();
for (const l of objek) {
  if (id.has(l.id)) gagal(`id ganda: ${l.id}`);
  id.add(l.id);
  const f = path.join(akar, 'public/lukisan', l.berkas);
  if (!fs.existsSync(f)) gagal(`berkas gambar tidak ada: public/lukisan/${l.berkas} (${l.id})`);
  else if (fs.statSync(f).size < 20_000) console.warn(`! ${l.berkas} kecil (${Math.round(fs.statSync(f).size / 1024)} KB): kemungkinan buram di layar besar`);
}
const pelukis = new Set([...objek.map((l) => l.pelukis), ...daftar('PELUKIS_PENGECOH')]);
const aliran = new Set([...objek.map((l) => l.aliran), ...daftar('ALIRAN_PENGECOH')]);
if (pelukis.size < 4) gagal('Nama pelukis (data + pengecoh) kurang dari 4');
if (aliran.size < 4) gagal('Aliran (data + pengecoh) kurang dari 4');

console.log(`${objek.length} lukisan, ${pelukis.size} nama pelukis, ${aliran.size} aliran.`);
if (salah) { console.error(`${salah} masalah.`); process.exit(1); }
console.log('Data OK.');
