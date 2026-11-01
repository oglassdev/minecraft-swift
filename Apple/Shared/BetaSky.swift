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
    let sunDirection: SIMD3<Float>

    init(time: Int64, temperature: Double, rain: Float = 0, thunder: Float = 0) {
        var angle = Float((time % 24000 + 24000) % 24000) / 24000 - 0.25
        if angle < 0 { angle += 1 }
        let originalAngle = angle
        angle = 1 - Float((cos(Double(angle) * .pi) + 1) / 2)
        celestialAngle = originalAngle + (angle - originalAngle) / 3
        let phase = celestialAngle * .pi * 2
        let daylight = min(1, max(0, Self.cosine(phase) * 2 + 0.5))
        let biomeTemperature = Float(min(1, max(-1, temperature / 3)))
        let rain = min(1, max(0, rain))
        let thunder = min(1, max(0, thunder))
        let baseSky =
            Self.hsv(
                hue: 0.62222224 - biomeTemperature * 0.05,
                saturation: 0.5 + biomeTemperature * 0.1) * daylight
        skyColor = Self.weatherColor(
            Self.weatherColor(baseSky, strength: rain * 0.75, gray: 0.6), strength: thunder * 0.75, gray: 0.2)
        let baseFog =
            SIMD3<Float>(0.7529412, 0.84705883, 1)
            * SIMD3(daylight * 0.94 + 0.06, daylight * 0.94 + 0.06, daylight * 0.91 + 0.09)
        fogColor = baseFog * SIMD3(1 - rain * 0.5, 1 - rain * 0.5, 1 - rain * 0.4) * (1 - thunder * 0.5)
        let rainyClouds =
            Self.weatherColor(SIMD3(repeating: 1), strength: rain * 0.95, gray: 0.6)
            * SIMD3(daylight * 0.9 + 0.1, daylight * 0.9 + 0.1, daylight * 0.85 + 0.15)
        cloudColor = Self.weatherColor(rainyClouds, strength: thunder * 0.95, gray: 0.2)
        let stars = min(1, max(0, 1 - (Self.cosine(phase) * 2 + 0.75)))
        starBrightness = stars * stars * 0.5 * (1 - rain)
        let rainyLight = Float(Double(daylight) * (1 - Double(rain * 5) / 16))
        let stormLight = Float(Double(rainyLight) * (1 - Double(thunder * 5) / 16))
        skySubtraction = Float(Int((1 - stormLight) * 11))
        sunDirection = SIMD3(-sin(phase), cos(phase), 0)
    }

    private static func cosine(_ value: Float) -> Float {
        let index = Int(value * 10430.378 + 16384) & 65535
        return Float(sin(Double(index) * .pi * 2 / 65536))
    }

    private static func weatherColor(_ color: SIMD3<Float>, strength: Float, gray: Float) -> SIMD3<Float> {
        let luminance = (color.x * 0.3 + color.y * 0.59 + color.z * 0.11) * gray
        return color * (1 - strength) + SIMD3(repeating: luminance * strength)
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
    private let skyPipeline: MTLRenderPipelineState
    private let starPipeline: MTLRenderPipelineState
    private let cloudPipeline: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private let sun: MTLTexture
    private let moon: MTLTexture
    private let clouds: MTLTexture
    private let stars: MTLBuffer?
    private let starVertexCount: Int

    struct Uniforms {
        var viewProjection: simd_float4x4
        var right: SIMD3<Float>
        var up: SIMD3<Float>
        var forward: SIMD3<Float>
        var sunDirection: SIMD3<Float>
        var skyColor: SIMD3<Float>
        var fogColor: SIMD3<Float>
        var cloudColor: SIMD3<Float>
        var cameraPosition: SIMD3<Float>
        var parameters: SIMD4<Float>
    }

    init(device: MTLDevice, library: MTLLibrary, colorFormat: MTLPixelFormat) throws {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = colorFormat
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.vertexFunction = library.makeFunction(name: "skyVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "skyFragment")
        skyPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.fragmentFunction = library.makeFunction(name: "cloudFragment")
        cloudPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        descriptor.vertexFunction = library.makeFunction(name: "starVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "starFragment")
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        starPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let depth = MTLDepthStencilDescriptor()
        depth.depthCompareFunction = .always
        depth.isDepthWriteEnabled = false
        guard let state = device.makeDepthStencilState(descriptor: depth) else {
            throw Renderer.SetupError.unavailable("could not create sky depth state")
        }
        depthState = state
        let loader = MTKTextureLoader(device: device)
        func load(_ path: String) throws -> MTLTexture {
            guard let root = Bundle.main.resourceURL else {
                throw Renderer.SetupError.unavailable("missing resources")
            }
            return try loader.newTexture(
                URL: root.appendingPathComponent("Vanilla/\(path).png"),
                options: [
                    .origin: MTKTextureLoader.Origin.topLeft, .SRGB: false,
                ])
        }
        sun = try load("terrain/sun")
        moon = try load("terrain/moon")
        clouds = try load("environment/clouds")
        let vertices = Self.starVertices()
        starVertexCount = vertices.count
        stars = vertices.withUnsafeBytes { bytes in
            guard let address = bytes.baseAddress else { return nil }
            return device.makeBuffer(bytes: address, length: bytes.count, options: .storageModeShared)
        }
    }

    func draw(
        encoder: MTLRenderCommandEncoder, camera: Camera, aspect: Float,
        matrix: simd_float4x4, state: BetaSkyState, time: Int64, fogColor: SIMD3<Float>,
        origin: SIMD3<Double> = .zero, visible: Bool
    ) {
        let right = simd_normalize(simd_cross(camera.forward, SIMD3(0, 1, 0)))
        let up = simd_cross(right, camera.forward)
        var translation = matrix_identity_float4x4
        translation.columns.3 = SIMD4(camera.position, 1)
        let phase = state.celestialAngle * .pi * 2
        let rotation = simd_float4x4(
            columns: (
                SIMD4<Float>(0, 0, 1, 0), SIMD4(-sin(phase), cos(phase), 0, 0),
                SIMD4(-cos(phase), -sin(phase), 0, 0), SIMD4(0, 0, 0, 1)
            ))
        var uniforms = Uniforms(
            viewProjection: matrix * translation * rotation, right: right, up: up,
            forward: camera.forward, sunDirection: state.sunDirection, skyColor: state.skyColor,
            fogColor: fogColor, cloudColor: state.cloudColor,
            cameraPosition: SIMD3(
                Float((origin.x + Double(camera.position.x)).truncatingRemainder(dividingBy: 2048)),
                camera.position.y,
                Float((origin.z + Double(camera.position.z)).truncatingRemainder(dividingBy: 2048))),
            parameters: SIMD4(
                aspect, tan(70 * .pi / 360),
                Float((Double(time) * 0.03).truncatingRemainder(dividingBy: 2048)),
                visible ? state.starBrightness : -1))
        encoder.setDepthStencilState(depthState)
        encoder.setCullMode(.none)
        encoder.setRenderPipelineState(skyPipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentTexture(sun, index: 0)
        encoder.setFragmentTexture(moon, index: 1)
        encoder.setFragmentTexture(clouds, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        if let stars, state.starBrightness > 0, visible {
            encoder.setRenderPipelineState(starPipeline)
            encoder.setVertexBuffer(stars, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: starVertexCount)
        }
        encoder.setRenderPipelineState(cloudPipeline)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
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
