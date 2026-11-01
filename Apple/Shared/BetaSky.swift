import Foundation
import MetalKit
import MinecraftCore
import simd

struct BetaSkyState {
    let celestialAngle: Float
    let skyColor: SIMD3<Float>
    let fogColor: SIMD3<Float>
    let cloudColor: SIMD3<Float>
    let starBrightness: Float
    let skySubtraction: Float
    let celestialOpacity: Float
    let sunriseColor: SIMD4<Float>?
    private let rain: Float
    private let thunder: Float

    init(
        time: Int64, temperature: Double, rain: Float = 0, thunder: Float = 0, partialTick: Float = 0,
        lightningFlash: Int = 0
    ) {
        var angle = (Float(time % 24000) + partialTick) / 24000 - 0.25
        if angle < 0 { angle += 1 }
        if angle > 1 { angle -= 1 }
        let originalAngle = angle
        angle = 1 - Float((cos(Double(angle) * .pi) + 1) / 2)
        celestialAngle = originalAngle + (angle - originalAngle) / 3
        let phase = celestialAngle * BetaVisualMath.pi * 2
        let daylight = min(1, max(0, Self.cosine(phase) * 2 + 0.5))
        let biomeTemperature = min(1, max(-1, Float(temperature) / 3))
        let rain = min(1, max(0, rain))
        let thunder = min(1, max(0, thunder))
        self.rain = rain
        self.thunder = thunder
        celestialOpacity = 1 - rain
        let baseSky =
            Self.hsv(
                hue: 0.62222224 - biomeTemperature * 0.05,
                saturation: 0.5 + biomeTemperature * 0.1) * daylight
        var skyColor = Self.weatherColor(
            Self.weatherColor(baseSky, strength: rain * 0.75, gray: 0.6), strength: thunder * 0.75, gray: 0.2)
        if lightningFlash > 0 {
            let strength = min(1, Float(lightningFlash) - partialTick) * 0.45
            skyColor = skyColor * (1 - strength) + SIMD3(0.8, 0.8, 1) * strength
        }
        self.skyColor = skyColor
        let cosine = Self.cosine(phase)
        if cosine >= -0.4 && cosine <= 0.4 {
            let fraction = cosine / 0.4 * 0.5 + 0.5
            var opacity = 1 - (1 - BetaVisualMath.sine(fraction * BetaVisualMath.pi)) * 0.99
            opacity *= opacity
            sunriseColor = SIMD4(fraction * 0.3 + 0.7, fraction * fraction * 0.7 + 0.2, 0.2, opacity)
        } else {
            sunriseColor = nil
        }
        let baseFog =
            SIMD3<Float>(0.7529412, 0.84705883, 1)
            * SIMD3(daylight * 0.94 + 0.06, daylight * 0.94 + 0.06, daylight * 0.91 + 0.09)
        fogColor = baseFog
        let rainyClouds =
            Self.weatherColor(SIMD3(repeating: 1), strength: rain * 0.95, gray: 0.6)
            * SIMD3(daylight * 0.9 + 0.1, daylight * 0.9 + 0.1, daylight * 0.85 + 0.15)
        cloudColor = Self.weatherColor(rainyClouds, strength: thunder * 0.95, gray: 0.2)
        let stars = min(1, max(0, 1 - (Self.cosine(phase) * 2 + 0.75)))
        starBrightness = stars * stars * 0.5 * (1 - rain)
        let rainyLight = Float(Double(daylight) * (1 - Double(rain * 5) / 16))
        let stormLight = Float(Double(rainyLight) * (1 - Double(thunder * 5) / 16))
        skySubtraction = Float(Int((1 - stormLight) * 11))
    }

    func renderFogColor(distanceOption: Int, brightness: Float) -> SIMD3<Float> {
        let weight = 1 - Float(pow(Double(1 / Float(4 - min(3, max(0, distanceOption)))), 0.25))
        var color = fogColor + (skyColor - fogColor) * weight
        color *= SIMD3(1 - rain * 0.5, 1 - rain * 0.5, 1 - rain * 0.4)
        color *= 1 - thunder * 0.5
        return color * brightness
    }

