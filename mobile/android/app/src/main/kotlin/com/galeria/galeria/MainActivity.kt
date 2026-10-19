package com.galeria.galeria

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        flutterEngine.platformViewsController.registry
            .registerViewFactory("galeria/ar_artwork", ArArtworkFactory(this, messenger))
        MethodChannel(messenger, "galeria/ar").setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAvailability" -> result.success(ArSupport.check(this))
                else -> result.notImplemented()
            }
        }
    }
}
