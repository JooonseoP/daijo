pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    // 2.1.0 (not the Flutter-template default 1.8.22): native_geofence uses
    // kotlinx.serialization, whose compiler plugin (kotlin-serialization-compiler-plugin-embeddable)
    // is not published for 1.8.22. Compatible with Gradle 8.10.2 / AGP 8.7.0.
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
