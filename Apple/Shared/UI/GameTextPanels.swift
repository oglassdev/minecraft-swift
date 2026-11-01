import SwiftUI

struct GameChatOverlay: View {
    @ObservedObject var session: GameSession
    @State private var message = ""
    @State private var focused = true
    @State private var chatStarted = Date()
    @State private var previousMessages: [String] = []
    @State private var lines: [ChatLine] = []
    @State private var nextID = 0
    private struct ChatLine: Identifiable {
        let id: Int
        let text: String
        let tick: Int
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05, paused: !session.chatOpen)) { time in
            BetaGUI(option: session.options.guiScale) { r in
                ZStack(alignment: .topLeading) {
                    if !session.hideHUD || session.chatOpen {
                        ForEach(
                            Array(lines.suffix(session.chatOpen ? 20 : 10).reversed().enumerated()),
                            id: \.element.id
                        ) { index, line in
                            let alpha = opacity(line)
                            if alpha > 0 {
                                Rectangle().fill(.black.opacity(Double(Int(alpha * 255) / 2) / 255)).frame(
                                    width: 320, height: 9
                                )
                                .offset(x: 2, y: CGFloat(r.height - 49 - index * 9))
                                BetaText(line.text).opacity(alpha).offset(
                                    x: 2, y: CGFloat(r.height - 48 - index * 9))
                            }
                        }
                    }
                    if session.chatOpen {
                        if session.isSleeping {
                            BetaButton(title: "Leave Bed", session: session) { session.leaveBed() }.offset(
                                x: CGFloat(r.width / 2 - 100), y: CGFloat(r.height - 40))
                        }
                        let blink = Int(max(0, time.date.timeIntervalSince(chatStarted)) * 20) / 6 % 2 == 0
                        Rectangle().fill(.black.opacity(0.5)).frame(width: CGFloat(r.width - 4), height: 12)
                            .offset(x: 2, y: CGFloat(r.height - 14))
                        BetaText("> " + message + (blink ? "_" : ""), color: 0xE0E0E0).offset(
                            x: 4, y: CGFloat(r.height - 12))
                        #if os(macOS)
                            BetaFieldInput(
                                text: $message, focused: $focused, maximumLength: 100, allowPaste: false,
                                escaped: cancel,
                                submitted: submit, tabbed: {}
                            ).frame(width: CGFloat(r.width - 4), height: 12).offset(
                                x: 2, y: CGFloat(r.height - 14))
                        #else
                            TextField("", text: $message).textFieldStyle(.plain).foregroundStyle(.clear).tint(
                                .clear
                            )
                            .autocorrectionDisabled().textInputAutocapitalization(.never).onSubmit(submit)
                            .frame(width: CGFloat(r.width - 4), height: 12).offset(
                                x: 2, y: CGFloat(r.height - 14))
                            BetaButton(title: "Cancel", width: 50, session: session, action: cancel).offset(
                                x: CGFloat(r.width - 58), y: CGFloat(r.height - 38))
                        #endif
                    }
                }
            }
        }
        .allowsHitTesting(session.chatOpen)
        .onAppear { receiveMessages() }
        .onChange(of: session.chatRevision) { _, _ in receiveMessages() }
        .onChange(of: session.chatOpen) { _, open in
            if open {
                message = ""
                chatStarted = Date()
                focused = true
            }
        }
    }

    private func submit() {
        session.sendChat(message)
        message = ""
    }
    private func cancel() {
        if session.isSleeping {
            session.leaveBed()
            return
        }
        session.chatOpen = false
        session.resetInput()
        message = ""
    }
    private func opacity(_ line: ChatLine) -> Double {
        if session.chatOpen { return 1 }
        let age = session.tickCount - line.tick
        guard age < 200 else { return 0 }
        let fade = min(1, max(0, (1 - Double(age) / 200) * 10))
        return fade * fade
    }
    private func receiveMessages() {
        let messages = session.chatLines
        if messages.isEmpty {
            lines = []
            previousMessages = []
            return
        }
        var overlap = min(previousMessages.count, messages.count)
        while overlap > 0 && Array(previousMessages.suffix(overlap)) != Array(messages.prefix(overlap)) {
            overlap -= 1
        }
        let newMessages =
            overlap == messages.count ? Array(messages.suffix(1)) : Array(messages.dropFirst(overlap))
        for message in newMessages {
            var line = ""
            for character in message {
                if !line.isEmpty && BetaBitmapFont.shared.width(line + String(character)) > 320 {
                    lines.append(ChatLine(id: nextID, text: line, tick: session.tickCount))
                    nextID += 1
                    line = ""
                }
                line.append(character)
            }
            lines.append(ChatLine(id: nextID, text: line, tick: session.tickCount))
            nextID += 1
        }
        if lines.count > 50 { lines.removeFirst(lines.count - 50) }
        previousMessages = messages
    }
}

