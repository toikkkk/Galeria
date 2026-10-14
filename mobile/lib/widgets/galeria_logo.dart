import 'package:flutter/material.dart';

/// Logo GALERIA (PNG transparan, `assets/images/logo/galeria_logo.png`).
///
/// [withWordmark] menambahkan tulisan "GALERIA" di kanan logo -- dipakai di
/// app bar. Tanpa itu, hanya emblem (splash, login, dll).
class GaleriaLogo extends StatelessWidget {
  const GaleriaLogo({super.key, this.size = 40, this.withWordmark = false, this.textStyle});

  final double size;
  final bool withWordmark;
  final TextStyle? textStyle;

  static const assetPath = 'assets/images/logo/galeria_logo.png';

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Logo GALERIA',
    );
    if (!withWordmark) return image;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        image,
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'GALERIA',
            overflow: TextOverflow.ellipsis,
            style: textStyle ?? Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}
