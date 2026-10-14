import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Kendali view AR native (lihat `android/.../ArArtworkView.kt`).
class ArArtworkController {
  ArArtworkController._(this._channel);

  final MethodChannel _channel;

  /// Lepas karya dari dinding (pengguna bisa menempel ulang).
  Future<void> reset() => _channel.invokeMethod<void>('reset');

  /// Tangkap tampilan AR (kamera + karya) -> path file JPEG di cache.
  Future<String?> ambilFoto() => _channel.invokeMethod<String>('ambilFoto');
}

/// Cek dukungan ARCore di HP: "supported" | "needs_install" | "checking" | "unsupported".
Future<String> cekDukunganAr() async {
  const channel = MethodChannel('galeria/ar');
  try {
    for (var i = 0; i < 6; i++) {
      final r = await channel.invokeMethod<String>('checkAvailability');
      if (r != 'checking') return r ?? 'unsupported';
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  } on PlatformException {
    // jatuh ke unsupported di bawah
  } on MissingPluginException {
    // bukan Android
  }
  return 'unsupported';
}

/// View AR native: tempel karya di bidang dinding terdeteksi dengan ukuran fisik asli.
/// Status dari native: mencari | dinding | terpasang | tak_kena | izin | kamera_gagal | tidak_didukung.
class ArArtworkView extends StatelessWidget {
  const ArArtworkView({
    super.key,
    required this.image,
    required this.lebarCm,
    required this.tinggiCm,
    required this.onStatus,
    required this.onCreated,
  });

  final Uint8List image;
  final double lebarCm;
  final double tinggiCm;
  final ValueChanged<String> onStatus;
  final ValueChanged<ArArtworkController> onCreated;

  static const _viewType = 'galeria/ar_artwork';

  @override
  Widget build(BuildContext context) {
    return PlatformViewLink(
      viewType: _viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
        },
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) {
        final controller = PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: {
            'image': image,
            'lebarCm': lebarCm,
            'tinggiCm': tinggiCm,
          },
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        );
        controller.addOnPlatformViewCreatedListener(params.onPlatformViewCreated);
        controller.addOnPlatformViewCreatedListener((id) {
          final channel = MethodChannel('galeria/ar_artwork/$id');
          channel.setMethodCallHandler((call) async {
            if (call.method == 'status') onStatus(call.arguments as String);
          });
          onCreated(ArArtworkController._(channel));
        });
        controller.create();
        return controller;
      },
    );
  }
}
