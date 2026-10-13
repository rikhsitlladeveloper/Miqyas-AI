plugins {
    id("com.android.application")
}

android {
    namespace = "uz.metrx.prototype"
    compileSdk = 36

    defaultConfig {
        applicationId = "uz.metrx.prototype"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.2-design"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

// Copy the latest HTML prototype into the app before every build.
// design/prototype/index.html is generated from prototype.html by design/prototype/make_index.py.
val syncPrototype by tasks.registering(Copy::class) {
    from(rootProject.file("../prototype/index.html"))
    into(layout.projectDirectory.dir("src/main/assets"))
}
tasks.named("preBuild") { dependsOn(syncPrototype) }
