import SwiftUI

@main
struct EXEmacRPCApp: App {
    @State private var monitor = GameMonitor.shared

    var body: some Scene {
        MenuBarExtra("EXEmacRPC", systemImage: "paperplane.fill") {
            ContentView()
        }

        Window("Configuration", id: "config-window") {
            ConfigView()
        }
        .windowResizability(.contentSize)
    }
}
