package fr.ensc.safit

import fr.ensc.safit.camera.HighSpeedCameraPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var camera: HighSpeedCameraPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        camera = HighSpeedCameraPlugin(this, flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        camera?.onPermissionResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        camera?.releaseNow()
        super.onDestroy()
    }
}
