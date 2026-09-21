group = "music.mstream.now_playing_widget"
version = "0.1.0"

buildscript {
    val kotlinVersion = "2.3.20"
    val agpVersion = "9.0.1"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:$agpVersion")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

// AGP 9 compiles Kotlin itself; older AGP needs the standalone plugin
// (mirrors packages/wifi_lock_shim).
val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()
if (agpMajor < 9) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

android {
    namespace = "music.mstream.now_playing_widget"
    compileSdk = 35

    defaultConfig {
        // requestPinAppWidget is API 26; the app's minSdk is 26 as well.
        minSdk = 26
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

project.extensions.configure(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java) {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // MediaButtonReceiver + PlaybackStateCompat: the buttons are media-key
    // broadcasts to audio_service's receiver (same version audio_service pins).
    implementation("androidx.media:media:1.7.0")
    implementation("androidx.core:core:1.13.1")
    testImplementation("junit:junit:4.13.2")
}
