# Minecraft Swift

Private Swift and Metal port of **Minecraft Beta 1.7.3**, targeting macOS 14+ and
iOS 17+. The portable Swift package contains the world and simulation; both Apple apps
share the Metal renderer and game session. This is a playable port under development,
with substantial original-behavior coverage, not yet complete Beta parity.

## Run

Requires Swift 6+, full Xcode with its Metal toolchain, Python 3, and `ffmpeg` for the
one-time audio conversion. `just` is optional.

```sh
cd minecraft-swift
just run
```

The first run downloads verified original client textures and legacy audio into an
ignored local directory. Subsequent runs use that cache. The equivalent commands are:

```sh
python3 Tools/import_assets.py
python3 Tools/convert_audio.py
xcodebuild -quiet -project Apple/MinecraftSwift.xcodeproj \
  -scheme MinecraftMac -configuration Release -destination 'platform=macOS' \
  -derivedDataPath .build/apple CODE_SIGNING_ALLOWED=NO build
open .build/apple/Build/Products/Release/MinecraftSwift.app
```

The run command uses an optimized Release build. Debug builds retain expensive Swift
checks and are intended for debugging. If Xcode reports a missing Metal toolchain, install it with
`xcodebuild -downloadComponent MetalToolchain`. The checked-in Xcode project also works
directly: select **MinecraftMac** and Run after importing assets.

Choose a saved world or create one with a name and optional seed. The title screen also
supports connecting to an offline-mode Beta 1.7.3 server. Singleplayer saves live in
`~/Library/Application Support/MinecraftSwift/saves/` on macOS; iOS uses the app's
Application Support directory. Options and statistics live beside `saves`.

| Input | Action |
| --- | --- |
| Click the scene | Capture pointer |
| W / A / S / D, mouse | Move and look |
| Space, Shift | Jump, sneak |
| Hold left click, right click | Mine/attack, use/place/interact |
| 1–9, scroll wheel | Select hotbar slot |
| E | Inventory and crafting |
| Q | Drop selected item |
| T / Return | Chat |
| Escape | Close panel, release pointer, pause |
| F / Shift-F | Cycle fog distance |
| F1 / F3 / F5 / F8 | Hide HUD, debug display, third-person view, smooth camera |
| F2 / F11 | Screenshot, fullscreen |
| Control-F | Development flight toggle |

In inventory, click to move/merge a stack; right click splits a stack or places one item.
Shift-click follows the original container transfer rules. Key bindings are editable in
Options → Controls. Texture packs can be selected from the title screen; ZIP archives
go in `~/Library/Application Support/MinecraftSwift/texturepacks/`.
Flight uses Space to rise, Shift/Control to descend, and Option to move faster.

## iPhone

```sh
just build-ios
```

Choose **MinecraftIOS** and an iPhone simulator in Xcode, then Run. It uses the same
renderer, simulation, atlas, sounds, and saves. Drag the left half to move and the right
half to look; use the on-screen mine/place/jump/sneak controls and inventory/hotbar.
Long press an inventory slot for the secondary stack action. Physical devices require
your signing team in Xcode.

## Portable development

```sh
swift build
swift test
```

The core imports Foundation and system zlib, with no Apple UI or graphics dependencies.
On Debian/Ubuntu, install `zlib1g-dev` and Swift 6+. No Linux graphical renderer or CI
is configured. Linux execution still needs verification on a Linux machine.

- `Sources/MinecraftCore/`: chunks, generation, lighting, physics, entities, blocks,
  inventory, maps, persistence, statistics, and the portable Beta protocol codec.
- `Apple/Shared/`: Metal rendering, native audio, session, menus, and gameplay UI.
- `Apple/macOS/`, `Apple/iOS/`: platform input and lifecycle adapters.
- `Tests/MinecraftCoreTests/`: source-derived fixtures and behavioral tests.
- `Tools/reference/`: authored Java oracle harnesses; generated reference files stay local.

