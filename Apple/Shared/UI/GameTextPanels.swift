import SwiftUI

struct GameChatOverlay: View {
    @ObservedObject var session: GameSession
    @State private var message = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
            ForEach(Array(session.chatLines.suffix(session.chatOpen ? 12 : 5).enumerated()), id: \.offset) {
                _, line in
                Text(line).font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white).padding(.horizontal, 5).padding(.vertical, 2)
                    .background(.black.opacity(0.55)).textSelection(.disabled)
            }
            if session.chatOpen {
                HStack {
                    TextField("Message…", text: $message).focused($focused)
                        .textFieldStyle(.plain).onSubmit(submit)
                        .foregroundStyle(.white).padding(10).background(.black.opacity(0.8))
                    Button("Send", action: submit).buttonStyle(GameMenuButtonStyle()).frame(width: 80)
                    Button("Cancel") {
                        session.chatOpen = false
                        session.resetInput()
                    }
                    .buttonStyle(GameMenuButtonStyle()).frame(width: 80)
                }
            }
        }
        .padding(.horizontal, 12).padding(.bottom, session.chatOpen ? 12 : 120)
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(session.chatOpen)
        .onChange(of: session.chatOpen) { _, open in focused = open }
    }

    private func submit() {
        session.sendChat(message)
        message = ""
    }
}

struct SignEditorPanel: View {
    @ObservedObject var session: GameSession

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Edit sign").font(.title2).foregroundStyle(.white)
                VStack(spacing: 4) {
                    ForEach(0..<4) { index in
                        TextField("", text: $session.signLines[index])
                            .multilineTextAlignment(.center).textFieldStyle(.plain)
                            .font(.system(size: 18, design: .monospaced)).foregroundStyle(.black)
                    }
                }
                .padding(20).background(Color(red: 0.62, green: 0.43, blue: 0.23))
                Button("Done") { session.finishSignEditing() }.buttonStyle(GameMenuButtonStyle())
            }.frame(width: 320)
        }
    }
}
