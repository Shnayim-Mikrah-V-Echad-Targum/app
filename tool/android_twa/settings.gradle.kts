// The Android web app: a Trusted Web Activity that opens
// https://shnayimmikrah.org/ in the reader's browser, full screen, as an app
// of its own (org.shnayimmikrah.web, beside the native org.shnayimmikrah.app).
// The pre-release workflow (.github/workflows/prerelease.yml) builds it:
//
//   gradle -p tool/android_twa assembleRelease -PversionName=X.Y.Z -PversionCode=N
//
// with Gradle and the Android Gradle Plugin at the versions android/ uses
// (test/app/twa_project_test.dart keeps them together). docs/RELEASE.md
// (Pre-releases) has the details.
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    // As android/settings.gradle.kts.
    id("com.android.application") version "9.1.0" apply false
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "shnayim_mikrah_web"
include(":app")