struct SignEditorPanel: View {
    @ObservedObject var session: GameSession
    var interactionEnabled = true
    @State private var selectedLine = 0
    @State private var opened = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { time in
            BetaGUI(option: session.options.guiScale) { r in
                ZStack(alignment: .topLeading) {
                    BetaScreenShade()
                    BetaText("Edit sign message:").offset(
                        x: CGFloat(r.width / 2 - BetaBitmapFont.shared.width("Edit sign message:") / 2), y: 40
                    )
                    sign(
                        width: r.width,
                        blink: Int(max(0, time.date.timeIntervalSince(opened)) * 20) / 6 % 2 == 0
                    )
                    BetaButton(title: "Done", session: session) { session.finishSignEditing() }.offset(
                        x: CGFloat(r.width / 2 - 100), y: CGFloat(r.height / 4 + 120))
                    #if os(macOS)
                        if interactionEnabled {
                            BetaSignInput(lines: $session.signLines, selected: $selectedLine).frame(
                                width: 1, height: 1)
                        }
                    #else
                        ForEach(0..<4) { index in
                            TextField("", text: $session.signLines[index]).textFieldStyle(.plain)
                                .foregroundStyle(.clear).tint(.clear)
                                .autocorrectionDisabled().textInputAutocapitalization(.never)
                                .frame(width: 94, height: 10).offset(
                                    x: CGFloat(r.width / 2) - 47, y: textY + CGFloat(index) * 10.416667)
                        }
                    #endif
                }
            }
        }
    }

    private var standing: Bool { session.signPosition.flatMap { session.world[$0] } == .standingSign }
    private var textY: CGFloat { standing ? 70.96354 : 100.26042 }
    private func sign(width: Int, blink: Bool) -> some View {
        let shift: CGFloat = standing ? 0 : 29.296875
        return ZStack(alignment: .topLeading) {
            BetaSprite(name: "item/sign.png", rect: CGRect(x: 2, y: 2, width: 24, height: 12))
                .scaleEffect(3.90625, anchor: .topLeading).offset(
                    x: CGFloat(width / 2) - 46.875, y: 68.359375 + shift)
            if standing {
                BetaSprite(name: "item/sign.png", rect: CGRect(x: 2, y: 16, width: 2, height: 14))
                    .scaleEffect(3.90625, anchor: .topLeading).offset(
                        x: CGFloat(width / 2) - 3.90625, y: 115.234375)
            }
            ForEach(0..<4) { index in
                let raw = session.signLines.indices.contains(index) ? session.signLines[index] : ""
                let text = blink && selectedLine == index ? "> " + raw + " <" : raw
                BetaText(text, color: 0, shadow: false).scaleEffect(1.0416667, anchor: .topLeading)
                    .offset(
                        x: CGFloat(width / 2) - CGFloat(BetaBitmapFont.shared.width(text) / 2) * 1.0416667,
                        y: textY + CGFloat(index) * 10.416667)
            }
        }
    }
}

#if os(macOS)
    import AppKit
    private struct BetaSignInput: NSViewRepresentable {
        @Binding var lines: [String]
        @Binding var selected: Int
        func makeNSView(context: Context) -> SignView {
            let view = SignView()
            update(view)
            return view
        }
        func updateNSView(_ view: SignView, context: Context) { update(view) }
        private func update(_ view: SignView) {
            view.lines = lines
            view.selected = selected
            view.changed = {
                lines = $0
                selected = $1
            }
        }
        final class SignView: NSView {
            var lines = ["", "", "", ""]
            var selected = 0
            var changed: (([String], Int) -> Void)?
            override var acceptsFirstResponder: Bool { true }
            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.window?.makeFirstResponder(self)
                }
            }
            override func keyDown(with event: NSEvent) {
                if event.keyCode == 126 {
                    selected = (selected + 3) & 3
                } else if event.keyCode == 125 || event.keyCode == 36 {
                    selected = (selected + 1) & 3
                } else if event.keyCode == 51 {
                    if !lines[selected].isEmpty { lines[selected].removeLast() }
                } else if let characters = event.characters {
                    for character in characters where BetaBitmapFont.shared.width(String(character)) > 0 {
                        if lines[selected].utf16.count + String(character).utf16.count <= 15 {
                            lines[selected].append(character)
                        }
                    }
                }
                changed?(lines, selected)
            }
        }
    }
#endif
