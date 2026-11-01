import MetalKit
import MinecraftCore
import simd

@MainActor
final class Renderer: NSObject, MTKViewDelegate {
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private let vertexBuffer: MTLBuffer
    private let vertexCount: Int
    private let session: GameSession
    private var previousTime: CFTimeInterval?

    struct Uniforms {
        var viewProjection: simd_float4x4
        var cameraPosition: SIMD3<Float>
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
        guard let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue()
        else {
            throw SetupError.unavailable("no compatible GPU or command queue")
        }
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor = MTLClearColor(red: 0.57, green: 0.75, blue: 0.90, alpha: 1)
        view.preferredFramesPerSecond = 60

        let library = try device.makeDefaultLibrary(bundle: .main)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "blockVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "blockFragment")
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        self.pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            throw SetupError.unavailable("could not create depth state")
        }
        let mesh = BlockMesh(world: .demo())
        let buffer = mesh.vertices.withUnsafeBytes { bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
        }
        guard let buffer else { throw SetupError.unavailable("could not upload the block mesh") }
        self.vertexBuffer = buffer
        self.vertexCount = mesh.vertices.count
        self.depthState = depthState
        self.queue = queue
        self.session = session
        super.init()
        view.delegate = self
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        let now = CACurrentMediaTime()
        let delta = Float(min(now - (previousTime ?? now), 0.05))
        previousTime = now
        session.update(deltaTime: delta)
        guard view.drawableSize.width > 0, view.drawableSize.height > 0,
            let pass = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let commandBuffer = queue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)
        else { return }

        let camera = session.camera
        let aspect = Float(view.drawableSize.width / view.drawableSize.height)
        var uniforms = Uniforms(
            viewProjection: Self.perspective(aspect: aspect) * Self.viewMatrix(camera: camera),
            cameraPosition: camera.position
        )
        encoder.setRenderPipelineState(pipeline)
        encoder.setDepthStencilState(depthState)
        encoder.setCullMode(.back)
        encoder.setFrontFacing(.counterClockwise)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { [weak session] buffer in
            if let error = buffer.error {
                let message = error.localizedDescription
                Task { @MainActor in session?.errorMessage = message }
            }
        }
        commandBuffer.commit()
    }

    private static func perspective(aspect: Float) -> simd_float4x4 {
        let near: Float = 0.1
        let far: Float = 150
        let y: Float = 1 / tan(70 * .pi / 360)
        let z = far / (near - far)
        return simd_float4x4(
            columns: (
                SIMD4(y / aspect, 0, 0, 0), SIMD4(0, y, 0, 0),
                SIMD4(0, 0, z, -1), SIMD4(0, 0, z * near, 0)
            ))
    }

    private static func viewMatrix(camera: Camera) -> simd_float4x4 {
        let forward = camera.forward
        let right = simd_normalize(simd_cross(forward, SIMD3(0, 1, 0)))
        let up = simd_cross(right, forward)
        let position = camera.position
        return simd_float4x4(
            columns: (
                SIMD4(right.x, up.x, -forward.x, 0),
                SIMD4(right.y, up.y, -forward.y, 0),
                SIMD4(right.z, up.z, -forward.z, 0),
                SIMD4(-simd_dot(right, position), -simd_dot(up, position), simd_dot(forward, position), 1)
            ))
    }
}
