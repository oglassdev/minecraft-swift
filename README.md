# Minecraft Swift

Private project working toward a faithful **Minecraft Beta 1.7.3** port in Swift and Metal,
targeting macOS and iOS. This first milestone is a small renderer prototype: a deterministic
block scene, exposed-face meshing, depth testing, directional face shading, distance fog,
and free-flight controls. It contains no Minecraft source, textures, sounds, or other assets.

## Run on macOS

Requires Swift 6.0+, full Xcode with the Metal toolchain, and a Metal-capable Mac.
Minimum deployment target: macOS 14.

```sh
cd minecraft-swift
just run
```

`just` is optional. The equivalent commands are:

```sh
xcodebuild -quiet -project Apple/MinecraftSwift.xcodeproj \
  -scheme MinecraftMac -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build/apple CODE_SIGNING_ALLOWED=NO build
open .build/apple/Build/Products/Debug/MinecraftSwift.app
```

You can also open `Apple/MinecraftSwift.xcodeproj`, select **MinecraftMac**, and Run.
The project is generated and checked in; XcodeGen is only needed to change its structure.
If Xcode reports a missing Metal toolchain, install Apple's component with
`xcodebuild -downloadComponent MetalToolchain`.

Click the scene to capture the pointer, then use:

| Input | Action |
| --- | --- |
| W / A / S / D | Move relative to camera heading |
| Mouse | Look |
| Space / Control | Rise / descend |
| Shift | Move faster |
| Escape | Release pointer and stop movement |

Losing window focus also releases the pointer and clears held inputs. This milestone uses
free flight: there is no gravity, collision, mining, or block placement yet.

## Portable core and Linux

The root is a dependency-free Swift package. It uses Swift standard-library SIMD values
and cross-platform Foundation math; it does not import Metal, simd, AppKit, UIKit, or SwiftUI.

```sh
swift build
swift test
```

Run those commands on Linux with Swift 6.0 or newer. CI is intentionally not configured.
The Apple app is intentionally outside the package target, so Linux never compiles Apple UI
or shaders. No Linux graphical renderer is included.

## iPhone path

The **MinecraftIOS** target already uses the same `Renderer.swift`, Metal shaders, scene,
mesher, camera, and game session as macOS. Only the view adapter and input handling differ.
Minimum deployment target: iOS 17. The app uses landscape orientation.

```sh
just build-ios
# Or:
xcodebuild -quiet -project Apple/MinecraftSwift.xcodeproj \
  -scheme MinecraftIOS -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/apple CODE_SIGNING_ALLOWED=NO build
```

In Xcode, choose **MinecraftIOS**, select an iPhone simulator, and Run. Touch controls:
drag on the left to move, drag on the right to look, and hold ▲ / ▼ to rise / descend.
For a physical iPhone, select your signing team in Xcode and run the target on the device;
the unsigned command above is only for Simulator.

## Small project tooling

- `Sources/MinecraftCore/`: portable world, mesh, and camera.
- `Tests/MinecraftCoreTests/`: focused meshing and camera behavior tests.
- `Apple/Shared/`: renderer, shaders, game session, and SwiftUI app.
- `Apple/macOS/`, `Apple/iOS/`: platform view adapters and input.
- `just format` / `just lint`: the Swift toolchain's formatter and linter.
- `just generate`: regenerate the Xcode project after editing `Apple/project.yml`
  (requires XcodeGen 2.44+).

The package has no external dependencies. `just` and XcodeGen are optional development
tools; neither is needed to build the checked-in project directly with Xcode.

## Milestone verification

Verified on November 1, 2026 with Swift 6.3.3 and Xcode 26.6 on an Apple Silicon Mac:

- All six core tests pass, covering exposed-face meshing, triangle winding, deterministic
  scene construction, camera movement speed and heading, and look-angle bounds.
- Both macOS and iOS Simulator targets build, including their Metal shaders.
- The macOS app launches and renders the scene with Metal API validation enabled and no
  reported errors. Forward movement, rise/descend, faster movement, pointer capture, and
  Escape release were exercised through native UI automation.
- The iPhone 17 Pro simulator launches and renders the same scene in landscape.
- Swift formatting and lint checks pass.

Not verified: execution on Linux (no local Linux runtime),
physical iPhone rendering/signing, touch gestures, and physical relative mouse input.
The UI automation's pointer drags did not provide usable relative mouse deltas, so mouse
look still needs a hands-on check. Camera rotation logic is covered by the core tests.

## Scope after this milestone

Faithful Beta behavior remains future work: seeded terrain and chunk storage, fixed-step
simulation, player collision and physics, block interactions, inventory, lighting, saving,
audio, and any authorized asset work. The current scene is hand-built placeholder terrain.
The repository is private at https://github.com/oglassdev/minecraft-swift.
