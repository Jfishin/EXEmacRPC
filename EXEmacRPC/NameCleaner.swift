import Foundation

enum NameCleaner {
    nonisolated static func clean(
        _ path: String,
        blacklist: Set<String>,
        overrides: [String: String]
    ) -> String {
        guard !path.isEmpty else { return "" }

        let normalized = path
            .replacingOccurrences(of: "\\\\", with: "/")
            .replacingOccurrences(of: "\\", with: "/")

        let filename = normalized.components(separatedBy: "/").last ?? normalized

        guard filename.lowercased().hasSuffix(".exe") else { return "" }

        var base = String(filename.dropLast(4))

        // Remove Unreal Engine build suffixes
        if let range = base.range(of: #"-Win(32|64)-Shipping$"#, options: .regularExpression) {
            base = String(base[base.startIndex..<range.lowerBound])
        }

        let lower = base.lowercased()

        if blacklist.contains(lower) { return "" }

        if let override = overrides[lower] { return override }

        // CamelCase splitting: "TheMessenger" -> "The Messenger"
        let split = base.replacingOccurrences(
            of: #"(?<=[a-z])(?=[A-Z])"#,
            with: " ",
            options: .regularExpression
        )
        return split
    }
}