    private static func cosine(_ value: Float) -> Float {
        let index = Int(value * 10430.378 + 16384) & 65535
        return Float(sin(Double(index) * .pi * 2 / 65536))
    }

    private static func weatherColor(_ color: SIMD3<Float>, strength: Float, gray: Float) -> SIMD3<Float> {
        let luminance = (color.x * 0.3 + color.y * 0.59 + color.z * 0.11) * gray
        let retained = 1 - strength
        return color * retained + SIMD3(repeating: luminance * (1 - retained))
    }

    private static func hsv(hue: Float, saturation: Float) -> SIMD3<Float> {
        let hue = (hue - floor(hue)) * 6
        let fraction = hue - floor(hue)
        let p = 1 - saturation
        let q = 1 - saturation * fraction
        let t = 1 - saturation * (1 - fraction)
        let color: SIMD3<Float>
        switch Int(hue) {
        case 0: color = SIMD3(1, t, p)
        case 1: color = SIMD3(q, 1, p)
        case 2: color = SIMD3(p, 1, t)
        case 3: color = SIMD3(p, q, 1)
        case 4: color = SIMD3(t, p, 1)
        default: color = SIMD3(1, p, q)
        }
        return SIMD3(
            Float(Int(color.x * 255 + 0.5)), Float(Int(color.y * 255 + 0.5)),
            Float(Int(color.z * 255 + 0.5))) / 255
    }
}

@MainActor
final class SkyRenderer {
    private let device: MTLDevice
    private let solidPipeline: MTLRenderPipelineState
    private let alphaPipeline: MTLRenderPipelineState
    private let additivePipeline: MTLRenderPipelineState
    private let cloudPipeline: MTLRenderPipelineState
    private let cloudDepthPipeline: MTLRenderPipelineState
    private let skyDepth: MTLDepthStencilState
    private let cloudDepth: MTLDepthStencilState
    private var sun: MTLTexture
    private var moon: MTLTexture
    private var clouds: MTLTexture
    private let upper: Geometry
    private let lower: Geometry
    private let stars: Geometry
    private let sunQuad: Geometry
    private let moonQuad: Geometry
    private let fastClouds: Geometry
    private let fancyClouds: [Geometry]

    private struct Geometry {
        let buffer: MTLBuffer?
        let count: Int
    }

    struct Appearance {
        var tint = SIMD4<Float>(repeating: 1)
        var uvOffset = SIMD2<Float>.zero
        var fogScale = SIMD3<Float>(repeating: 1)
    }

    init(device: MTLDevice, library: MTLLibrary, colorFormat: MTLPixelFormat) throws {
        self.device = device
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "skyGeometryVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "skyGeometryFragment")
        descriptor.colorAttachments[0].pixelFormat = colorFormat
        descriptor.depthAttachmentPixelFormat = .depth32Float
        solidPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let attachment = descriptor.colorAttachments[0]!
        attachment.isBlendingEnabled = true
        attachment.sourceRGBBlendFactor = .sourceAlpha
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        alphaPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        attachment.destinationRGBBlendFactor = .one
        additivePipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.fragmentFunction = library.makeFunction(name: "cloudGeometryFragment")
        cloudPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        attachment.writeMask = []
        cloudDepthPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let depth = MTLDepthStencilDescriptor()
        depth.depthCompareFunction = .always
        depth.isDepthWriteEnabled = false
        guard let skyDepth = device.makeDepthStencilState(descriptor: depth) else {
            throw Renderer.SetupError.unavailable("could not create sky depth state")
        }
        self.skyDepth = skyDepth
        depth.depthCompareFunction = .lessEqual
        depth.isDepthWriteEnabled = true
        guard let cloudDepth = device.makeDepthStencilState(descriptor: depth) else {
            throw Renderer.SetupError.unavailable("could not create cloud depth state")
        }
        self.cloudDepth = cloudDepth
        func geometry(_ vertices: [BlockVertex]) -> Geometry {
            Geometry(buffer: device.makeSharedBuffer(vertices), count: vertices.count)
        }
        upper = geometry(BetaSkyGeometry.plane(height: 16))
        lower = geometry(BetaSkyGeometry.plane(height: -16))
        stars = geometry(
            Self.starVertices().map {
                BlockVertex(
                    position: SIMD3($0.x, $0.y, $0.z), color: SIMD3(repeating: 1), textureWeight: 0,
                    light: 255)
            })
        sunQuad = geometry(BetaSkyGeometry.celestial(moon: false))
        moonQuad = geometry(BetaSkyGeometry.celestial(moon: true))
        fastClouds = geometry(BetaSkyGeometry.fastClouds())
        fancyClouds = (0..<4).map {
            geometry(BetaSkyGeometry.fancyClouds(bottom: $0 & 1 != 0, top: $0 & 2 != 0))
        }
        let loader = MTKTextureLoader(device: device)
        sun = try Self.load("terrain/sun", loader: loader)
        moon = try Self.load("terrain/moon", loader: loader)
        clouds = try Self.load("environment/clouds", loader: loader)
    }

