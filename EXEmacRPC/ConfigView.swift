import SwiftUI

struct ConfigView: View {
    private var config = AppConfig.shared
    private var monitor = GameMonitor.shared

    @State private var newBlacklistEntry = ""
    @State private var newOverrideKey = ""
    @State private var newOverrideValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configuration")
                .font(.title2)
                .bold()

            // Tracked process status
            GroupBox {
                HStack {
                    Circle()
                        .fill(monitor.discordConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    if let game = monitor.currentGame {
                        Text("Tracking: \(game)")
                            .font(.system(.body, design: .monospaced))
                    } else if monitor.isEnabled {
                        Text("Scanning... no game detected")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Scanner disabled")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            GroupBox("Blacklist") {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(config.blacklist.sorted(), id: \.self) { entry in
                                HStack {
                                    Text(entry)
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                    Button(role: .destructive) {
                                        config.blacklist.remove(entry)
                                        config.save()
                                        monitor.rescan()
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.trailing, 14)
                    }
                    .frame(maxHeight: 150)

                    HStack {
                        TextField("Add process name...", text: $newBlacklistEntry)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addBlacklistEntry() }
                        Button("Add") { addBlacklistEntry() }
                    }
                }
                .padding(8)
            }

            GroupBox("Name Overrides") {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(
                                config.overrides.sorted(by: { $0.key < $1.key }),
                                id: \.key
                            ) { key, value in
                                HStack {
                                    Text(key)
                                        .font(.system(.body, design: .monospaced))
                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(.secondary)
                                    Text(value)
                                    Spacer()
                                    Button(role: .destructive) {
                                        config.overrides.removeValue(forKey: key)
                                        config.save()
                                        monitor.rescan()
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.trailing, 14)
                    }
                    .frame(maxHeight: 150)

                    HStack {
                        TextField("Process name", text: $newOverrideKey)
                            .textFieldStyle(.roundedBorder)
                        TextField("Display name", text: $newOverrideValue)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addOverride() }
                        Button("Add") { addOverride() }
                    }
                }
                .padding(8)
            }
        }
        .padding(20)
        .frame(width: 450)
        .frame(minHeight: 500)
    }

    private func addBlacklistEntry() {
        let entry = newBlacklistEntry.trimmingCharacters(in: .whitespaces).lowercased()
        guard !entry.isEmpty else { return }
        config.blacklist.insert(entry)
        config.save()
        monitor.rescan()
        newBlacklistEntry = ""
    }

    private func addOverride() {
        let key = newOverrideKey.trimmingCharacters(in: .whitespaces).lowercased()
        let value = newOverrideValue.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !value.isEmpty else { return }
        config.overrides[key] = value
        config.save()
        monitor.rescan()
        newOverrideKey = ""
        newOverrideValue = ""
    }
}
