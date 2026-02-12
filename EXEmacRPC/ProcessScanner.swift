import Foundation

enum ProcessScanner {
    nonisolated static func scanForGame(
        blacklist: Set<String>,
        overrides: [String: String]
    ) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "args="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            print("[Scanner] Failed to run ps: \(error)")
            return ""
        }

        // Read pipe BEFORE waitUntilExit to avoid deadlock when output > pipe buffer
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8) else {
            print("[Scanner] Failed to decode ps output")
            return ""
        }

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.lowercased().contains(".exe") else { continue }

            // Extract the full path/name ending in .exe, including spaces
            guard let range = trimmed.range(of: #"\S.*?\.exe"#, options: [.regularExpression, .caseInsensitive]) else { continue }
            let exePath = String(trimmed[range])

            let name = NameCleaner.clean(exePath, blacklist: blacklist, overrides: overrides)
            if !name.isEmpty {
                print("[Scanner] Detected: \(name)")
                return name
            }
        }

        return ""
    }
}
