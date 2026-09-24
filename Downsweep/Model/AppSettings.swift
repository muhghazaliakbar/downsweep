import Foundation
import SweepCore

enum SweepMode: String, Codable, CaseIterable, Identifiable {
    /// Suggest only; the person approves each sweep.
    case review
    /// Apply suggestions as they appear, within the safety limit.
    case automatic

    var id: String { rawValue }
}

/// Everything the person configures, stored as one JSON blob in UserDefaults.
struct AppSettings: Codable, Equatable {
    var mode: SweepMode = .review
    var folderPath: String = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].path
    var configuration = SweepConfiguration()
    var hasCompletedOnboarding = false

    var folderURL: URL { URL(filePath: folderPath, directoryHint: .isDirectory) }

    private static let key = "settings.v1"

    static func load(from defaults: UserDefaults = .standard) -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
