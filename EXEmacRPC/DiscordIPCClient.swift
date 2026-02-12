import Foundation

final class DiscordIPCClient: @unchecked Sendable {
    nonisolated static let shared = DiscordIPCClient()

    private let clientID = Secrets.discordClientID
    nonisolated(unsafe) private var socketFD: Int32 = -1
    nonisolated(unsafe) private var _isConnected = false
    private let lock = NSLock()

    private enum Opcode: UInt32 {
        case handshake = 0
        case frame = 1
        case close = 2
    }

    nonisolated private init() {}

    // MARK: - Connection

    nonisolated var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConnected
    }

    @discardableResult
    nonisolated func connect() -> Bool {
        lock.lock()
        if _isConnected { lock.unlock(); return true }
        lock.unlock()

        let tmpDirs = [
            ProcessInfo.processInfo.environment["TMPDIR"],
            ProcessInfo.processInfo.environment["TMP"],
            ProcessInfo.processInfo.environment["TEMP"],
            "/tmp"
        ].compactMap { $0 }

        for tmpDir in tmpDirs {
            for i in 0...9 {
                let path = (tmpDir as NSString).appendingPathComponent("discord-ipc-\(i)")
                if connectToSocket(path: path) {
                    if performHandshake() {
                        lock.lock()
                        _isConnected = true
                        lock.unlock()
                        print("[Discord] Connected via \(path)")
                        return true
                    }
                    Darwin.close(socketFD)
                    socketFD = -1
                }
            }
        }
        print("[Discord] Failed to connect - is Discord running?")
        return false
    }

    nonisolated func disconnect() {
        lock.lock()
        guard _isConnected else { lock.unlock(); return }
        _isConnected = false
        let fd = socketFD
        socketFD = -1
        lock.unlock()

        Darwin.close(fd)
        print("[Discord] Disconnected")
    }

    // MARK: - Socket

    nonisolated private func connectToSocket(path: String) -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }

        // Set read/write timeout to 3 seconds
        var timeout = timeval(tv_sec: 3, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = path.utf8CString
        let maxLen = MemoryLayout.size(ofValue: addr.sun_path)
        guard pathBytes.count <= maxLen else {
            Darwin.close(fd)
            return false
        }

        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: maxLen) { dest in
                for (i, byte) in pathBytes.enumerated() {
                    dest[i] = byte
                }
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(fd, sockPtr, addrLen)
            }
        }

        if result != 0 {
            Darwin.close(fd)
            return false
        }

        lock.lock()
        socketFD = fd
        lock.unlock()
        return true
    }

    // MARK: - Handshake

    nonisolated private func performHandshake() -> Bool {
        let payload: [String: Any] = ["v": 1, "client_id": clientID]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        guard sendFrame(opcode: .handshake, data: data) else { return false }
        guard let (opcode, responseData) = readFrame() else {
            print("[Discord] Handshake: no response")
            return false
        }
        if opcode == Opcode.frame.rawValue {
            if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let evt = json["evt"] as? String {
                print("[Discord] Handshake: \(evt)")
            }
            return true
        }
        print("[Discord] Handshake failed: opcode \(opcode)")
        return false
    }

    // MARK: - Frame I/O

    @discardableResult
    nonisolated private func sendFrame(opcode: Opcode, data: Data) -> Bool {
        lock.lock()
        let fd = socketFD
        lock.unlock()
        guard fd >= 0 else { return false }

        var buffer = Data(capacity: 8 + data.count)
        var op = opcode.rawValue.littleEndian
        var len = UInt32(data.count).littleEndian
        buffer.append(Data(bytes: &op, count: 4))
        buffer.append(Data(bytes: &len, count: 4))
        buffer.append(data)

        return buffer.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return false }
            let sent = Darwin.write(fd, base, buffer.count)
            return sent == buffer.count
        }
    }

    nonisolated private func readFrame() -> (UInt32, Data)? {
        lock.lock()
        let fd = socketFD
        lock.unlock()
        guard fd >= 0 else { return nil }

        var header = [UInt8](repeating: 0, count: 8)
        let headerRead = Darwin.read(fd, &header, 8)
        guard headerRead == 8 else { return nil }

        let opcode = header.withUnsafeBytes {
            $0.load(fromByteOffset: 0, as: UInt32.self).littleEndian
        }
        let length = header.withUnsafeBytes {
            $0.load(fromByteOffset: 4, as: UInt32.self).littleEndian
        }

        guard length > 0, length < 1_000_000 else { return (opcode, Data()) }

        var payload = [UInt8](repeating: 0, count: Int(length))
        var totalRead = 0
        while totalRead < Int(length) {
            let n = Darwin.read(fd, &payload[totalRead], Int(length) - totalRead)
            if n <= 0 { return nil }
            totalRead += n
        }

        return (opcode, Data(payload))
    }

    // MARK: - Activity

    nonisolated func setActivity(
        details: String,
        startTimestamp: Int,
        largeImageURL: String? = nil,
        largeImageText: String? = nil
    ) {
        if !isConnected {
            guard connect() else { return }
        }

        var assets: [String: Any] = [:]
        if let url = largeImageURL {
            assets["large_image"] = url
            if let text = largeImageText {
                assets["large_text"] = text
            }
        }

        var activity: [String: Any] = [
            "details": details,
            "timestamps": ["start": startTimestamp]
        ]
        if !assets.isEmpty {
            activity["assets"] = assets
        }

        let payload: [String: Any] = [
            "cmd": "SET_ACTIVITY",
            "args": [
                "pid": ProcessInfo.processInfo.processIdentifier,
                "activity": activity
            ],
            "nonce": UUID().uuidString
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }

        if !sendFrame(opcode: .frame, data: data) {
            print("[Discord] Send failed, reconnecting...")
            lock.lock()
            _isConnected = false
            lock.unlock()
            disconnect()
            if connect() {
                sendFrame(opcode: .frame, data: data)
            }
        }

        // Read response
        if let (_, responseData) = readFrame() {
            if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let evt = json["evt"] as? String {
                print("[Discord] SET_ACTIVITY response: \(evt)")
            }
        }
    }

    nonisolated func clearActivity() {
        guard isConnected else { return }

        let payload: [String: Any] = [
            "cmd": "SET_ACTIVITY",
            "args": [
                "pid": ProcessInfo.processInfo.processIdentifier
            ],
            "nonce": UUID().uuidString
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        sendFrame(opcode: .frame, data: data)
        _ = readFrame()
        print("[Discord] Activity cleared")
    }
}
