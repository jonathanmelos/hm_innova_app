// settings.gradle.kts — esquema nuevo y mínimo

pluginManagement {
    // Apunta al Gradle de Flutter en tu SDK LOCAL (ajusta la ruta si no es esta)
    includeBuild("C:/flutter/flutter/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// NO pongas versión aquí (la toma del includeBuild de arriba)
plugins {
    id("dev.flutter.flutter-plugin-loader")
}

include(":app")
