default:
    @just --list

# Portable package commands; also run these on Linux.
build:
    swift build

test:
    swift test

format:
    swift format format --in-place --recursive Package.swift Sources Tests Apple

lint:
    swift format lint --strict --recursive Package.swift Sources Tests Apple

assets:
    python3 Tools/import_assets.py
    python3 Tools/convert_audio.py

reference:
    python3 Tools/prepare_reference.py

build-mac: assets
    xcodebuild -quiet -project Apple/MinecraftSwift.xcodeproj -scheme MinecraftMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/apple CODE_SIGNING_ALLOWED=NO build

run: build-mac
    open .build/apple/Build/Products/Debug/MinecraftSwift.app

build-ios: assets
    xcodebuild -quiet -project Apple/MinecraftSwift.xcodeproj -scheme MinecraftIOS -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/apple CODE_SIGNING_ALLOWED=NO build

# Only needed after changing project.yml; the generated project is committed.
generate:
    xcodegen generate --spec Apple/project.yml
