import Combine
import Foundation
import MinecraftCore

@MainActor
final class GameSession: ObservableObject {
    enum Action { case forward, backward, left, right, up, down, fast }

    @Published var isMouseCaptured = false
    @Published var errorMessage: String?
    @Published private(set) var positionText = ""
    var camera = Camera()
    var pressed: Set<Action> = []
    var touchMovement = SIMD2<Float>.zero
    private var statusElapsed: Float = 0

    func update(deltaTime: Float) {
        func axis(_ positive: Action, _ negative: Action) -> Float {
            (pressed.contains(positive) ? 1 : 0) - (pressed.contains(negative) ? 1 : 0)
        }
        camera.move(
            MovementInput(
                forward: axis(.forward, .backward) + touchMovement.y,
                right: axis(.right, .left) + touchMovement.x,
                up: axis(.up, .down),
                fast: pressed.contains(.fast)
            ), deltaTime: deltaTime)
        statusElapsed += deltaTime
        if statusElapsed >= 0.15 {
            let p = camera.position
            positionText = String(format: "XYZ  %.1f  %.1f  %.1f", p.x, p.y, p.z)
            statusElapsed = 0
        }
    }

    func resetInput() {
        pressed.removeAll()
        touchMovement = .zero
    }
}