    private static func load(_ path: String, loader: MTKTextureLoader) throws -> MTLTexture {
        guard let url = TextureResources.url(for: path) else {
            throw Renderer.SetupError.unavailable("missing sky texture")
        }
        return try loader.newTexture(
            URL: url, options: [.origin: MTKTextureLoader.Origin.topLeft, .SRGB: false])
    }

    func reload(device: MTLDevice) throws {
        let loader = MTKTextureLoader(device: device)
        let sun = try Self.load("terrain/sun", loader: loader)
        let moon = try Self.load("terrain/moon", loader: loader)
        let clouds = try Self.load("environment/clouds", loader: loader)
        self.sun = sun
        self.moon = moon
        self.clouds = clouds
    }

    func draw(
        encoder: MTLRenderCommandEncoder, center: SIMD3<Float>, matrix: simd_float4x4,
        state: BetaSkyState, fogColor: SIMD3<Float>, fogEnd: Float, visible: Bool
    ) {
        guard visible else { return }
        let centered = matrix * HeldItemGeometry.translation(center)
        var uniforms = Renderer.Uniforms(
            viewProjection: centered, renderOffset: .zero, cameraPosition: .zero,
            fogColor: fogColor, fogStart: 0, fogEnd: fogEnd * 0.8, skySubtraction: 0, fogDensity: 0,
            ambientFloor: 0.05)
        var appearance = Appearance(tint: SIMD4(state.skyColor, 1))
        encoder.setDepthStencilState(skyDepth)
        encoder.setCullMode(.none)
        encoder.setRenderPipelineState(solidPipeline)
        draw(upper, encoder: encoder, uniforms: &uniforms, appearance: &appearance, texture: sun)
        uniforms.fogStart = 10000
        uniforms.fogEnd = 20000
        if let color = state.sunriseColor {
            encoder.setRenderPipelineState(alphaPipeline)
            uniforms.viewProjection =
                centered * HeldItemGeometry.rotation(90, axis: SIMD3(1, 0, 0))
                * HeldItemGeometry.rotation(state.celestialAngle > 0.5 ? 180 : 0, axis: SIMD3(0, 0, 1))
            appearance.tint = color
            let vertices = BetaSkyGeometry.sunrise(opacity: color.w)
            let geometry = Geometry(buffer: device.makeSharedBuffer(vertices), count: vertices.count)
            draw(geometry, encoder: encoder, uniforms: &uniforms, appearance: &appearance, texture: sun)
        }
        encoder.setRenderPipelineState(additivePipeline)
        uniforms.viewProjection =
            centered * HeldItemGeometry.rotation(state.celestialAngle * 360, axis: SIMD3(1, 0, 0))
        appearance.tint = SIMD4(1, 1, 1, state.celestialOpacity)
        draw(sunQuad, encoder: encoder, uniforms: &uniforms, appearance: &appearance, texture: sun)
        draw(moonQuad, encoder: encoder, uniforms: &uniforms, appearance: &appearance, texture: moon)
        if state.starBrightness > 0 {
            appearance.tint = SIMD4(repeating: state.starBrightness)
            draw(stars, encoder: encoder, uniforms: &uniforms, appearance: &appearance, texture: sun)
        }
        encoder.setRenderPipelineState(solidPipeline)
        uniforms.viewProjection = centered
        uniforms.fogStart = 0
        uniforms.fogEnd = fogEnd * 0.8
        appearance.tint = SIMD4(state.skyColor * SIMD3(0.2, 0.2, 0.6) + SIMD3(0.04, 0.04, 0.1), 1)
        draw(lower, encoder: encoder, uniforms: &uniforms, appearance: &appearance, texture: sun)
    }

