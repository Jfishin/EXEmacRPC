import SwiftUI

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    private var monitor = GameMonitor.shared

    var body: some View {
        VStack(spacing: 12) {
            Button(monitor.isEnabled ? "Disable" : "Enable") {
                monitor.isEnabled.toggle()
            }
            .buttonStyle(.borderedProminent)
            .tint(monitor.isEnabled ? .red : .green)

            Button("Show Config") {
                openWindow(id: "config-window")
                NSApp.activate()
            }

            Divider()

            if let game = monitor.currentGame {
                HStack(spacing: 6) {
                    Circle()
                        .fill(monitor.discordConnected ? .green : .orange)
                        .frame(width: 6, height: 6)
                    Text(game)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Divider()
            }

            Button("Quit") {
                Task.detached {
                    DiscordIPCClient.shared.clearActivity()
                    DiscordIPCClient.shared.disconnect()
                    await MainActor.run {
                        NSApp.terminate(nil)
                    }
                }
            }
        }
        .padding()
        .frame(width: 200)
    }
}
