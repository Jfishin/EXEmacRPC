import Foundation

@Observable
final class AppConfig {
    static let shared = AppConfig()

    var blacklist: Set<String>
    var overrides: [String: String]
    var platform: String  // "crossover", "portingkit", or "sikarugir"
    var customPlatformEnabled: Bool
    var customDiscordClientID: String
    var customPublicKey: String

    var activeDiscordClientID: String {
        if customPlatformEnabled, !customDiscordClientID.isEmpty {
            return customDiscordClientID
        }
        switch platform {
        case "portingkit": return Secrets.portingKitDiscordClientID
        case "sikarugir": return Secrets.sikarugirDiscordClientID
        case "wine": return Secrets.wineDiscordClientID
        default: return Secrets.discordClientID
        }
    }

    private let configURL: URL

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("EXEmacRPC")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.configURL = appSupport.appendingPathComponent("config.json")

        if let data = try? Data(contentsOf: configURL),
           let stored = try? JSONDecoder().decode(StoredConfig.self, from: data) {
            self.blacklist = Set(stored.blacklist)
            self.overrides = Dictionary(
                stored.overrides.map { ($0.key.lowercased(), $0.value) },
                uniquingKeysWith: { _, last in last }
            )
            self.platform = stored.platform ?? "crossover"
            self.customPlatformEnabled = stored.customPlatformEnabled ?? false
            self.customDiscordClientID = stored.customDiscordClientID ?? ""
            self.customPublicKey = stored.customPublicKey ?? ""
        } else {
            self.blacklist = Set([
                "ac4bfsp", "andale32", "bridge", "cmd", "conhost", "cxcplinfo",
                "cxmanip", "dxsetup", "explorer", "gameoverlayui", "gameoverlaygui64", "gldriverquery64",
                "ndp452-kb2901907-x86-x64-allos-enu",
                "plugplay", "rpcss", "services", "start", "steam",
                "steamerrorreporter", "steamerrorreporter64", "steamservice", "steamsysinfo",
                "steamwebhelper", "svchost", "unitycrashhandler64", "upc",
                "ubisoftgamelauncher", "uplayservice", "uplaywebcore",
                "vcredist_x64", "vcredist_x86", "vulkandriverquery",
                "vulkandriverquery64", "wine", "wineboot", "winecfg",
                "winedbg", "winedevice", "winemenubuilder", "winewrapper",
                "crashpad_handler"
            ])
            self.overrides = [
                "d2": "Diablo II",
                "hl2": "Half Life 2",
                "precinct": "The Precinct",
                "bbq": "The First Berserker Khazan",
                "kz": "The First Berserker Khazan",
                "etg": "Enter the Gungeon"
            ]
            self.platform = "crossover"
            self.customPlatformEnabled = false
            self.customDiscordClientID = ""
            self.customPublicKey = ""
            save()
        }
    }

    func save() {
        let stored = StoredConfig(
            blacklist: Array(blacklist).sorted(),
            overrides: overrides,
            platform: platform,
            customPlatformEnabled: customPlatformEnabled,
            customDiscordClientID: customDiscordClientID,
            customPublicKey: customPublicKey
        )
        if let data = try? JSONEncoder().encode(stored) {
            try? data.write(to: configURL, options: .atomic)
        }
    }
}

private struct StoredConfig: Codable {
    let blacklist: [String]
    let overrides: [String: String]
    let platform: String?
    let customPlatformEnabled: Bool?
    let customDiscordClientID: String?
    let customPublicKey: String?
}
