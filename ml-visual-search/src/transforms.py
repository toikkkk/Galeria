"""Definisi augmentasi dan normalisasi gambar.

Tanggung jawab file ini:
- :class:`SquarePad` -- "meng-embed" gambar ke kanvas PERSEGI dengan menambah
  padding di kiri-kanan (untuk gambar potret) atau atas-bawah (untuk lanskap).
  Tujuannya (arahan dosen): SELURUH komposisi lukisan terjaga -- tidak ada
  bagian tepi yang ter-crop dan rasio aspek asli tidak terdistorsi saat gambar
  diperkecil ke 224x224. Penting karena EDA menunjukkan rasio aspek subset
  WikiArt sangat lebar (0.35 s/d 3.28).
- :func:`build_train_transforms` -- pipeline augmentasi untuk split TRAIN::

      [SquarePad] -> Resize(256) -> RandomCrop(224) -> RandomHorizontalFlip(0.5)
      -> ColorJitter (ringan) -> RandomRotation(10 deg)
      -> ToTensor -> Normalize (mean/std ImageNet)

  CATATAN: JANGAN menambah vertical flip atau cutout agresif -- merusak
  komposisi & detail gaya lukisan (lihat CLAUDE.md "Rencana Teknis Model").
- :func:`build_eval_transforms` -- pipeline DETERMINISTIK untuk val / test /
  ekstraksi embedding ([SquarePad] -> Resize -> [CenterCrop] -> ToTensor ->
  Normalize), tanpa augmentasi acak apa pun.

Semua parameter (ukuran resize/crop, padding, mean/std, probabilitas augmentasi)
diambil dari ``config.yaml`` bagian ``image`` dan ``augmentation``.
"""

from __future__ import annotations

from PIL import Image
from torchvision import transforms
from torchvision.transforms import functional as F


class SquarePad:
    """Embed gambar ke kanvas persegi via padding kiri-kanan / atas-bawah.

    Args:
        mode: ``"edge"`` (replikasi piksel tepi -- aman untuk rasio aspek
            ekstrem, tanpa border keras), ``"reflect"`` (cermin -- hati-hati,
            gagal bila padding >= dimensi gambar), atau ``"constant"``
            (border warna solid).
        fill: warna border bila ``mode == "constant"`` (mis. 255 = putih,
            0 = hitam). Diabaikan untuk mode lain.
    """

    def __init__(self, mode: str = "edge", fill: int = 255) -> None:
        self.mode = mode
        self.fill = fill

    def __call__(self, img: Image.Image) -> Image.Image:
        w, h = img.size
        side = max(w, h)
        pad_left = (side - w) // 2
        pad_right = side - w - pad_left
        pad_top = (side - h) // 2
        pad_bottom = side - h - pad_top
        return F.pad(
            img,
            [pad_left, pad_top, pad_right, pad_bottom],
            fill=self.fill,
            padding_mode=self.mode,
        )

    def __repr__(self) -> str:  # pragma: no cover - kosmetik
        return f"{self.__class__.__name__}(mode={self.mode!r}, fill={self.fill})"


def _square_pad_step(cfg: dict) -> list:
    """Kembalikan ``[SquarePad(...)]`` bila diaktifkan di config, atau ``[]``."""
    img = cfg["image"]
    if not img.get("pad_to_square", False):
        return []
    return [SquarePad(mode=img.get("pad_mode", "edge"), fill=img.get("pad_fill", 255))]


def build_train_transforms(cfg: dict) -> transforms.Compose:
    """Pipeline augmentasi untuk split train.

    Default (CLAUDE.md): Resize -> RandomCrop -> HFlip -> ColorJitter -> Rotation.
    Bila ``augmentation.trivial_augment`` true: HFlip -> TrivialAugmentWide
    (menggantikan ColorJitter + Rotation) -- augmentasi kuat tanpa tuning untuk
    data kecil. TrivialAugmentWide tidak memuat flip vertikal / cutout.
    """
    img = cfg["image"]
    aug = cfg["augmentation"]

    steps = [
        *_square_pad_step(cfg),
        transforms.Resize(img["resize"]),
        transforms.RandomCrop(img["size"]),
        transforms.RandomHorizontalFlip(p=aug["horizontal_flip"]),
    ]
    if aug.get("trivial_augment", False):
        steps.append(transforms.TrivialAugmentWide())
    else:
        jitter = aug["color_jitter"]
        steps += [
            transforms.ColorJitter(
                brightness=jitter["brightness"],
                contrast=jitter["contrast"],
                saturation=jitter["saturation"],
                hue=jitter["hue"],
            ),
            transforms.RandomRotation(degrees=aug["rotation_degrees"]),
        ]
    steps += [
        transforms.ToTensor(),
        transforms.Normalize(mean=img["mean"], std=img["std"]),
    ]
    return transforms.Compose(steps)


def build_eval_transforms(cfg: dict) -> transforms.Compose:
    """Pipeline deterministik untuk val / test / ekstraksi embedding.

    Bila ``pad_to_square`` aktif, gambar sudah persegi sehingga langsung
    di-resize ke ``image.size`` (tanpa center-crop, agar tidak ada komposisi
    yang hilang). Bila tidak, pakai Resize -> CenterCrop klasik.
    """
    img = cfg["image"]
    if img.get("pad_to_square", False):
        steps = [*_square_pad_step(cfg), transforms.Resize((img["size"], img["size"]))]
    else:
        steps = [
            transforms.Resize(img["resize"]),
            transforms.CenterCrop(img["size"]),
        ]
    return transforms.Compose(
        steps
        + [
            transforms.ToTensor(),
            transforms.Normalize(mean=img["mean"], std=img["std"]),
        ]
    )


def build_capture_simulation_transform(cfg: dict) -> transforms.Compose:
    """Simulasikan "foto HP dari lukisan fisik/layar" -- BUKAN untuk training,
    khusus menguji **instance retrieval** ("scan lukisan spesifik untuk
    dicari di katalog", gaya Google Lens): rotasi, distorsi perspektif,
    perubahan pencahayaan, dan blur ringan meniru kondisi orang memotret
    karya dengan kamera HP (sudut miring, cahaya beda, tidak fokus sempurna).

    Dipakai di ``notebooks/02_embedding_retrieval.ipynb`` untuk mengukur
    apakah embedding tetap menemukan file ASLI sebuah karya di katalog
    meski query-nya "difoto ulang" dalam kondisi tidak ideal -- beda dari
    :func:`build_eval_transforms` yang deterministik untuk skoring normal.
    """
    img = cfg["image"]
    return transforms.Compose(
        [
            transforms.RandomRotation(12, fill=255),
            transforms.RandomPerspective(distortion_scale=0.25, p=0.8, fill=255),
            transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.2),
            transforms.GaussianBlur(kernel_size=3, sigma=(0.1, 1.5)),
            transforms.Resize((img["size"], img["size"])),
            transforms.ToTensor(),
            transforms.Normalize(mean=img["mean"], std=img["std"]),
        ]
    )
