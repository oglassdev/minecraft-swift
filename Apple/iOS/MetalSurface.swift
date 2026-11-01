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
    @ObservedObject var session: GameSession
    @State private var previousLook = CGSize.zero
    @State private var moveOffset = CGSize.zero

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.contentShape(Rectangle())
                .overlay(alignment: .bottomLeading) { joystick.padding(.leading, 32).padding(.bottom, 68) }
                .gesture(moveGesture)
            Color.clear.contentShape(Rectangle())
                .gesture(lookGesture)
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    holdButton("Mine", systemImage: "hammer.fill") { session.primaryAction(isPressed: $0) }
                    Button {
                        session.secondaryAction()
                    } label: {
                        controlLabel("Place", systemImage: "square.stack.3d.up.fill")
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 12) {
                    holdButton("Jump", systemImage: "arrow.up") { active in
                        set(.jump, active: active)
                        set(.up, active: active)
                    }
                    holdButton("Sneak", systemImage: "arrow.down") { active in
                        set(.sneak, active: active)
                        set(.down, active: active)
                    }
                }
            }
            .padding(.trailing, 28)
            .padding(.bottom, 68)
        }
        .allowsHitTesting(
            !session.inventoryOpen && !session.isPaused && !session.isLoading && !session.worldMenuOpen
                && !session.chatOpen
                && !session.signEditorOpen
        )
        .onChange(of: session.inventoryOpen) { _, open in if open { releaseControls() } }
        .onChange(of: session.isPaused) { _, paused in if paused { releaseControls() } }
        .onChange(of: session.chatOpen) { _, open in if open { releaseControls() } }
        .onChange(of: session.signEditorOpen) { _, open in if open { releaseControls() } }
        .onDisappear { releaseControls() }
    }

    private var joystick: some View {
        Circle().fill(.black.opacity(0.25)).frame(width: 108, height: 108)
            .overlay {
                Circle().fill(.white.opacity(0.4)).frame(width: 36, height: 36).offset(moveOffset)
            }
            .overlay { Circle().stroke(.white.opacity(0.3), lineWidth: 2) }
            .allowsHitTesting(false)
            .accessibilityLabel("Movement stick. Drag the left half of the screen to move.")
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let x = Float(value.translation.width / 60)
                let y = Float(-value.translation.height / 60)
                let length = max(1, sqrt(x * x + y * y))
                session.touchMovement = SIMD2(x, y) / length
                moveOffset = CGSize(width: CGFloat(x / length) * 32, height: CGFloat(-y / length) * 32)
            }
            .onEnded { _ in
                session.touchMovement = .zero
                moveOffset = .zero
            }
    }

    private var lookGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.translation.width - previousLook.width
                let dy = value.translation.height - previousLook.height
                session.camera.look(
                    horizontal: Float(dx) * session.options.mouseRadiansPerPixel * 1.5,
                    vertical: -Float(dy) * (session.options.invertY ? -1 : 1)
                        * session.options.mouseRadiansPerPixel * 1.5)
                previousLook = value.translation
            }
            .onEnded { _ in previousLook = .zero }
    }

    private func holdButton(
        _ title: String,
        systemImage: String,
        changed: @escaping (Bool) -> Void
    ) -> some View {
        controlLabel(title, systemImage: systemImage)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in changed(true) }
                    .onEnded { _ in changed(false) }
            )
            .accessibilityLabel(title)
    }

    private func controlLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: systemImage).font(.system(size: 18, weight: .semibold))
            Text(title).font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(width: 56, height: 52)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.25), lineWidth: 1) }
    }

    private func set(_ action: GameSession.Action, active: Bool) {
        if active { session.pressed.insert(action) } else { session.pressed.remove(action) }
    }

    private func releaseControls() {
        session.primaryAction(isPressed: false)
        session.resetInput()
        previousLook = .zero
        moveOffset = .zero
    }
}
