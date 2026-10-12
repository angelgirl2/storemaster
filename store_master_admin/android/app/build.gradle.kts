import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    FileInputStream(signingPropertiesFile).use { signingProperties.load(it) }
}
val configuredStoreFile = signingProperties.getProperty("storeFile")?.let { rootProject.file(it) }

android {
    namespace = "com.storemasteradmin.angelgirlbrand"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.storemasteradmin.angelgirlbrand"
        minSdk = flutter.minSdkVersion
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += setOf(
                "arm64-v8a",
                "x86_64"
            )
        }
    }

    signingConfigs {
        create("release") {
            if (configuredStoreFile != null && configuredStoreFile.exists()) {
                storeFile = configuredStoreFile
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        getByName("debug")

        getByName("release") {
            if (configuredStoreFile != null && configuredStoreFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }

            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        )
    }
}

subprojects {
    afterEvaluate {
        extensions
            .findByType<com.android.build.api.dsl.ApplicationExtension>()
            ?.compileSdk = 36

        extensions
            .findByType<com.android.build.api.dsl.LibraryExtension>()
            ?.compileSdk = 36
    }
}

flutter {
    source = "../.."
}
