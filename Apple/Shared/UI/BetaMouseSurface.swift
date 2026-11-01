import SwiftUI

#if os(macOS)
    import AppKit

    struct BetaMouseSurface: NSViewRepresentable {
        var moved: (CGPoint?) -> Void
        var clicked: (CGPoint, Bool, Bool) -> Void

        func makeNSView(context: Context) -> MouseView {
            let view = MouseView()
            view.moved = moved
            view.clicked = clicked
            return view
        }
        func updateNSView(_ view: MouseView, context: Context) {
            view.moved = moved
            view.clicked = clicked
        }

        final class MouseView: NSView {
            var moved: ((CGPoint?) -> Void)?
            var clicked: ((CGPoint, Bool, Bool) -> Void)?
            private var tracking: NSTrackingArea?
            override var isFlipped: Bool { true }
            override var acceptsFirstResponder: Bool { false }
            override func updateTrackingAreas() {
                if let tracking { removeTrackingArea(tracking) }
                tracking = NSTrackingArea(
                    rect: .zero,
                    options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                    owner: self)
                if let tracking { addTrackingArea(tracking) }
                super.updateTrackingAreas()
            }
            override func mouseMoved(with event: NSEvent) {
                moved?(convert(event.locationInWindow, from: nil))
            }
            override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }
            override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }
            override func rightMouseDragged(with event: NSEvent) { mouseMoved(with: event) }
            override func mouseExited(with event: NSEvent) { moved?(nil) }
            override func mouseDown(with event: NSEvent) { click(event, secondary: false) }
            override func rightMouseDown(with event: NSEvent) { click(event, secondary: true) }
            private func click(_ event: NSEvent, secondary: Bool) {
                let point = convert(event.locationInWindow, from: nil)
                moved?(point)
                clicked?(point, secondary, event.modifierFlags.contains(.shift))
            }
        }
    }
#else
    struct BetaMouseSurface: View {
        var moved: (CGPoint?) -> Void
        var clicked: (CGPoint, Bool, Bool) -> Void
        @State private var point = CGPoint.zero
        @State private var secondary = false
        var body: some View {
            Color.clear.contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        point = value.location
                        moved(point)
                    }.onEnded { value in
                        if !secondary { clicked(value.location, false, false) }
                        secondary = false
                    }
                )
                .simultaneousGesture(
                    LongPressGesture().onEnded { _ in
                        secondary = true
                        clicked(point, true, false)
                    })
        }
    }
#endif
