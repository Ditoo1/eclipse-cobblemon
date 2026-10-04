#!/usr/bin/env bash
# PREPARADO PARA EL FUTURO (no se usa todavía): compila native/ como XCFramework para iOS.
# Ejecutar en macOS con Xcode:
#   rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
set -euo pipefail
cd "$(dirname "$0")/../native"

cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
cargo build --release --target x86_64-apple-ios

mkdir -p target/ios-sim
lipo -create \
  target/aarch64-apple-ios-sim/release/libeclipse_core.a \
  target/x86_64-apple-ios/release/libeclipse_core.a \
  -output target/ios-sim/libeclipse_core.a

rm -rf ../ios/EclipseCore.xcframework
xcodebuild -create-xcframework \
  -library target/aarch64-apple-ios/release/libeclipse_core.a -headers include \
  -library target/ios-sim/libeclipse_core.a -headers include \
  -output ../ios/EclipseCore.xcframework

echo "ios/EclipseCore.xcframework listo"
