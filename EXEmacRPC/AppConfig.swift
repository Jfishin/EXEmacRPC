import Foundation

@Observable
final class AppConfig {
    static let shared = AppConfig()

    var blacklist: Set<String>
    var overrides: [String: String]

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
                "winedbg", "winedevice", "winewrapper",
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
            save()
        }
    }

    func save() {
        let stored = StoredConfig(
            blacklist: Array(blacklist).sorted(),
            overrides: overrides
        )
        if let data = try? JSONEncoder().encode(stored) {
            try? data.write(to: configURL, options: .atomic)
        }
    }
}

private struct StoredConfig: Codable {
    let blacklist: [String]
    let overrides: [String: String]
}
