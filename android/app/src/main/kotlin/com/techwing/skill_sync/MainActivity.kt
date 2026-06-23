package com.techwing.skill_sync

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The background sync service plugin registration is handled automatically
        // by Flutter's plugin system or through fallback mechanisms in the Dart code
    }
}