import Foundation

/// Settings › About: "0.1.2 (57)" and when this version first ran here (an install or an update).
enum AppVersion {
    static let label: String = {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] ?? "?") (\(info?["CFBundleVersion"] ?? "?"))"
    }()

    static var updatedAt: Date? { UserDefaults.standard.object(forKey: "updatedAt") as? Date }

    /// Call once at launch: the first run of a new version counts as the update time.
    static func recordLaunch() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: "seenVersion") != label else { return }
        defaults.set(label, forKey: "seenVersion")
        defaults.set(Date(), forKey: "updatedAt")
    }
}
