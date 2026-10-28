import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

// The release key lives outside the repo (D:\WORKDESK\TOKENS). Point METRX_KEYSTORE at another
// properties file to use a different one; without it, release builds stay unsigned.
val keyProps = Properties().apply {
    val f = file(System.getenv("METRX_KEYSTORE") ?: "D:/WORKDESK/TOKENS/metrx-keystore.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "uz.metrx.app"
    compileSdk = 37

    defaultConfig {
        applicationId = "uz.metrx.app"
        minSdk = 26
        targetSdk = 36
        // Google Play 1.0.0 (28 Oct 2026); the earlier test builds were 0.x up to code 8
        versionCode = 10
        versionName = "1.0.0"
    }

    signingConfigs {
        if (keyProps.getProperty("storeFile") != null) create("release") {
            storeFile = file(keyProps.getProperty("storeFile"))
            storePassword = keyProps.getProperty("storePassword")
            keyAlias = keyProps.getProperty("keyAlias")
            keyPassword = keyProps.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.findByName("release")
        }
        // The release build (R8, shrunk resources) under its own id and the debug key, to try on the emulator next to the
        // installed debug app (which holds real data) without replacing it: ./gradlew :app:installQa
        create("qa") {
            initWith(getByName("release"))
            applicationIdSuffix = ".qa"
            signingConfig = signingConfigs.getByName("debug")
            matchingFallbacks += "release"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    // BuildConfig.DEBUG: the laser simulator is there only in a debug build with test mode on (laser/LaserRouter.kt)
    buildFeatures { compose = true; buildConfig = true }

    // Phones (arm64, older arm) and the x86_64 emulator. Native libraries are stored uncompressed and 16 KB aligned in
    // the APK (Google Play's 16 KB page-size rule, 26 Oct 2026), so Android maps them straight from the APK.
    defaultConfig { ndk { abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64") } }
    packaging { jniLibs { useLegacyPackaging = false } }
    // SceneView ships lighting files and materials the 3D view never loads. Used: the two flat-colour materials and,
    // for the lit furniture (modern 3D, 25 Oct 2026), the lit colour, lit picture and see-through lit ones; the studio
    // light is made in code (ui/three/Render3D.kt), so SceneView's environments stay out.
    androidResources {
        ignoreAssetsPatterns += listOf(
            "<dir>environments", "contact_shadow.filamat", "image_texture.filamat", "occlusion.filamat",
            "semantics_overlay.filamat", "splat.filamat", "transparent_textured.filamat",
            "video_texture.filamat", "video_texture_chroma_key.filamat", "view_texture_lit.filamat", "view_texture_unlit.filamat"
        )
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.09.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.core:core-ktx:1.19.1")
    implementation("androidx.core:core-splashscreen:1.2.0")
    // Real backdrop blur behind the tab bar, sheets and header buttons on Android 12+; a frosted tint below that.
    implementation("dev.chrisbanes.haze:haze-android:1.7.3")
    // projects are stored as JSON documents in SQLite (see data/Store.kt)
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.10.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    // 3D view of rooms (Filament underneath); 4.48.0 is from 28 Sep 2026
    implementation("io.github.sceneview:sceneview:4.48.0")
    // the Measure page's live camera (CameraX 1.6.2, stable since summer 2026)
    implementation("androidx.camera:camera-camera2:1.6.2")
    implementation("androidx.camera:camera-lifecycle:1.6.2")
    implementation("androidx.camera:camera-view:1.6.2")
    // offline voice numbers (UX upgrades §9): Vosk; the Uzbek and Russian models are downloaded by the app over Wi-Fi
    // 0.3.75 ships 16 KB-aligned arm64/x86_64 libvosk.so (0.3.47's was 4 KB); JNA 5.19.1's libjnidispatch.so is
    // 16 KB aligned on every ABI (Vosk itself asks for 5.18.1)
    implementation("com.alphacephei:vosk-android:0.3.75")
    implementation("net.java.dev.jna:jna:5.19.1@aar")
    // an order's location (GPS fix, 27 Oct 2026): Google's fused provider (GPS + Wi-Fi + cell) and the "Turn on
    // location" dialog; without Google Play services the app falls back to the phone's own GPS and network providers
    implementation("com.google.android.gms:play-services-location:21.4.0")
    debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("androidx.compose.ui:ui-tooling-preview")
    testImplementation("junit:junit:4.13.2")
}
