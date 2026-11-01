import AppKit
import Combine
import MetalKit
import MinecraftCore
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
            Publishers.MergeMany(
                session.$inventoryOpen, session.$isPaused, session.$chatOpen, session.$signEditorOpen,
                session.$worldMenuOpen, session.$showDeathScreen
            )
            .filter { $0 }
            .sink { [weak self] _ in self?.releaseMouse() }
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
        return ownsMouseCapture && !session.isInputBlocked
    }

    override func mouseDown(with event: NSEvent) { pressMouse { $0.primaryAction(isPressed: true) } }

    override func mouseUp(with event: NSEvent) {
        session?.primaryAction(isPressed: false)
    }

    override func rightMouseDown(with event: NSEvent) { pressMouse { $0.secondaryAction(isPressed: true) } }

    override func rightMouseUp(with event: NSEvent) { session?.secondaryAction(isPressed: false) }

    /// The first click captures the mouse; later clicks act on the game.
    private func pressMouse(_ action: (GameSession) -> Void) {
        guard let session, !session.isInputBlocked else { return }
        if ownsMouseCapture { action(session) } else { captureMouse() }
    }

    private func captureMouse() {
        guard !ownsMouseCapture else { return }
        window?.makeFirstResponder(self)
        guard CGAssociateMouseAndMouseCursorPosition(0) == .success else { return }
        ownsMouseCapture = true
        NSCursor.hide()
    }

    @objc func releaseMouse() {
        if ownsMouseCapture {
            CGAssociateMouseAndMouseCursorPosition(1)
            NSCursor.unhide()
            ownsMouseCapture = false
        }
        session?.primaryAction(isPressed: false)
        session?.resetInput()
        scrollRemainder = 0
    }

    @objc private func windowLostFocus() {
        releaseMouse()
        session?.releaseInputAndPause()
    }

    @objc private func applicationWillTerminate() {
        releaseMouse()
    }

    override func mouseMoved(with event: NSEvent) {
        guard acceptsGameplayInput else { return }
        session?.lookMouse(horizontal: Float(event.deltaX), vertical: Float(event.deltaY))
    }

    override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }
    override func rightMouseDragged(with event: NSEvent) { mouseMoved(with: event) }

    override func keyDown(with event: NSEvent) {
        guard let session else { return }
        if event.modifierFlags.contains(.command) {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == 103 && !event.isARepeat {
            window?.toggleFullScreen(nil)
            return
        }
        if event.keyCode == 120 && !event.isARepeat {
            session.captureScreenshot()
            return
        }
        guard !session.worldMenuOpen, !session.showDeathScreen else {
            super.keyDown(with: event)
            return
        }
        let keys = mappedKeys(for: event.keyCode)
        if event.keyCode == 53 && !event.isARepeat {
            releaseMouse()
            session.dismissOverlay()
        } else if keys.contains(.inventory) && !event.isARepeat && !session.isPaused && !session.isLoading
            && !session.chatOpen && !session.signEditorOpen
        {
            releaseMouse()
            session.toggleInventory()
        } else if keys.contains(.chat) && !event.isARepeat && acceptsGameplayInput {
            releaseMouse()
            session.beginChat()
        } else {
            guard acceptsGameplayInput else {
                super.keyDown(with: event)
                return
            }
            if event.keyCode == 122 && !event.isARepeat {
                session.hideHUD.toggle()
            } else if event.keyCode == 99 && !event.isARepeat {
                session.showDebug.toggle()
            } else if event.keyCode == 96 && !event.isARepeat {
                session.togglePerspective()
            } else if event.keyCode == 100 && !event.isARepeat {
                session.toggleSmoothCamera()
            } else if event.keyCode == 3 && event.modifierFlags.contains(.control) && !event.isARepeat {
                session.toggleFlight()
            } else {
                if let slot = Self.hotbarSlot(for: event.keyCode) { session.selectHotbar(slot) }
                if keys.contains(.drop) && !event.isARepeat { session.dropSelectedItem() }
                if keys.contains(.fog) && !event.isARepeat {
                    let direction = event.modifierFlags.contains(.shift) ? -1 : 1
                    session.options.renderDistance = (session.options.renderDistance + direction + 4) % 4
                    session.saveOptions()
                }
                for action in actions(for: event.keyCode) {
                    session.pressed.insert(action)
                    if action == .jump { session.pressed.insert(.up) }
                }
            }
        }
    }

    override func keyUp(with event: NSEvent) {
        for action in actions(for: event.keyCode) {
            session?.pressed.remove(action)
            if action == .jump { session?.pressed.remove(.up) }
        }
    }

    override func flagsChanged(with event: NSEvent) {
        guard acceptsGameplayInput, let session else { return }
        let binding = session.options.keyBindings[.sneak] ?? GameKey.sneak.defaultCode
        let sneaking: Bool
        switch binding {
        case 42, 54: sneaking = event.modifierFlags.contains(.shift)
        case 29, 157: sneaking = event.modifierFlags.contains(.control)
        case 56, 184: sneaking = event.modifierFlags.contains(.option)
        default: return
        }
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

    private func mappedKeys(for code: UInt16) -> [GameKey] {
        guard let session, let lwjgl = Self.lwjglCodes[code] else { return [] }
        return GameKey.allCases.filter { session.options.keyBindings[$0] == lwjgl }
    }

    private func actions(for code: UInt16) -> [GameSession.Action] {
        mappedKeys(for: code).compactMap { key in
            switch key {
            case .forward: .forward
            case .back: .backward
            case .left: .left
            case .right: .right
            case .jump: .jump
            case .sneak: .sneak
            default: nil
            }
        }
    }

    static let lwjglCodes: [UInt16: Int] = [
        0: 30, 1: 31, 2: 32, 3: 33, 4: 35, 5: 34, 6: 44, 7: 45, 8: 46, 9: 47, 11: 48,
        12: 16, 13: 17, 14: 18, 15: 19, 16: 21, 17: 20, 18: 2, 19: 3, 20: 4, 21: 5, 22: 7, 23: 6,
        24: 13, 25: 10, 26: 8, 27: 12, 28: 9, 29: 11, 30: 27, 31: 24, 32: 22, 33: 26, 34: 23, 35: 25,
        36: 28, 37: 38, 38: 36, 39: 40, 40: 37, 41: 39, 42: 43, 43: 51, 44: 53, 45: 49, 46: 50, 47: 52,
        48: 15, 49: 57, 50: 41, 51: 14, 53: 1, 56: 42, 60: 54, 58: 56, 61: 184, 59: 29, 62: 157,
        123: 203, 124: 205, 125: 208, 126: 200, 122: 59, 120: 60, 99: 61, 118: 62, 96: 63, 97: 64, 100: 66,
    ]

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
