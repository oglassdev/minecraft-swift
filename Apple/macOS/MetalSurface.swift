import AppKit
import Combine
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
        nsView.disconnect()
        nsView.isPaused = true
    }
}

final class MacMetalView: MTKView {
    var session: GameSession? {
        didSet {
            subscriptions.removeAll()
            guard let session else { return }
            session.$inventoryOpen.combineLatest(
                session.$isPaused, session.$chatOpen, session.$signEditorOpen
            )
            .sink { [weak self] inventoryOpen, paused, chat, sign in
                if inventoryOpen || paused || chat || sign { self?.releaseMouse() }
            }
            .store(in: &subscriptions)
        }
    }
    var renderer: Renderer?
    private var subscriptions = Set<AnyCancellable>()
    private var ownsMouseCapture = false
    private var scrollRemainder: CGFloat = 0

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        guard let window else {
            releaseMouse()
            return
        }
        window.acceptsMouseMovedEvents = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowLostFocus),
            name: NSWindow.didResignKeyNotification, object: window
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification, object: nil
        )
    }

    func disconnect() {
        releaseMouse()
        subscriptions.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    private var acceptsGameplayInput: Bool {
        guard let session else { return false }
        return ownsMouseCapture && !session.inventoryOpen && !session.isPaused && !session.isLoading
            && !session.worldMenuOpen
            && !session.chatOpen && !session.signEditorOpen
    }

    override func mouseDown(with event: NSEvent) {
        guard let session, !session.inventoryOpen, !session.isPaused,
            !session.isLoading && !session.worldMenuOpen && !session.chatOpen && !session.signEditorOpen
        else { return }
        if ownsMouseCapture { session.primaryAction(isPressed: true) } else { captureMouse() }
    }

    override func mouseUp(with event: NSEvent) {
        session?.primaryAction(isPressed: false)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let session, !session.inventoryOpen, !session.isPaused,
            !session.isLoading && !session.worldMenuOpen && !session.chatOpen && !session.signEditorOpen
        else { return }
        if ownsMouseCapture { session.secondaryAction() } else { captureMouse() }
    }

    private func captureMouse() {
        guard !ownsMouseCapture, let session else { return }
        window?.makeFirstResponder(self)
        guard CGAssociateMouseAndMouseCursorPosition(0) == .success else { return }
        ownsMouseCapture = true
        NSCursor.hide()
        session.isMouseCaptured = true
    }

    @objc func releaseMouse() {
        if ownsMouseCapture {
            CGAssociateMouseAndMouseCursorPosition(1)
            NSCursor.unhide()
            ownsMouseCapture = false
        }
        session?.isMouseCaptured = false
        session?.primaryAction(isPressed: false)
        session?.resetInput()
        scrollRemainder = 0
    }

    @objc private func windowLostFocus() {
        releaseMouse()
        guard let session else { return }
        if !session.isPaused && !session.inventoryOpen { session.togglePause() }
    }

    @objc private func applicationWillTerminate() {
        releaseMouse()
    }

    override func mouseMoved(with event: NSEvent) {
        guard acceptsGameplayInput else { return }
        session?.camera.look(
            horizontal: Float(event.deltaX) * (session?.options.mouseRadiansPerPixel ?? 0.0025),
            vertical: -Float(event.deltaY) * (session?.options.invertY == true ? -1 : 1)
                * (session?.options.mouseRadiansPerPixel ?? 0.0025)
        )
    }

    override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }
    override func rightMouseDragged(with event: NSEvent) { mouseMoved(with: event) }

    override func keyDown(with event: NSEvent) {
        guard let session else { return }
        if event.modifierFlags.contains(.command) {
            super.keyDown(with: event)
            return
        }
        guard !session.worldMenuOpen else {
            super.keyDown(with: event)
            return
        }
        switch event.keyCode {
        case 53 where !event.isARepeat:
            releaseMouse()
            session.dismissOverlay()
        case 17 where !event.isARepeat && !session.isPaused && !session.inventoryOpen && !session.isLoading,
            36 where !event.isARepeat && !session.isPaused && !session.inventoryOpen && !session.isLoading:
            releaseMouse()
            session.beginChat()
        case 14
        where !event.isARepeat && !session.isPaused && !session.isLoading && !session.worldMenuOpen
            && !session.chatOpen
            && !session.signEditorOpen:
            releaseMouse()
            session.toggleInventory()
        default:
            guard acceptsGameplayInput else {
                super.keyDown(with: event)
                return
            }
            if let slot = Self.hotbarSlot(for: event.keyCode) {
                session.selectHotbar(slot)
            } else if event.keyCode == 12 && !event.isARepeat {
                session.dropSelectedItem()
            } else if event.keyCode == 3 && !event.isARepeat {
                session.toggleFlight()
            } else if let action = Self.action(for: event.keyCode) {
                session.pressed.insert(action)
                if action == .jump { session.pressed.insert(.up) }
            } else {
                super.keyDown(with: event)
            }
        }
    }

    override func keyUp(with event: NSEvent) {
        guard let action = Self.action(for: event.keyCode) else { return }
        session?.pressed.remove(action)
        if action == .jump { session?.pressed.remove(.up) }
    }

    override func flagsChanged(with event: NSEvent) {
        guard acceptsGameplayInput, let session else { return }
        let sneaking = event.modifierFlags.contains(.shift)
        if sneaking { session.pressed.insert(.sneak) } else { session.pressed.remove(.sneak) }
        if sneaking || event.modifierFlags.contains(.control) {
            session.pressed.insert(.down)
        } else {
            session.pressed.remove(.down)
        }
        if event.modifierFlags.contains(.option) {
            session.pressed.insert(.fast)
        } else {
            session.pressed.remove(.fast)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard acceptsGameplayInput else { return }
        scrollRemainder += event.scrollingDeltaY
        let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 8 : 1
        let steps = min(9, Int(abs(scrollRemainder) / threshold))
        guard steps > 0 else { return }
        let direction = scrollRemainder > 0 ? 1 : -1
        session?.cycleHotbar(direction * steps)
        scrollRemainder -= CGFloat(direction * steps) * threshold
    }

    private static func action(for keyCode: UInt16) -> GameSession.Action? {
        switch keyCode {
        case 13: .forward
        case 1: .backward
        case 0: .left
        case 2: .right
        case 49: .jump
        default: nil
        }
    }

    private static func hotbarSlot(for keyCode: UInt16) -> Int? {
        switch keyCode {
        case 18: 0
        case 19: 1
        case 20: 2
        case 21: 3
        case 23: 4
        case 22: 5
        case 26: 6
        case 28: 7
        case 25: 8
        default: nil
        }
    }
}
