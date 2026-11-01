import AppKit
import MetalKit
import SwiftUI

struct MetalSurface: NSViewRepresentable {
    let session: GameSession

    func makeNSView(context: Context) -> MacMetalView {
        let view = MacMetalView(frame: .zero)
        view.session = session
        do { view.renderer = try Renderer(view: view, session: session) } catch {
            session.errorMessage = error.localizedDescription
        }
        return view
    }

    func updateNSView(_ nsView: MacMetalView, context: Context) {}

    static func dismantleNSView(_ nsView: MacMetalView, coordinator: ()) {
        nsView.releaseMouse()
        nsView.isPaused = true
    }
}

final class MacMetalView: MTKView {
    var session: GameSession?
    var renderer: Renderer?
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        if let window {
            window.acceptsMouseMovedEvents = true
            NotificationCenter.default.addObserver(
                self, selector: #selector(releaseMouse),
                name: NSWindow.didResignKeyNotification, object: window
            )
        } else {
            releaseMouse()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let session, !session.isMouseCaptured else { return }
        window?.makeFirstResponder(self)
        guard CGAssociateMouseAndMouseCursorPosition(0) == .success else { return }
        NSCursor.hide()
        session.isMouseCaptured = true
    }

    @objc func releaseMouse() {
        if session?.isMouseCaptured == true {
            CGAssociateMouseAndMouseCursorPosition(1)
            NSCursor.unhide()
            session?.isMouseCaptured = false
        }
        session?.resetInput()
    }

    override func mouseMoved(with event: NSEvent) {
        guard session?.isMouseCaptured == true else { return }
        session?.camera.look(
            horizontal: Float(event.deltaX) * 0.0025, vertical: -Float(event.deltaY) * 0.0025)
    }

    override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            releaseMouse()
        } else if session?.isMouseCaptured == true, let action = Self.action(for: event.keyCode) {
            session?.pressed.insert(action)
        } else {
            super.keyDown(with: event)
        }
    }

    override func keyUp(with event: NSEvent) {
        if let action = Self.action(for: event.keyCode) { session?.pressed.remove(action) }
    }

    override func flagsChanged(with event: NSEvent) {
        guard session?.isMouseCaptured == true else { return }
        if event.modifierFlags.contains(.shift) {
            session?.pressed.insert(.fast)
        } else {
            session?.pressed.remove(.fast)
        }
        if event.modifierFlags.contains(.control) {
            session?.pressed.insert(.down)
        } else {
            session?.pressed.remove(.down)
        }
    }

    private static func action(for keyCode: UInt16) -> GameSession.Action? {
        switch keyCode {
        case 13: .forward
        case 1: .backward
        case 0: .left
        case 2: .right
        case 49: .up
        default: nil
        }
    }
}
