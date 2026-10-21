plugins {
    id("com.android.application")
}

// The version, from the pre-release workflow: -PversionName=X.Y.Z (the tag)
// and -PversionCode=N (the run's number).
val twaVersionName = providers.gradleProperty("versionName").getOrElse("0.0.0")
val twaVersionCode = providers.gradleProperty("versionCode").getOrElse("1").toInt()

// Release signing, from the environment, never from a file in the
// repository: TWA_KEYSTORE (the keystore's path), TWA_KEYSTORE_PASSWORD,
// TWA_KEY_ALIAS and TWA_KEY_PASSWORD. The workflow sets them from the
// ANDROID_TWA_* secrets when they exist, and otherwise from a key it
// generates for the run. Without them, the release APK is left unsigned
// (app-release-unsigned.apk).
val twaKeystore = providers.environmentVariable("TWA_KEYSTORE").orNull?.takeIf { it.isNotBlank() }

android {
    namespace = "org.shnayimmikrah.web"
    // As android/ (Flutter's defaults: compileSdk and targetSdk 36).
    compileSdk = 36

    defaultConfig {
        applicationId = "org.shnayimmikrah.web"
        minSdk = 24
        targetSdk = 36
        versionCode = twaVersionCode
        versionName = twaVersionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (twaKeystore != null) {
            create("release") {
                storeFile = file(twaKeystore)
                storePassword = providers.environmentVariable("TWA_KEYSTORE_PASSWORD").get()
                keyAlias = providers.environmentVariable("TWA_KEY_ALIAS").get()
                keyPassword = providers.environmentVariable("TWA_KEY_PASSWORD").get()
            }
        }
    }

    buildTypes {
        release {
            // androidbrowserhelper brings AppCompat and Guava, little of
            // which the launcher uses.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            if (twaKeystore != null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    implementation("com.google.androidbrowserhelper:androidbrowserhelper:2.7.4")
}
