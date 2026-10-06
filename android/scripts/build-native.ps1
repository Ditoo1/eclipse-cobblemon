# Compila native/ (Rust) a app/src/main/jniLibs para las ABIs de Android.
# Requisitos: rustup target add aarch64-linux-android armv7-linux-androideabi
#             cargo install cargo-ndk
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

if (-not $env:ANDROID_NDK_HOME) {
    $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
    $ndk = Get-ChildItem "$sdk\ndk" -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $ndk) { throw "No se encontró el NDK en $sdk\ndk" }
    $env:ANDROID_NDK_HOME = $ndk.FullName
}
Write-Host "NDK: $env:ANDROID_NDK_HOME"

Push-Location "$root\native"
try {
    cargo ndk -t arm64-v8a -t armeabi-v7a -P 26 -o "$root\app\src\main\jniLibs" build --release
    if ($LASTEXITCODE -ne 0) { throw "cargo ndk falló" }
} finally {
    Pop-Location
}
Write-Host "libeclipse_core.so -> app/src/main/jniLibs"
