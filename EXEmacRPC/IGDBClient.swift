import Foundation

final class IGDBClient {
    static let shared = IGDBClient()

    private let twitchClientID = Secrets.twitchClientID
    private let twitchClientSecret = Secrets.twitchClientSecret

    private var accessToken: String?
    private var tokenExpiry: Date = .distantPast

    private static let cacheKey = "IGDBCoverCache"
    private var coverCache: [String: String] = UserDefaults.standard.dictionary(forKey: IGDBClient.cacheKey) as? [String: String] ?? [:]

    private func saveCacheToDisk() {
        UserDefaults.standard.set(coverCache, forKey: IGDBClient.cacheKey)
    }

    func fetchCoverArtURL(for gameName: String) async -> String? {
        let cacheKey = gameName.lowercased()

        if let cached = coverCache[cacheKey] {
            return cached.isEmpty ? nil : cached
        }

        guard await ensureAuthenticated() else { return nil }
        guard let token = accessToken else { return nil }

        let escapedName = gameName.replacingOccurrences(of: "\"", with: "\\\"")
        let query = "search \"\(escapedName)\"; fields name,cover.image_id; limit 1;"

        var request = URLRequest(url: URL(string: "https://api.igdb.com/v4/games")!)
        request.httpMethod = "POST"
        request.setValue(twitchClientID, forHTTPHeaderField: "Client-ID")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = query.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let games = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let firstGame = games.first,
                  let cover = firstGame["cover"] as? [String: Any],
                  let imageID = cover["image_id"] as? String
            else {
                coverCache[cacheKey] = ""
                saveCacheToDisk()
                return nil
            }

            let url = "https://images.igdb.com/igdb/image/upload/t_cover_big/\(imageID).jpg"
            coverCache[cacheKey] = url
            saveCacheToDisk()
            return url
        } catch {
            return nil
        }
    }

    private func ensureAuthenticated() async -> Bool {
        if accessToken != nil && Date() < tokenExpiry {
            return true
        }

        guard twitchClientID != "YOUR_TWITCH_CLIENT_ID" else { return false }

        var components = URLComponents(string: "https://id.twitch.tv/oauth2/token")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: twitchClientID),
            URLQueryItem(name: "client_secret", value: twitchClientSecret),
            URLQueryItem(name: "grant_type", value: "client_credentials"),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String,
                  let expiresIn = json["expires_in"] as? Int
            else { return false }

            self.accessToken = token
            self.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
            return true
        } catch {
            return false
        }
    }
}