`just format` / `just lint` use the Swift toolchain formatter. `just generate` regenerates
the Xcode project after adding files or changing `Apple/project.yml` (XcodeGen 2.44+).
There are no third-party Swift dependencies.

## Current implementation

- Original 128-block Overworld and Nether generation, climate, caves, ores, trees,
  dungeons, vegetation, springs, population, and Far Lands arithmetic.
- Original bitmap menus, integer GUI scaling, HUD, inventory/crafting/container clicks,
  achievements, chat, death/pause screens, controls, and local texture-pack selection.
- Fixed 20 Hz player/entity simulation, collision, damage, armor, survival inventory,
  crafting/smelting, fluids, fire, growth, redstone, rails, pistons, and containers.
- Source atlas selections and special block geometry, smooth lighting, fog, day/night,
  clouds/stars, weather, particles, animated textures, mobs, vehicles, and held items.
- Gzip NBT `level.dat`, McRegion chunks, both dimensions, maps, legacy world conversion,
  weather, options, statistics/achievements, and asynchronous world streaming/saves.
- All 57 Beta protocol 14 packet types and authoritative multiplayer inventory/world
  updates. An original offline-mode server has been used for local integration checks.
- Original local textures, 183 sound variants, 12 music tracks, and two records, converted
  once to formats handled by native Apple audio.

The tests compare against original Java outputs for terrain/population hashes, portals,
light arrays, block textures, packet bytes, movement, item/map behavior, NBT, and other
selected mechanics. These checks establish the sampled behavior; they do not establish
complete game parity. Remaining differences include some mob AI/animation details,
particle simulation, menu scrolling/diagnostics, asynchronous world population random
ordering, some nested block callbacks, and legacy online authentication. Anaglyph and
Advanced OpenGL are unavailable. Physical iPhone performance, Linux execution, and
physical relative mouse input still require verification; mobile controls retain the
existing touch implementation.

Verified November 1, 2026 with Swift 6.3.3 and Xcode 26.6: all 167 core tests and
strict formatting pass; the unified macOS Release and iOS Simulator builds pass.
The macOS scene sustained approximately 118–120 FPS at 854×480 points in the existing
forest save with more than 250 entities. Native checks covered movement, inventory
right-click splitting/merging, Shift-click transfers, F1/F3/F5, and saving. The entity
benchmark matches the pose/velocity/yaw/health/age digest and event count after
replacing repeated full entity scans with an ordered spatial index. Its 400-entity
Release workload fell from 18.02 to 2.20 ms per tick; Debug fell from 215.79 to
26.14 ms per tick, with simulation rates and mob caps preserved. Source oracle checks also cover all font
metrics, 328 container slot positions, 216 sky-color cases, and 25,872 cloud vertices.
These are sampled checks, not a claim of complete 1:1 behavior. The original-server loopback passed joining, chat, inventory split/crafting transactions,
remote player and arrow interpolation, singleplayer restoration, and death-to-title
overlay cleanup. The 36-pose arrow oracle matches all 1,296 vertices within 0.000001;
offscreen Metal checks render inventory icons and the player at GUI scales 1–4. The revised iOS app
loaded a saved world and rendered the shared scene under Metal API validation;
simulator touch automation remained unreliable. F2 screenshot
capture and physical relative mouse behavior still need manual verification.

The longer spring-generation regression loads 1,089 chunks and populates 900 on a
512 KiB cooperative thread stack. Run it separately with:

```sh
MINECRAFT_FLUID_STRESS=1 swift test --filter FluidGenerationTests
```

## Local reference and assets

```sh
just assets
just reference
```

`assets` verifies pinned official client/index hashes, extracts textures, downloads the
legacy sound resources, and converts audio with `ffmpeg`. `reference` additionally
prepares a pinned local decompiler and class-name mapping for comparison. Neither is
needed to build or test the portable core. Original assets and generated/decompiled
reference code are ignored by Git; only authored Swift, tools, and numeric fixtures are
committed. The legacy audio index spans later releases too; the playback event table
selects the Beta sounds.

Repository: <https://github.com/oglassdev/minecraft-swift> (private).
