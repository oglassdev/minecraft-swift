import SwiftUI

struct BetaTextField: View {
    @Binding var text: String
    @Binding var focused: Bool
    var width = 200
    var maximumLength = 32
    @State private var focusStarted = Date()
    var submitted: () -> Void = {}
    var tabbed: () -> Void = {}

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { time in
            let blink = focused && Int(max(0, time.date.timeIntervalSince(focusStarted)) * 20) / 6 % 2 == 0
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(white: 160.0 / 255)).frame(width: CGFloat(width + 2), height: 22)
                    .offset(x: -1, y: -1)
                Rectangle().fill(.black).frame(width: CGFloat(width), height: 20)
                BetaText(
                    text.replacingOccurrences(of: "\n", with: "") + (blink ? "_" : ""), color: 0xE0E0E0,
                    shadow: false
                ).offset(x: 4, y: 6)
                #if os(macOS)
                    BetaFieldInput(
                        text: $text, focused: $focused, maximumLength: maximumLength, submitted: submitted,
                        tabbed: tabbed)
                #else
                    TextField("", text: $text).textFieldStyle(.plain).foregroundStyle(.clear).tint(.clear)
                        .autocorrectionDisabled().textInputAutocapitalization(.never).onSubmit(submitted)
                #endif
            }.frame(width: CGFloat(width), height: 20, alignment: .topLeading)
        }.onChange(of: focused) { _, value in if value { focusStarted = Date() } }
    }
}

#if os(macOS)
    import AppKit
    struct BetaFieldInput: NSViewRepresentable {
        @Binding var text: String
        @Binding var focused: Bool
        var maximumLength: Int
        var allowPaste = true
        var escaped: () -> Void = {}
        var submitted: () -> Void
        var tabbed: () -> Void
        func makeNSView(context: Context) -> FieldView {
            let view = FieldView()
            update(view)
            return view
        }
        func updateNSView(_ view: FieldView, context: Context) {
            update(view)
            view.requestFocus()
        }
        private func update(_ view: FieldView) {
            view.allowPaste = allowPaste
            view.escaped = escaped
            view.text = text
            view.focused = focused
            view.maximumLength = maximumLength
            view.changed = { text = $0 }
            view.focusChanged = { focused = $0 }
            view.submitted = submitted
            view.tabbed = tabbed
        }
        final class FieldView: NSView {
            var text = "", focused = false, maximumLength = 32
            var allowPaste = true
            var escaped: (() -> Void)?
            var changed: ((String) -> Void)?, focusChanged: ((Bool) -> Void)?, submitted: (() -> Void)?,
                tabbed: (() -> Void)?
            override var acceptsFirstResponder: Bool { true }
            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                requestFocus()
            }
            func requestFocus() {
                guard focused, let window, window.firstResponder !== self else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.focused else { return }
                    self.window?.makeFirstResponder(self)
                }
            }
            override func becomeFirstResponder() -> Bool {
                focused = true
                focusChanged?(true)
                return true
            }
            override func resignFirstResponder() -> Bool {
                focused = false
                focusChanged?(false)
                return true
            }
            override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
            override func keyDown(with event: NSEvent) {
                if event.keyCode == 53 {
                    escaped?()
                    return
                }
                if event.keyCode == 36 {
                    submitted?()
                    return
                }
                if event.keyCode == 48 {
                    tabbed?()
                    return
                }
                if event.keyCode == 51 {
                    if !text.isEmpty {
                        text.removeLast()
                        changed?(text)
                    }
                    return
                }
                if (event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control))
                    && event.keyCode == 9
                {
                    if allowPaste, let paste = NSPasteboard.general.string(forType: .string) {
                        append(paste, limit: 32)
                    }
                    return
                }
                if let value = event.characters {
                    let allowed = value.filter { BetaBitmapFont.shared.width(String($0)) > 0 }
                    append(String(allowed), limit: maximumLength)
                }
            }
            private func append(_ value: String, limit: Int) {
                for character in value {
                    if limit > 0 && text.utf16.count + String(character).utf16.count > limit { break }
                    text.append(character)
                }
                changed?(text)
            }
        }
    }

    struct BetaKeyCapture: NSViewRepresentable {
        var captured: (Int) -> Void
        func makeNSView(context: Context) -> CaptureView {
            let view = CaptureView()
            view.captured = captured
            return view
        }
        func updateNSView(_ view: CaptureView, context: Context) { view.captured = captured }
        final class CaptureView: NSView {
            var captured: ((Int) -> Void)?
            override var acceptsFirstResponder: Bool { true }
            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.window?.makeFirstResponder(self)
                }
            }
            override func keyDown(with event: NSEvent) {
                captured?(MacMetalView.lwjglCodes[event.keyCode] ?? 0)
            }
            override func flagsChanged(with event: NSEvent) {
                captured?(MacMetalView.lwjglCodes[event.keyCode] ?? 0)
            }
        }
    }
#endif

struct BetaSlider: View {
    let title: String
    @Binding var value: Float
    var changed: () -> Void = {}
    var body: some View {
        ZStack(alignment: .topLeading) {
            BetaSprite(name: "gui/gui.png", rect: CGRect(x: 0, y: 46, width: 75, height: 20))
            BetaSprite(name: "gui/gui.png", rect: CGRect(x: 125, y: 46, width: 75, height: 20)).offset(x: 75)
            let knob = Int(value * 142)
            BetaSprite(name: "gui/gui.png", rect: CGRect(x: 0, y: 66, width: 4, height: 20)).offset(
                x: CGFloat(knob))
            BetaSprite(name: "gui/gui.png", rect: CGRect(x: 196, y: 66, width: 4, height: 20)).offset(
                x: CGFloat(knob + 4))
            BetaText(title, color: 0xE0E0E0).offset(
                x: CGFloat(150 / 2 - BetaBitmapFont.shared.width(title) / 2), y: 6)
        }.frame(width: 150, height: 20, alignment: .topLeading).contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { gesture in
                    value = min(1, max(0, Float((gesture.location.x - 4) / 142)))
                    changed()
                }
            )
            .accessibilityLabel(title).accessibilityValue("\(Int(value * 100))%")
    }
}
