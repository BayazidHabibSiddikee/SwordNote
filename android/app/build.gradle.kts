plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.swordnote.swordnote"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.swordnote.swordnote"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Native build config — mirrors CupCake's pattern
        externalNativeBuild {
            cmake {
                arguments.addAll(
                    listOf(
                        "-DCMAKE_BUILD_TYPE=Release",
                        "-DANDROID_ARM_NEON=TRUE",
                        "-DGGML_OPENMP=OFF",
                        "-DGGML_LLAMAFILE=OFF",
                    )
                )
                cppFlags.addAll(listOf("-O3", "-DNDEBUG"))
                cFlags.addAll(listOf("-O3", "-DNDEBUG"))
            }
        }

        ndk {
            abiFilters.addAll(listOf("arm64-v8a"))
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            isMinifyEnabled = false
            isDebuggable = true
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            ndk {
                abiFilters.add("arm64-v8a")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/swordnote/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    // Don't compress GGUF models — they're large binary files
    androidResources {
        noCompress += "gguf"
    }

    packagingOptions {
        jniLibs {
            pickFirsts.add("lib/swordnote_jni.so")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Future: Add TensorFlow Lite for on-device vision models
    // implementation("org.tensorflow:tensorflow-lite:2.14.0")
}
