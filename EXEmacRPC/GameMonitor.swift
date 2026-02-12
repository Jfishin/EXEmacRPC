import Foundation

@Observable
final class GameMonitor {
    static let shared = GameMonitor()

    var isEnabled: Bool = false {
        didSet {
            if isEnabled { startScanning() }
            else { stopScanning() }
        }
    }

    var currentGame: String?
    var discordConnected: Bool = false

    private var timer: Timer?
    private var lastDetectedGame: String = ""
    private var gameStartTime: Int = 0
    private var isScanning = false

    private init() {}

    func rescan() {
        guard isEnabled else { return }
        scan()
    }

    private func startScanning() {
        print("[Monitor] Starting scanner")
        scan()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.scan()
        }
    }

    private func stopScanning() {
        print("[Monitor] Stopping scanner")
        timer?.invalidate()
        timer = nil

        Task.detached {
            DiscordIPCClient.shared.clearActivity()
            DiscordIPCClient.shared.disconnect()
            await MainActor.run {
                GameMonitor.shared.currentGame = nil
                GameMonitor.shared.lastDetectedGame = ""
                GameMonitor.shared.discordConnected = false
            }
        }
    }

    private func scan() {
        guard !isScanning else {
            print("[Monitor] Scan skipped (already running)")
            return
        }
        isScanning = true

        let blacklist = AppConfig.shared.blacklist
        let overrides = AppConfig.shared.overrides
        let lastGame = lastDetectedGame

        Task.detached {
            let game = ProcessScanner.scanForGame(blacklist: blacklist, overrides: overrides)

            if game != lastGame {
                if game.isEmpty {
                    print("[Monitor] No game detected, clearing presence")
                    DiscordIPCClient.shared.clearActivity()
                } else {
                    print("[Monitor] New game: \(game)")
                    let newStartTime = Int(Date().timeIntervalSince1970)
                    let coverURL = await IGDBClient.shared.fetchCoverArtURL(for: game)
                    print("[Monitor] Cover URL: \(coverURL ?? "none")")

                    DiscordIPCClient.shared.setActivity(
                        details: game,
                        startTimestamp: newStartTime,
                        largeImageURL: coverURL,
                        largeImageText: game
                    )

                    await MainActor.run {
                        GameMonitor.shared.gameStartTime = newStartTime
                    }
                }
            }

            let connected = DiscordIPCClient.shared.isConnected

            await MainActor.run {
                GameMonitor.shared.lastDetectedGame = game
                GameMonitor.shared.currentGame = game.isEmpty ? nil : game
                GameMonitor.shared.discordConnected = connected
                GameMonitor.shared.isScanning = false
            }
        }
    }
}
