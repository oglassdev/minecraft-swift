import MetalKit
import SwiftUI

struct MetalSurface: UIViewRepresentable {
    let session: GameSession

    final class Coordinator {
        var renderer: Renderer?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero)
        do { context.coordinator.renderer = try Renderer(view: view, session: session) } catch {
            session.errorMessage = error.localizedDescription
        }
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}

    static func dismantleUIView(_ uiView: MTKView, coordinator: Coordinator) {
        uiView.isPaused = true
    }
}

struct TouchControls: View {
    let session: GameSession
    @State private var previousLook = CGSize.zero
    @State private var moveOffset = CGSize.zero

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle())
                    .overlay(alignment: .bottomLeading) {
                        Circle().fill(.white.opacity(0.1)).frame(width: 100, height: 100)
                            .overlay {
                                Circle().fill(.white.opacity(0.35)).frame(width: 36, height: 36)
                                    .offset(moveOffset)
                            }
                            .padding(36)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = Float(value.translation.width / 60)
                                let y = Float(-value.translation.height / 60)
                                let length = max(1, sqrt(x * x + y * y))
                                session.touchMovement = SIMD2(x, y) / length
                                moveOffset = CGSize(
                                    width: CGFloat(x / length) * 32, height: CGFloat(-y / length) * 32)
                            }
                            .onEnded { _ in
                                session.touchMovement = .zero
                                moveOffset = .zero
                            })
                Color.clear.contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let dx = value.translation.width - previousLook.width
                                let dy = value.translation.height - previousLook.height
                                session.camera.look(
                                    horizontal: Float(dx) * 0.004, vertical: -Float(dy) * 0.004)
                                previousLook = value.translation
                            }
                            .onEnded { _ in previousLook = .zero })
            }
            .overlay(alignment: .bottomTrailing) {
                VStack(spacing: 18) {
                    altitudeButton("▲", action: .up)
                    altitudeButton("▼", action: .down)
                }
                .padding(.trailing, 30)
                .padding(.bottom, 45)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func altitudeButton(_ title: String, action: GameSession.Action) -> some View {
        Text(title).font(.title2).foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(.black.opacity(0.3), in: Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in session.pressed.insert(action) }
                    .onEnded { _ in session.pressed.remove(action) }
            )
            .accessibilityLabel(action == .up ? "Fly up" : "Fly down")
    }
}
