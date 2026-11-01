# Minecraft Swift

Private Swift and Metal project aiming toward a faithful Minecraft Beta 1.7.3 port.
The first milestone is a placeholder block scene with free-flight controls.

## General guidelines

- Do not edit AGENTS.md or CLAUDE.md unless explicitly asked.
- Keep changes simple, type safe, and scoped to the current milestone.
- Keep Minecraft source, assets, credentials, and third-party dependencies out unless explicitly authorized.
- Keep the core buildable on Linux. Apple frameworks belong under Apple/.
- Do not revert unrelated changes or publish this private project without authorization.

## Tooling

- Swift 6.0 or newer; use `swift build` and `swift test` for the portable package.
- `just` lists the optional convenience commands. All underlying commands are in Justfile.
- `just run` builds and opens the macOS app; `just build-ios` builds for iOS Simulator.
- Use `just format` and `just lint` with the toolchain's swift-format.
- The Xcode project is checked in. After editing Apple/project.yml, run `just generate` with XcodeGen.
- Test the behavior being changed. Avoid full app rebuilds for core-only edits and avoid redundant checks.
- Check for existing running apps or dev utilities before starting new ones; clean up processes you start.

## Code style and Git

- Prefer value types and explicit public API boundaries in the shared package.
- Keep UI and Metal access on the main actor; keep portable simulation independent of rendering.
- Use comments sparingly to explain the behavior they accompany.
- Use Conventional Commits. Keep generated build output and local signing settings out of Git.

## Glossary

- Core: the MinecraftCore Swift package, shared with Linux.
- Block world: integer block positions mapped to solid block kinds; missing positions are air.
- Mesh: outward-facing triangles emitted for exposed block faces.
- Free flight: temporary camera movement without collision, gravity, or Beta player physics.
