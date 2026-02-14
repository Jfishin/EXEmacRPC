import SwiftUI

struct ConfigView: View {
    private var config = AppConfig.shared
    private var monitor = GameMonitor.shared

    @State private var newBlacklistEntry = ""
    @State private var newOverrideKey = ""
    @State private var newOverrideValue = ""
    @State private var showCustomClientID = false
    @State private var showCustomPublicKey = false

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configuration")
                .font(.title2)
                .bold()

            HStack {
                Picker("Platform", selection: Binding(
                    get: { config.platform },
                    set: { newValue in
                        config.platform = newValue
                        config.save()
                        if monitor.isEnabled {
                            let newID = config.activeDiscordClientID
                            Task.detached {
                                DiscordIPCClient.shared.reconnectWithNewClientID(newClientID: newID)
                                let connected = DiscordIPCClient.shared.isConnected
                                await MainActor.run {
                                    monitor.discordConnected = connected
                                    monitor.rescan()
                                }
                            }
                        }
                    }
                )) {
                    Text("CrossOver").tag("crossover")
                    Text("Porting Kit").tag("portingkit")
                    Text("Sikarugir").tag("sikarugir")
                    Text("WINE").tag("wine")
                }
                .pickerStyle(.menu)
                .disabled(config.customPlatformEnabled)

                Text("Re-enable the scanner to apply")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Custom Platform", isOn: Binding(
                get: { config.customPlatformEnabled },
                set: { newValue in
                    config.customPlatformEnabled = newValue
                    config.save()
                    if monitor.isEnabled {
                        let newID = config.activeDiscordClientID
                        Task.detached {
                            DiscordIPCClient.shared.reconnectWithNewClientID(newClientID: newID)
                            let connected = DiscordIPCClient.shared.isConnected
                            await MainActor.run {
                                monitor.discordConnected = connected
                                monitor.rescan()
                            }
                        }
                    }
                }
            ))

            if config.customPlatformEnabled {
                Link("Create app at discord.com/developers/applications",
                     destination: URL(string: "https://discord.com/developers/applications")!)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if showCustomClientID {
                                TextField("Application ID", text: Binding(
                                    get: { config.customDiscordClientID },
                                    set: { config.customDiscordClientID = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            } else {
                                SecureField("Application ID", text: Binding(
                                    get: { config.customDiscordClientID },
                                    set: { config.customDiscordClientID = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            }
                            Button {
                                showCustomClientID.toggle()
                            } label: {
                                Image(systemName: showCustomClientID ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.plain)
                        }
                        HStack {
                            if showCustomPublicKey {
                                TextField("Public Key", text: Binding(
                                    get: { config.customPublicKey },
                                    set: { config.customPublicKey = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            } else {
                                SecureField("Public Key", text: Binding(
                                    get: { config.customPublicKey },
                                    set: { config.customPublicKey = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            }
                            Button {
                                showCustomPublicKey.toggle()
                            } label: {
                                Image(systemName: showCustomPublicKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.plain)
                        }
                        HStack {
                            Spacer()
                            Button("Save") {
                                config.save()
                                if monitor.isEnabled {
                                    let newID = config.activeDiscordClientID
                                    Task.detached {
                                        DiscordIPCClient.shared.reconnectWithNewClientID(newClientID: newID)
                                        let connected = DiscordIPCClient.shared.isConnected
                                        await MainActor.run {
                                            monitor.discordConnected = connected
                                            monitor.rescan()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(8)
                }
            }

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
        }
        .frame(width: 450)
        .frame(minHeight: 600)
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
