import Foundation
import MinecraftCore
import Network

@MainActor
final class MultiplayerClient {
    private let onPacket: @MainActor (BetaPacket) -> Void
    private let onDisconnect: @MainActor (String) -> Void
    private let queue = DispatchQueue(label: "minecraft-swift.multiplayer")
    private var connection: NWConnection?
    private var decoder = BetaPacketCodec()
    private var timeout: Task<Void, Never>?
    private var username = ""
    private var loggedIn = false

    init(
        onPacket: @escaping @MainActor (BetaPacket) -> Void,
        onDisconnect: @escaping @MainActor (String) -> Void
    ) {
        self.onPacket = onPacket
        self.onDisconnect = onDisconnect
    }

    func connect(host: String, port: UInt16, username: String) {
        close(reason: nil)
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, port > 0, !username.isEmpty, username.utf16.count <= 16,
            let endpointPort = NWEndpoint.Port(rawValue: port)
        else {
            onDisconnect("Enter a server address, a port from 1 to 65535, and a username of 1–16 characters.")
            return
        }
        self.username = username
        let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            Task { @MainActor in
                guard let self, let connection, self.connection === connection else { return }
                switch state {
                case .ready:
                    self.send(.handshake(self.username))
                    self.receive(from: connection)
                case .failed(let error): self.close(reason: error.localizedDescription)
                case .cancelled: self.close(reason: "Disconnected")
                default: break
                }
            }
        }
        connection.start(queue: queue)
        timeout = Task { [weak self, weak connection] in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            guard let self, let connection, self.connection === connection, !self.loggedIn else { return }
            self.close(reason: "The server did not complete the Beta 1.7.3 login.")
        }
    }

    func send(_ packet: BetaPacket) {
        guard let connection else { return }
        do {
            guard Self.clientPacketIDs.contains(packet.id) else {
                throw BetaProtocolError.invalid("This packet can only be sent by a Beta server.")
            }
            let data = try BetaPacketCodec.encode(packet)
            connection.send(
                content: data,
                completion: .contentProcessed { [weak self, weak connection] error in
                    guard let error else { return }
                    Task { @MainActor in
                        guard let self, let connection, self.connection === connection else { return }
                        self.close(reason: error.localizedDescription)
                    }
                })
        } catch { close(reason: error.localizedDescription) }
    }

    func disconnect() {
        guard connection != nil else { return }
        send(.disconnect("Quitting"))
        close(reason: "Disconnected")
    }

    private func receive(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) {
            [weak self, weak connection] data, _, complete, error in
            Task { @MainActor in
                guard let self, let connection, self.connection === connection else { return }
                do {
                    if let data {
                        for packet in try self.decoder.append(data) {
                            guard self.connection === connection else { return }
                            self.handle(packet)
                        }
                    }
                    guard self.connection === connection else { return }
                    if let error {
                        self.close(reason: error.localizedDescription)
                    } else if complete {
                        self.close(reason: "The server closed the connection.")
                    } else {
                        self.receive(from: connection)
                    }
                } catch { self.close(reason: "Invalid Beta server packet: \(error.localizedDescription)") }
            }
        }
    }

    private func handle(_ packet: BetaPacket) {
        switch packet {
        case .handshake(let serverID):
            guard serverID == "-" else {
                close(
                    reason:
                        "This server requires legacy online authentication, which is unavailable. Connect to an offline-mode Beta 1.7.3 server."
                )
                return
            }
            send(
                .login(
                    entityIDOrProtocol: BetaPacketCodec.protocolVersion, username: username, seed: 0,
                    dimension: 0))
        case .keepAlive: send(.keepAlive)
        case .login:
            loggedIn = true
            timeout?.cancel()
            timeout = nil
        case .disconnect(let reason):
            onPacket(packet)
            close(reason: reason)
            return
        default: break
        }
        onPacket(packet)
    }

    private func close(reason: String?) {
        let wasConnected = connection != nil
        timeout?.cancel()
        timeout = nil
        let previous = connection
        connection = nil
        previous?.stateUpdateHandler = nil
        previous?.cancel()
        decoder.reset()
        loggedIn = false
        if let reason, wasConnected { onDisconnect(reason) }
    }

    private static let clientPacketIDs: Set<UInt8> = [
        0, 1, 2, 3, 7, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 27, 101, 102, 106, 130, 255,
    ]
}
