package uz.metrx.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import uz.metrx.app.core.Settings
import uz.metrx.app.core.Strings
import uz.metrx.app.ui.MetrxApp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Strings.load(this)
        val settings = Settings(applicationContext)
        // A cold start plays the opening animation; coming back after the system recreated the screen does not.
        val playIntro = savedInstanceState == null
        // 3D pictures and photos left behind by rooms and items deleted in an earlier session
        if (playIntro) {
            val ps = uz.metrx.app.data.Store.get(this).projects.toList()
            uz.metrx.app.data.ViewFiles.sweep(this, ps)
            uz.metrx.app.data.PhotoFiles.sweep(this, (ps.flatMap { p -> p.floors.flatMap { w -> w.items.mapNotNull { it.src } } } + settings.shots.mapNotNull { it.src }).toSet())
        }
        setContent { MetrxApp(settings, playIntro) }
    }

    override fun onStop() {
        super.onStop()
        // nothing typed is lost if the phone kills the app while it is in the background
        uz.metrx.app.data.Store.get(this).flush()
    }
}
