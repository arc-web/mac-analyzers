import Foundation
import AnalyzersKit

/// The newest release the person has seen What's New for: what decides the sidebar card and the "New" mark on a
/// row. One string in the defaults, the version, so the next release brings the card back once.
enum WhatsNewSeen {
    static let key = "whatsNew.seenVersion"
    /// What the same fact was called before What's New had rows; read once and then forgotten.
    private static let oldKey = "lastSeenChangelog"

    /// Makes sure there is a value. A copy that has none and never wrote the old key is a first launch, and a first
    /// launch must not announce changes the person never had: it starts as having seen what is installed.
    static func migrate(installed: String) {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: key) == nil else { return }
        defaults.set(defaults.string(forKey: oldKey) ?? installed, forKey: key)
        defaults.removeObject(forKey: oldKey)
    }

    static var version: String? { UserDefaults.standard.string(forKey: key) }

    /// Records that `version` has been seen. Never moves backwards.
    static func markSeen(_ version: String) {
        if let seen = self.version, !UpdateChecker.isNewer(version, than: seen) { return }
        UserDefaults.standard.set(version, forKey: key)
    }

    /// Whether a release is newer than what the person last saw.
    static func isNew(_ version: String?, seen: String?) -> Bool {
        guard let version else { return false }
        guard let seen, !seen.isEmpty else { return false }
        return UpdateChecker.isNewer(version, than: seen)
    }
}
