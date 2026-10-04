pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven("https://jitpack.io") // dependencias de Amethyst
    }
}
rootProject.name = "EclipseCobblemon"
include(":app")
include(":amethyst")          // runtime Amethyst/Pojav vendorizado (LGPL-3.0)
// Dependencia nativa de Amethyst. El nombre del proyecto debe ser "androidnsbypass":
// es el nombre del paquete prefab que importa su Android.mk.
include(":androidnsbypass")
project(":androidnsbypass").projectDir = file("amethyst-nsbypass")
