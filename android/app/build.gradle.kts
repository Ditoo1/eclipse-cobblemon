import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Firma de release fuera del repo (../../EclipseCobblemon-signing, junto a la carpeta del repo), o donde indique
// ECLIPSE_SIGNING_PROPS. Sin ella, el release queda sin firmar.
val signingProps = Properties().apply {
    val f = file(System.getenv("ECLIPSE_SIGNING_PROPS") ?: "../../../EclipseCobblemon-signing/keystore.properties")
    if (f.isFile) f.inputStream().use(::load)
}

android {
    namespace = "dev.eclipsecobblemon.launcher"
    compileSdk = 37

    defaultConfig {
        applicationId = "dev.eclipsecobblemon.launcher"
        minSdk = 26
        // Igual que Amethyst: su runtime está probado con targetSdk 34
        targetSdk = 34
        // release.yml los pasa con -PversionCode / -PversionName
        versionCode = (findProperty("versionCode") as String?)?.toInt() ?: 1
        versionName = findProperty("versionName") as String? ?: "0.1.0"
    }

    signingConfigs {
        if (signingProps.containsKey("storeFile")) create("release") {
            storeFile = file(signingProps.getProperty("storeFile"))
            storePassword = signingProps.getProperty("storePassword")
            keyAlias = signingProps.getProperty("keyAlias")
            keyPassword = signingProps.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.findByName("release")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    packaging {
        jniLibs {
            // Amethyst carga JRE, LWJGL y renderers desde nativeLibraryDir: las .so deben extraerse.
            useLegacyPackaging = true
            // Como app, Amethyst prioriza sus .so propias sobre las de sus AARs; como librería hay que desempatar.
            pickFirsts += listOf("**/libbytehook.so", "**/libc++_shared.so", "**/libglxshim.so", "**/libandroidnsbypass.so")
        }
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(project(":amethyst"))

    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-core")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    debugImplementation("androidx.compose.ui:ui-tooling")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
