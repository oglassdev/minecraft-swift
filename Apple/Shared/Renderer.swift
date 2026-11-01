import MetalKit
import MinecraftCore
import simd

@MainActor
final class Renderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let opaquePipeline: MTLRenderPipelineState
    private let transparentPipeline: MTLRenderPipelineState
    private let breakingPipeline: MTLRenderPipelineState
    private let weatherPipeline: MTLRenderPipelineState
    private let additivePipeline: MTLRenderPipelineState
    private let mapPipeline: MTLRenderPipelineState
    private let writeDepth: MTLDepthStencilState
    private let readDepth: MTLDepthStencilState
    private var textures: VanillaTextures
    private let skyRenderer: SkyRenderer
    private let entityRenderer: EntityRenderer
    private let firstPersonRenderer: FirstPersonRenderer
    private let effectsRenderer: WorldEffectsRenderer
    private let overlays: ScreenOverlays
    private var textureAnimation = LiquidTextureAnimation()
    private var itemTextureAnimation = ItemTextureAnimation()
    private let session: GameSession
    private var previousTime: CFTimeInterval?
    private var fpsTime: CFTimeInterval?
    private var framesSinceFPSReport = 0
    private var lastPresentationTick: Int?
    private var previousFogBrightness: Float = 0
    private var fogBrightness: Float = 0
    private var texturePackRevision: UInt64
    private var meshes: [ChunkPosition: ChunkMesh] = [:]
    private var cachedWorldSeed: Int64?
    private var cachedWorldRevision: UInt64?
    private var cachedDimension: Int8?
    private var cachedSessionGeneration: UInt64?
    private var cachedMeshOptions = BlockMeshOptions()
    private var meshEpoch: UInt64 = 0
    private var meshScheduleCounter: UInt64 = 0
    private var meshJobs: [ChunkPosition: Task<Void, Never>] = [:]
    private var readyMeshes: [MeshResult] = []
    private var breakingCache:
        (position: BlockPosition, revision: UInt64, stage: Int, buffer: MTLBuffer?, count: Int)?

    private struct ChunkMesh {
        let revision: UInt64
        let opaque: MTLBuffer?
        let opaqueCount: Int
        let cutout: MTLBuffer?
        let cutoutCount: Int
        let translucent: MTLBuffer?
        let translucentCount: Int
        var translucentIndices: MTLBuffer?
        let translucentCenters: [SIMD3<Float>]
        var sortedAt: SIMD3<Double>
        let options: BlockMeshOptions
    }

    private struct MeshResult: Sendable {
        let position: ChunkPosition
        let revision: UInt64
        let options: BlockMeshOptions
        let epoch: UInt64
        let sortedAt: SIMD3<Double>
        let geometry: MeshGeometry?
        let indices: [UInt32]
    }

    private struct MeshGeometry: Sendable {
        let opaque: [BlockVertex]
        let cutout: [BlockVertex]
        let translucent: [BlockVertex]
        let centers: [SIMD3<Float>]
    }

    private struct VisibleChunk {
        let position: ChunkPosition
        let mesh: ChunkMesh
        let distance: Double
        let offset: SIMD3<Float>
    }

    private struct MeshCandidate {
        let position: ChunkPosition
        let distance: Double
        let priority: Int
        let missing: Bool
        let sortOnly: Bool
    }

    struct Uniforms {
        var viewProjection: simd_float4x4
        var renderOffset: SIMD3<Float>
        var cameraPosition: SIMD3<Float>
        var fogColor: SIMD3<Float>
        var fogStart: Float
        var fogEnd: Float
        var skySubtraction: Float
        var fogDensity: Float
        var ambientFloor: Float
        var cullLeaves: UInt32 = 0
    }

    enum SetupError: LocalizedError {
        case unavailable(String)
        var errorDescription: String? {
            switch self {
            case .unavailable(let detail): "Metal setup failed: \(detail)"
            }
        }
    }

    init(view: MTKView, session: GameSession) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw SetupError.unavailable("no compatible GPU or command queue")
        }
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor = MTLClearColor(red: 0.57, green: 0.75, blue: 0.95, alpha: 1)
        view.preferredFramesPerSecond = 60
        let library = try device.makeDefaultLibrary(bundle: .main)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "blockVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "blockFragment")
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        self.opaquePipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let attachment = descriptor.colorAttachments[0]!
        attachment.isBlendingEnabled = true
        attachment.sourceRGBBlendFactor = .sourceAlpha
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        self.transparentPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        attachment.destinationRGBBlendFactor = .one
        self.additivePipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.fragmentFunction = library.makeFunction(name: "mapFragment")
        self.mapPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        descriptor.fragmentFunction = library.makeFunction(name: "weatherFragment")
        self.weatherPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        descriptor.fragmentFunction = library.makeFunction(name: "breakFragment")
        attachment.sourceRGBBlendFactor = .destinationColor
        attachment.destinationRGBBlendFactor = .sourceColor
        self.breakingPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = true
        guard let writeDepth = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            throw SetupError.unavailable("could not create depth state")
        }
        depthDescriptor.isDepthWriteEnabled = false
        guard let readDepth = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            throw SetupError.unavailable("could not create transparent depth state")
        }
        self.writeDepth = writeDepth
        self.readDepth = readDepth
        TextureResources.configure(overrideURL: session.texturePackURL, revision: session.texturePackRevision)
        let textures = try VanillaTextures(device: device)
        self.textures = textures
        try InventoryRenderImages.shared.configure(
            device: device, atlas: textures.atlas, library: library, queue: queue)
        self.skyRenderer = try SkyRenderer(
            device: device, library: library, colorFormat: view.colorPixelFormat)
        self.entityRenderer = EntityRenderer(device: device, atlas: textures.atlas, items: textures.items)
        self.firstPersonRenderer = FirstPersonRenderer(
            device: device, atlas: textures.atlas, items: textures.items)
        self.effectsRenderer = WorldEffectsRenderer(device: device, atlas: textures.atlas)
        self.overlays = try ScreenOverlays(
            device: device, library: library, atlas: textures.atlas, colorFormat: view.colorPixelFormat)
        self.device = device
        self.queue = queue
        self.session = session
        self.texturePackRevision = session.texturePackRevision
        super.init()
        view.delegate = self
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        let now = CACurrentMediaTime()
        let delta = Float(min(now - (previousTime ?? now), 1))
        previousTime = now
        session.update(deltaTime: delta)
        reloadTexturePackIfNeeded()
        guard view.drawableSize.width > 0, view.drawableSize.height > 0,
            let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
            let commandBuffer = queue.makeCommandBuffer()
        else { return }
        framesSinceFPSReport += 1
        if let fpsTime, now - fpsTime >= 1 {
            session.fps = Int((Double(framesSinceFPSReport) / (now - fpsTime)).rounded())
            framesSinceFPSReport = 0
            self.fpsTime = now
        } else if fpsTime == nil {
            fpsTime = now
        }

        if session.isLoading || session.worldMenuOpen {
            if cachedWorldSeed != nil {
                meshEpoch &+= 1
                for job in meshJobs.values { job.cancel() }
                readyMeshes.removeAll()
                meshes.removeAll()
                cachedWorldSeed = nil
                breakingCache = nil
            }
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)
            encoder?.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
            return
        }

        let options = session.options
        #if os(macOS)
            let maximumFPS = view.window?.screen?.maximumFramesPerSecond ?? 60
        #else
            let maximumFPS = view.window?.screen.maximumFramesPerSecond ?? 60
        #endif
        let targetFPS = [maximumFPS, 120, 40][min(2, max(0, options.fpsLimit))]
        if view.preferredFramesPerSecond != targetFPS { view.preferredFramesPerSecond = targetFPS }
        let eyePosition = session.cameraPositionDouble
        let partial = session.renderPartialTick
        let portal = session.previousPortalTime + (session.portalTime - session.previousPortalTime) * partial
        let advancedTicks = min(10, max(0, session.tickCount - (lastPresentationTick ?? session.tickCount)))
        lastPresentationTick = session.tickCount
        let textureDelta = Float(advancedTicks) / 20
        firstPersonRenderer.advance(
            heldItem: session.heldItem, slot: session.inventory.selectedHotbar, ticks: advancedTicks)
        let sleeping = session.sleepingBed != nil
        let thirdPerson = session.thirdPerson && !sleeping
        var frameCamera = session.camera
        let cameraPosition: SIMD3<Double>
        if let bed = session.sleepingBed {
            frameCamera = Camera(
                position: .zero,
                yaw: Float((session.world.state(at: bed)?.metadata ?? 0) & 3) * BetaVisualMath.pi / 2,
                pitch: 0)
            cameraPosition = eyePosition + SIMD3(0, 0.12, 0)
        } else {
            cameraPosition =
                thirdPerson
                ? RenderMotion.thirdPersonPosition(
                    world: session.world, eye: eyePosition, forward: frameCamera.forward) : eyePosition
        }
        let origin = SIMD3<Double>(floor(cameraPosition.x / 16) * 16, 0, floor(cameraPosition.z / 16) * 16)
        var camera = frameCamera
        camera.setPosition(Self.relative(cameraPosition, to: origin))
        textureAnimation.encode(
            deltaTime: textureDelta, device: device, atlas: textures.atlas, commandBuffer: commandBuffer)
        itemTextureAnimation.encode(
            delta: textureDelta, compassAngle: session.compassAngle,
            clockAngle: session.clockAngle, device: device, atlas: textures.items,
            commandBuffer: commandBuffer)
        let aspect = Float(view.drawableSize.width / view.drawableSize.height)
        let renderDistance = Float(256 >> min(3, max(0, options.renderDistance)))
        let water = session.player.isEyeUnderwater(in: session.world)
        let lava = session.player.isEyeInLava(in: session.world)
        var fov: Float = water ? 60 : 70
        if session.player.health <= 0 {
            fov /= (1 - 500 / (Float(session.player.deathTime) + partial + 500)) * 2 + 1
        }
        let bobbing = RenderMotion.bobbing(
            player: session.player, partial: partial, enabled: options.viewBobbing)
        let hurt = RenderMotion.hurt(player: session.player, partial: partial)
        let portalTransform = RenderMotion.portal(amount: portal, time: Float(session.tickCount) + partial)
        let cameraEffects = hurt * bobbing * portalTransform
        let projection = Self.perspective(aspect: aspect, far: renderDistance * 2, fov: fov)
        let matrix =
            projection * cameraEffects
            * (thirdPerson || sleeping
                ? matrix_identity_float4x4 : HeldItemGeometry.translation(SIMD3(0, 0, -0.1)))
            * Self.viewMatrix(camera: camera)
        let frustum = RenderFrustum(matrix: matrix)
        refreshMeshes(
            camera: cameraPosition, frustum: frustum, origin: origin, distance: renderDistance,
            options: BlockMeshOptions(
                smoothLighting: options.smoothLighting, fancyLeaves: options.fancyGraphics))
        let climate = session.world.climate(
            atX: Int(floor(eyePosition.x)), z: Int(floor(eyePosition.z)))
        let nether = session.world.dimension == -1
        let sky = BetaSkyState(
            time: session.worldTime, temperature: climate.temperature,
            rain: nether ? 0 : session.rainStrength, thunder: nether ? 0 : session.thunderStrength,
            partialTick: partial, lightningFlash: session.weather.lightningFlashTicks)
        let fogLight = session.world.light(
            at: BlockPosition(Int(floor(eyePosition.x)), Int(floor(eyePosition.y)), Int(floor(eyePosition.z)))
        )
        let lightBrightness = BetaLighting.brightness(
            level: max(Int(fogLight.sky) - (nether ? 0 : Int(sky.skySubtraction)), Int(fogLight.block)),
            ambient: nether ? 0.1 : 0.05)
        let distanceBrightness = Float(3 - min(3, max(0, options.renderDistance))) / 3
        let targetFogBrightness = lightBrightness * (1 - distanceBrightness) + distanceBrightness
        for _ in 0..<advancedTicks {
            previousFogBrightness = fogBrightness
            fogBrightness += (targetFogBrightness - fogBrightness) * 0.1
        }
        let fogDimming = previousFogBrightness + (fogBrightness - previousFogBrightness) * partial
        let fogColor: SIMD3<Float>
        if water {
            fogColor = SIMD3(0.02, 0.02, 0.2) * fogDimming
        } else if lava {
            fogColor = SIMD3(0.6, 0.1, 0) * fogDimming
        } else if nether {
            fogColor = SIMD3(0.2, 0.03, 0.03) * fogDimming
        } else {
            fogColor = sky.renderFogColor(distanceOption: options.renderDistance, brightness: fogDimming)
        }
        let fogEnd = fogDistance(position: cameraPosition, configuredDistance: renderDistance)
        var uniforms = Uniforms(
            viewProjection: matrix, renderOffset: .zero, cameraPosition: camera.position,
            fogColor: fogColor, fogStart: nether ? 0 : fogEnd * 0.25, fogEnd: fogEnd,
            skySubtraction: nether ? 0 : sky.skySubtraction,
            fogDensity: water ? 0.1 : (lava ? 2 : 0), ambientFloor: nether ? 0.1 : 0.05
        )
        pass.colorAttachments[0].clearColor = MTLClearColor(
            red: Double(fogColor.x), green: Double(fogColor.y), blue: Double(fogColor.z), alpha: 0)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        skyRenderer.draw(
            encoder: encoder, center: Self.relative(eyePosition, to: origin), matrix: matrix, state: sky,
            fogColor: fogColor, fogEnd: fogEnd, visible: !nether && options.renderDistance < 2)
        encoder.setRenderPipelineState(opaquePipeline)
        encoder.setDepthStencilState(writeDepth)
        encoder.setCullMode(.back)
        encoder.setFrontFacing(.counterClockwise)
        encoder.setFragmentTexture(textures.atlas, index: 0)
        func bind(offset: SIMD3<Float>) {
            uniforms.renderOffset = offset
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        }
        let squaredRenderDistance = Double(renderDistance * renderDistance)
        var visible: [VisibleChunk] = []
        for (position, mesh) in meshes where frustum.contains(chunk: position, origin: origin) {
            let distance = Self.distanceSquared(chunk: position, camera: cameraPosition)
            guard distance < squaredRenderDistance else { continue }
            visible.append(
                VisibleChunk(
                    position: position, mesh: mesh, distance: distance,
                    offset: Self.relative(
                        SIMD3(Double(position.x * 16), 0, Double(position.z * 16)), to: origin)))
        }
        for chunk in visible {
            bind(offset: chunk.offset)
            draw(buffer: chunk.mesh.opaque, count: chunk.mesh.opaqueCount, encoder: encoder)
        }
        encoder.setCullMode(.none)
        uniforms.cullLeaves = 1
        for chunk in visible {
            bind(offset: chunk.offset)
            draw(buffer: chunk.mesh.cutout, count: chunk.mesh.cutoutCount, encoder: encoder)
        }
        uniforms.cullLeaves = 0
        bind(offset: .zero)
        var renderedEntities = session.entities
        if thirdPerson {
            var local = GameEntity(id: Int64.min, kind: "player", position: session.player.position)
            local.previousPosition = session.player.previousPosition
            local.yaw = session.camera.yaw
            local.pitch = session.camera.pitch
            local.previousYaw = local.yaw
            local.previousPitch = local.pitch
            local.bodyYawDegrees = local.yaw * 180 / BetaVisualMath.pi + 180
            local.previousBodyYawDegrees = local.bodyYawDegrees
            local.limbSwing = session.player.walkedDistance / 0.6 * 4
            local.limbSwingAmount = min(
                1,
                simd_length(SIMD2<Float>(Float(session.player.velocity.x), Float(session.player.velocity.z)))
                    * 4)
            local.previousLimbSwingAmount = local.limbSwingAmount
            local.contents = [session.heldItem] + session.inventory.armor
            local.remoteFlags = session.player.isSneaking ? 2 : 0
            local.health = session.player.health
            local.fireTicks = session.player.fireTicks
            local.hurtTicks = session.player.hurtTime
            local.deathTicks = session.player.deathTime
            local.onGround = session.player.onGround
            local.ageTicks = session.tickCount
            renderedEntities.append(local)
        }
        entityRenderer.draw(
            encoder: encoder, entities: renderedEntities, world: session.world,
            camera: camera, origin: origin, now: now, opaquePipeline: opaquePipeline,
            transparentPipeline: transparentPipeline,
            additivePipeline: additivePipeline, writeDepth: writeDepth, readDepth: readDepth,
            frustum: frustum, visibleChunks: Set(visible.map(\.position)), renderDistance: renderDistance,
            skySubtraction: uniforms.skySubtraction, partialTick: partial)
        encoder.setRenderPipelineState(transparentPipeline)
        encoder.setDepthStencilState(readDepth)
        encoder.setFragmentTexture(textures.atlas, index: 0)
        visible.sort { $0.distance > $1.distance }
        for chunk in visible {
            guard let vertices = chunk.mesh.translucent, let indices = chunk.mesh.translucentIndices,
                chunk.mesh.translucentCount > 0
            else { continue }
            bind(offset: chunk.offset)
            encoder.setVertexBuffer(vertices, offset: 0, index: 0)
            encoder.drawIndexedPrimitives(
                type: .triangle, indexCount: chunk.mesh.translucentCount,
                indexType: .uint32, indexBuffer: indices, indexBufferOffset: 0)
        }
        bind(offset: .zero)
        if let selected = session.selectedBlock {
            if session.miningProgress > 0 {
                bind(
                    offset: Self.relative(
                        SIMD3(
                            Double(selected.position.x), Double(selected.position.y),
                            Double(selected.position.z)), to: origin))
                drawBreaking(position: selected.position, encoder: encoder)
                bind(offset: .zero)
                encoder.setRenderPipelineState(transparentPipeline)
            }
            let vertices = Self.selectionVertices(
                world: session.world, position: selected.position, origin: origin)
            if !vertices.isEmpty {
                encoder.setVertexBytes(
                    vertices, length: vertices.count * MemoryLayout<BlockVertex>.stride, index: 0)
                encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertices.count)
            }
        }
        effectsRenderer.draw(
            encoder: encoder, events: session.takeParticleEvents(), world: session.world,
            camera: camera, origin: origin, delta: delta, rain: session.rainStrength,
            pipeline: transparentPipeline,
            weatherPipeline: weatherPipeline, depth: readDepth, fancy: options.fancyGraphics)
        skyRenderer.drawClouds(
            encoder: encoder, center: Self.relative(eyePosition, to: origin), position: eyePosition,
            matrix: matrix,
            state: sky, ticks: session.tickCount, partial: partial, worldUniforms: uniforms,
            fancy: options.fancyGraphics, visible: !nether)
        encoder.endEncoding()
        pass.colorAttachments[0].loadAction = .load
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1
        if let handEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) {
            let eyeLight = session.world.light(
                at: BlockPosition(
                    Int(floor(cameraPosition.x)),
                    Int(floor(cameraPosition.y)), Int(floor(cameraPosition.z))))
            uniforms.viewProjection = projection * hurt * bobbing
            uniforms.cameraPosition = .zero
            uniforms.fogStart = 100
            uniforms.fogEnd = 200
            uniforms.fogDensity = 0
            if !thirdPerson && !sleeping && !session.hideHUD {
                firstPersonRenderer.draw(
                    encoder: handEncoder,
                    swingProgress: RenderMotion.swing(
                        previous: session.player.previousSwingProgress, current: session.player.swingProgress,
                        partial: partial),
                    partialTick: partial, light: eyeLight.sky << 4 | eyeLight.block,
                    uniforms: uniforms, pipeline: opaquePipeline, mapPipeline: mapPipeline, depth: writeDepth,
                    map: session.heldMap,
                    marker: session.heldMap?.marker(
                        position: cameraPosition,
                        yaw: camera.yaw, dimension: session.world.dimension), pitch: camera.pitch)
            }
            overlays.draw(
                encoder: handEncoder, world: session.world, player: session.player, camera: camera,
                position: eyePosition, projection: projection, skySubtraction: uniforms.skySubtraction,
                portal: portal, fancy: options.fancyGraphics,
                pumpkin: !thirdPerson && session.inventory.armor[3]?.id == 86,
                firstPerson: !thirdPerson && !sleeping)
            handEncoder.endEncoding()
        }
        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { [weak session] buffer in
            if let error = buffer.error {
                let message = error.localizedDescription
                Task { @MainActor in session?.errorMessage = message }
            }
        }
        commandBuffer.commit()
    }

    private func reloadTexturePackIfNeeded() {
        guard texturePackRevision != session.texturePackRevision else { return }
        texturePackRevision = session.texturePackRevision
        TextureResources.configure(overrideURL: session.texturePackURL, revision: texturePackRevision)
        do {
            let textures = try VanillaTextures(device: device)
            let library = try device.makeDefaultLibrary(bundle: .main)
            try skyRenderer.reload(device: device)
            try InventoryRenderImages.shared.configure(
                device: device, atlas: textures.atlas, library: library, queue: queue)
            self.textures = textures
            entityRenderer.reload(atlas: textures.atlas, items: textures.items)
            firstPersonRenderer.reload(atlas: textures.atlas, items: textures.items)
            effectsRenderer.reload(atlas: textures.atlas)
            overlays.reload(atlas: textures.atlas)
            meshEpoch &+= 1
            for job in meshJobs.values { job.cancel() }
            readyMeshes.removeAll()
            meshes.removeAll()
            breakingCache = nil
            cachedWorldSeed = nil
        } catch { session.errorMessage = error.localizedDescription }
    }

    private func drawBreaking(position: BlockPosition, encoder: MTLRenderCommandEncoder) {
        let stage = min(9, max(0, Int(session.miningProgress * 10)))
        if breakingCache?.position != position || breakingCache?.revision != session.world.revision
            || breakingCache?.stage != stage
        {
            let center = SIMD3<Float>(repeating: 0.5)
            let vertices = BlockMesh(world: session.world, blockAt: position, relativeTo: position).vertices
                .map { vertex in
                    let uv = vertex.uv * 16
                    let localUV = SIMD2(uv.x - floor(uv.x), uv.y - floor(uv.y))
                    return BlockVertex(
                        position: center + (vertex.position - center) * 1.004,
                        color: SIMD3(repeating: 1), uv: (SIMD2(Float(stage), 15) + localUV) / 16)
                }
            breakingCache = (
                position, session.world.revision, stage, device.makeSharedBuffer(vertices), vertices.count
            )
        }
        guard let cache = breakingCache else { return }
        encoder.setRenderPipelineState(breakingPipeline)
        encoder.setFragmentTexture(textures.atlas, index: 0)
        draw(buffer: cache.buffer, count: cache.count, encoder: encoder)
    }

    private func refreshMeshes(
        camera: SIMD3<Double>, frustum: RenderFrustum, origin: SIMD3<Double>,
        distance: Float, options: BlockMeshOptions
    ) {
        let world = session.world
        let replacedWorld =
            world.seed != cachedWorldSeed || world.dimension != cachedDimension
            || world.revision < (cachedWorldRevision ?? 0)
            || session.sessionGeneration != cachedSessionGeneration
        if replacedWorld || options != cachedMeshOptions {
            meshEpoch &+= 1
            for job in meshJobs.values { job.cancel() }
            readyMeshes.removeAll()
            if replacedWorld { meshes.removeAll() }
        }
        cachedMeshOptions = options
        cachedWorldSeed = world.seed
        cachedWorldRevision = world.revision
        cachedDimension = world.dimension
        cachedSessionGeneration = session.sessionGeneration
        let retainedDistance = Double(distance + 32)
        let stale = meshes.keys.filter {
            world.chunks[$0] == nil
                || Self.distanceSquared(chunk: $0, camera: camera) >= retainedDistance * retainedDistance
        }
        for position in stale { meshes[position] = nil }
        let uploadDeadline = CACurrentMediaTime() + 0.004
        var uploaded = 0
        readyMeshes.sort {
            Self.distanceSquared(chunk: $0.position, camera: camera)
                > Self.distanceSquared(chunk: $1.position, camera: camera)
        }
        while !readyMeshes.isEmpty && uploaded < 2 && CACurrentMediaTime() < uploadDeadline {
            let result = readyMeshes.removeLast()
            guard result.epoch == meshEpoch, result.options == options,
                world.chunks[result.position] != nil,
                (world.chunkRevisions[result.position] ?? 0) == result.revision,
                Self.distanceSquared(chunk: result.position, camera: camera) < retainedDistance
                    * retainedDistance
            else { continue }
            if let geometry = result.geometry {
                meshes[result.position] = ChunkMesh(
                    revision: result.revision,
                    opaque: device.makeSharedBuffer(geometry.opaque), opaqueCount: geometry.opaque.count,
                    cutout: device.makeSharedBuffer(geometry.cutout), cutoutCount: geometry.cutout.count,
                    translucent: device.makeSharedBuffer(geometry.translucent),
                    translucentCount: geometry.translucent.count,
                    translucentIndices: device.makeSharedBuffer(result.indices),
                    translucentCenters: geometry.centers,
                    sortedAt: result.sortedAt, options: result.options)
            } else {
                guard var mesh = meshes[result.position], mesh.revision == result.revision,
                    mesh.options == result.options, mesh.translucentCount == result.indices.count,
                    !TranslucentSort.needsUpdate(from: result.sortedAt, to: camera),
                    let indices = device.makeSharedBuffer(result.indices)
                else { continue }
                mesh.translucentIndices = indices
                mesh.sortedAt = result.sortedAt
                meshes[result.position] = mesh
            }
            uploaded += 1
        }
        let waiting = Set(readyMeshes.map(\.position))
        let capacity = max(0, 2 - meshJobs.count - readyMeshes.count)
        guard capacity > 0 else { return }
        var candidates: [MeshCandidate] = []
        for position in world.chunks.keys {
            let squaredDistance = Self.distanceSquared(chunk: position, camera: camera)
            guard squaredDistance < Double(distance * distance), meshJobs[position] == nil,
                !waiting.contains(position)
            else { continue }
            let revision = world.chunkRevisions[position] ?? 0
            let sortOnly: Bool
            if let mesh = meshes[position], mesh.revision == revision, mesh.options == options {
                guard !mesh.translucentCenters.isEmpty,
                    TranslucentSort.needsUpdate(from: mesh.sortedAt, to: camera),
                    frustum.contains(chunk: position, origin: origin)
                else { continue }
                sortOnly = true
            } else {
                sortOnly = false
            }
            let priority: Int
            if squaredDistance < 1024 {
                priority = 0
            } else if frustum.contains(chunk: position, origin: origin) {
                priority = 1
            } else {
                priority = 2
            }
            candidates.append(
                MeshCandidate(
                    position: position, distance: squaredDistance, priority: priority,
                    missing: meshes[position] == nil, sortOnly: sortOnly))
        }
        candidates.sort { a, b in
            a.priority == b.priority ? a.distance < b.distance : a.priority < b.priority
        }
        let epoch = meshEpoch
        let colorMaps = textures.colorMaps
        for _ in 0..<min(capacity, candidates.count) {
            let candidateIndex =
                meshScheduleCounter & 1 == 1
                ? candidates.firstIndex(where: \.missing) ?? 0 : 0
            let candidate = candidates.remove(at: candidateIndex)
            meshScheduleCounter &+= 1
            let position = candidate.position
            let revision = world.chunkRevisions[position] ?? 0
            let localCamera = Self.relative(
                camera, to: SIMD3(Double(position.x * 16), 0, Double(position.z * 16)))
            let task: Task<MeshResult, Never>
            if candidate.sortOnly, let centers = meshes[position]?.translucentCenters {
                task = Task.detached(priority: .userInitiated) {
                    MeshResult(
                        position: position, revision: revision, options: options, epoch: epoch,
                        sortedAt: camera, geometry: nil,
                        indices: TranslucentSort.indices(centers: centers, camera: localCamera))
                }
            } else {
                task = Task.detached(priority: .userInitiated) {
                    let mesh = BlockMesh(
                        world: world, chunk: position, colorMaps: colorMaps,
                        relativeTo: BlockPosition(position.x * 16, 0, position.z * 16), options: options)
                    let centers = mesh.translucentFaces.map(\.center)
                    let geometry = MeshGeometry(
                        opaque: mesh.opaqueVertices, cutout: mesh.cutoutVertices,
                        translucent: mesh.translucentFaces.flatMap(\.vertices), centers: centers)
                    return MeshResult(
                        position: position, revision: revision, options: options, epoch: epoch,
                        sortedAt: camera, geometry: geometry,
                        indices: TranslucentSort.indices(centers: centers, camera: localCamera))
                }
            }
            meshJobs[position] = Task { [weak self] in
                let result = await task.value
                guard let self else { return }
                self.meshJobs[position] = nil
                guard !Task.isCancelled, self.meshEpoch == epoch,
                    (self.session.world.chunkRevisions[position] ?? 0) == revision,
                    self.session.world.chunks[position] != nil
                else { return }
                self.readyMeshes.append(result)
            }
        }
    }

    private func draw(buffer: MTLBuffer?, count: Int, encoder: MTLRenderCommandEncoder) {
        guard let buffer, count > 0 else { return }
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: count)
    }

    private func fogDistance(position: SIMD3<Double>, configuredDistance: Float) -> Float {
        var minimum = SIMD2(Int.max, Int.max)
        var maximum = SIMD2(Int.min, Int.min)
        for chunk in session.world.chunks.keys {
            minimum = pointwiseMin(minimum, SIMD2(chunk.x, chunk.z))
            maximum = pointwiseMax(maximum, SIMD2(chunk.x, chunk.z))
        }
        guard minimum.x <= maximum.x else { return 32 }
        let distance = min(
            position.x - Double(minimum.x * 16), Double((maximum.x + 1) * 16) - position.x,
            position.z - Double(minimum.y * 16), Double((maximum.y + 1) * 16) - position.z)
        return Float(max(16, min(Double(configuredDistance) - 4, distance - 4)))
    }

    private static func selectionVertices(world: BlockWorld, position: BlockPosition, origin: SIMD3<Double>)
        -> [BlockVertex]
    {
        guard let state = world.state(at: position) else { return [] }
        let edges = [0, 1, 0, 2, 0, 4, 1, 3, 1, 5, 2, 3, 2, 6, 3, 7, 4, 5, 4, 6, 5, 7, 6, 7]
        return BlockCollision.selectionBoxes(for: state, at: position).flatMap { box in
            let minimum =
                relative(box.min, to: origin) - SIMD3(repeating: 0.003)
            let maximum =
                relative(box.max, to: origin) + SIMD3(repeating: 0.003)
            let corners = (0..<8).map { index in
                SIMD3(
                    index & 1 == 0 ? minimum.x : maximum.x,
                    index & 2 == 0 ? minimum.y : maximum.y,
                    index & 4 == 0 ? minimum.z : maximum.z)
            }
            return edges.map {
                BlockVertex(position: corners[$0], color: .zero, opacity: 0.55, textureWeight: 0)
            }
        }
    }

    private static func relative(_ point: SIMD3<Double>, to origin: SIMD3<Double>) -> SIMD3<Float> {
        let value = point - origin
        return SIMD3(Float(value.x), Float(value.y), Float(value.z))
    }

    private static func perspective(aspect: Float, far: Float = 256, fov: Float = 70) -> simd_float4x4 {
        let near: Float = 0.05
        let y: Float = 1 / tan(fov * BetaVisualMath.pi / 360)
        let z = far / (near - far)
        return simd_float4x4(
            columns: (
                SIMD4(y / aspect, 0, 0, 0), SIMD4(0, y, 0, 0),
                SIMD4(0, 0, z, -1), SIMD4(0, 0, z * near, 0)
            ))
    }

    static func distanceSquared(chunk: ChunkPosition, camera: SIMD3<Double>) -> Double {
        let dx = max(0, Double(chunk.x * 16) - camera.x, camera.x - Double((chunk.x + 1) * 16))
        let dz = max(0, Double(chunk.z * 16) - camera.z, camera.z - Double((chunk.z + 1) * 16))
        return dx * dx + dz * dz
    }

    private static func viewMatrix(camera: Camera) -> simd_float4x4 {
        let forward = camera.forward
        let right = SIMD3<Float>(cos(camera.yaw), 0, sin(camera.yaw))
        let up = simd_cross(right, forward)
        let position = camera.position
        return simd_float4x4(
            columns: (
                SIMD4(right.x, up.x, -forward.x, 0), SIMD4(right.y, up.y, -forward.y, 0),
                SIMD4(right.z, up.z, -forward.z, 0),
                SIMD4(-simd_dot(right, position), -simd_dot(up, position), simd_dot(forward, position), 1)
            ))
    }
}
