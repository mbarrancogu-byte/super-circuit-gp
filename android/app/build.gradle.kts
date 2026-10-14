plugins {
    id("com.android.application")
}

android {
    namespace = "com.starlegend.advancedf1"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.starlegend.advancedf1"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
