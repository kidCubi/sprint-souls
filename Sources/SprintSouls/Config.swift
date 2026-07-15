import Foundation

struct Config: Codable {
    var anchor: String        // local time, e.g. "2026-07-16T08:00:00"
    var intervalDays: Int
    var title: String
    var subtitle: String?
    var soundPath: String?

    static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var anchorDate: Date? { Config.dateFormat.date(from: anchor) }

    /// Explicit soundPath wins; otherwise any "sound.*" audio file dropped
    /// into the config directory is used, then the default one shipped next
    /// to the binary by install.sh.
    var resolvedSoundPath: String? {
        if let soundPath, !soundPath.isEmpty {
            return (soundPath as NSString).expandingTildeInPath
        }
        var directories = [Config.directory]
        if let executable = Bundle.main.executableURL {
            directories.append(executable.deletingLastPathComponent())
        }
        for directory in directories {
            for ext in ["mp3", "m4a", "aiff", "aif", "wav", "caf"] {
                let candidate = directory.appendingPathComponent("sound.\(ext)").path
                if FileManager.default.fileExists(atPath: candidate) { return candidate }
            }
        }
        return nil
    }

    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/sprint-souls", isDirectory: true)
    }
    static var configURL: URL { directory.appendingPathComponent("config.json") }
    static var stateURL: URL { directory.appendingPathComponent("state.json") }

    static func load() -> Config {
        if let data = try? Data(contentsOf: configURL),
           let config = try? JSONDecoder().decode(Config.self, from: data) {
            return config
        }
        let config = Config.default()
        config.save()
        return config
    }

    func save() {
        try? FileManager.default.createDirectory(at: Config.directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(self) {
            try? data.write(to: Config.configURL)
        }
    }

    static func `default`() -> Config {
        // Anchor on the next Thursday at 08:00 local time.
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekday = 5 // Thursday
        components.hour = 8
        components.minute = 0
        components.second = 0
        let anchorDate = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) ?? Date()
        return Config(
            anchor: dateFormat.string(from: anchorDate),
            intervalDays: 14,
            title: "SPRINT {n} STARTED",
            subtitle: nil,
            soundPath: nil
        )
    }
}

struct State: Codable {
    var lastShownBoundary: String?

    static func load() -> State {
        if let data = try? Data(contentsOf: Config.stateURL),
           let state = try? JSONDecoder().decode(State.self, from: data) {
            return state
        }
        return State(lastShownBoundary: nil)
    }

    func save() {
        try? FileManager.default.createDirectory(at: Config.directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: Config.stateURL)
        }
    }
}