    func drawClouds(
        encoder: MTLRenderCommandEncoder, center: SIMD3<Float>, position: SIMD3<Double>,
        matrix: simd_float4x4, state: BetaSkyState, ticks: Int, partial: Float,
        worldUniforms: Renderer.Uniforms, fancy: Bool, visible: Bool
    ) {
        guard visible else { return }
        let placement = BetaSkyGeometry.cloudPlacement(
            position: position, ticks: ticks, partial: partial, fancy: fancy)
        var uniforms = worldUniforms
        uniforms.viewProjection =
            matrix * HeldItemGeometry.translation(center)
            * simd_float4x4(diagonal: SIMD4(placement.scale, 1))
        uniforms.renderOffset = placement.offset
        uniforms.cameraPosition = .zero
        var appearance = Appearance(
            tint: SIMD4(state.cloudColor, 0.8), uvOffset: placement.uv, fogScale: placement.scale)
        encoder.setCullMode(.none)
        encoder.setDepthStencilState(cloudDepth)
        let geometry = fancy ? fancyClouds[(placement.bottom ? 1 : 0) | (placement.top ? 2 : 0)] : fastClouds
        if fancy {
            encoder.setRenderPipelineState(cloudDepthPipeline)
            draw(geometry, encoder: encoder, uniforms: &uniforms, appearance: &appearance, texture: clouds)
        }
        encoder.setRenderPipelineState(cloudPipeline)
        draw(geometry, encoder: encoder, uniforms: &uniforms, appearance: &appearance, texture: clouds)
    }

    private func draw(
        _ geometry: Geometry, encoder: MTLRenderCommandEncoder,
        uniforms: inout Renderer.Uniforms, appearance: inout Appearance, texture: MTLTexture
    ) {
        guard let buffer = geometry.buffer else { return }
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Renderer.Uniforms>.stride, index: 1)
        encoder.setVertexBytes(&appearance, length: MemoryLayout<Appearance>.stride, index: 2)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: geometry.count)
    }
    static func starVertices() -> [SIMD4<Float>] {
        var random = JavaRandom(seed: 10842)
        var vertices: [SIMD4<Float>] = []
        for _ in 0..<1500 {
            var x = Double(random.nextFloat() * 2 - 1)
            var y = Double(random.nextFloat() * 2 - 1)
            var z = Double(random.nextFloat() * 2 - 1)
            let size = Double(0.25 + random.nextFloat() * 0.25)
            let squared = x * x + y * y + z * z
            guard squared < 1 && squared > 0.01 else { continue }
            let length = 1 / sqrt(squared)
            x *= length
            y *= length
            z *= length
            let longitude = atan2(x, z)
            let latitude = atan2(sqrt(x * x + z * z), y)
            let roll = random.nextDouble() * .pi * 2
            var points: [SIMD4<Float>] = []
            for corner in 0..<4 {
                let u = Double((corner & 2) - 1) * size
                let v = Double(((corner + 1) & 2) - 1) * size
                let rotatedU = u * cos(roll) - v * sin(roll)
                let rotatedV = v * cos(roll) + u * sin(roll)
                let vertical = rotatedU * sin(latitude)
                let horizontal = -rotatedU * cos(latitude)
                points.append(
                    SIMD4(
                        Float(x * 100 + horizontal * sin(longitude) - rotatedV * cos(longitude)),
                        Float(y * 100 + vertical),
                        Float(z * 100 + rotatedV * sin(longitude) + horizontal * cos(longitude)), 1))
            }
            for index in [0, 1, 2, 0, 2, 3] { vertices.append(points[index]) }
        }
        return vertices
    }
}
