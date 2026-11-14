import Foundation
import AnalyzersKit

/// The newest release the person has seen What's New for: what decides the sidebar card and the "New" mark on a
/// row. One string in the defaults, the version, so the next release brings the card back once.
@MainActor
enum WhatsNewSeen {
    static let key = "whatsNew.seenVersion"
    /// What the same fact was called before What's New had rows; read once and then forgotten.
    private static let oldKey = "lastSeenChangelog"

    /// Makes sure there is a value. A copy with none and no old key is either a new install or one that updated into the
    /// release that brought the card. A new install (no setup record, no settings file, no background job: the Welcome
    /// flow's own test) must not be told about changes it never had, so it starts as having seen what is installed
    /// (the Welcome flow writes the same value). An existing install starts at the release before the installed one,
    /// so it sees the card once for the release that shipped it.
    static func migrate(installed: String) async {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: key) == nil else { return }
        if let old = defaults.string(forKey: oldKey) {
            defaults.set(old, forKey: key)
            defaults.removeObject(forKey: oldKey)
            return
        }
        let setup = await SetupInputs.read()
        // another caller may have written it while this one was reading
        guard defaults.string(forKey: key) == nil else { return }
        // the Welcome flow's own test of a new install, not a second copy of it
        let inputs = WelcomeSatisfaction.inputs(setup: setup, state: SetupState.load(), hasTimeMachine: false,
                                                version: installed, neverOpen: false)
        let before = WelcomePlanner.isFreshInstall(inputs) ? nil : releaseBefore(installed)
        defaults.set(before ?? installed, forKey: key)
    }

    /// The newest release in the bundled notes that is older than `installed`.
    static func releaseBefore(_ installed: String) -> String? {
        ReleaseNote.bundled(includeNext: false).compactMap(\.version)
            .filter { UpdateChecker.isNewer(installed, than: $0) }
            .max { UpdateChecker.compare($0, $1) == .orderedAscending }
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
