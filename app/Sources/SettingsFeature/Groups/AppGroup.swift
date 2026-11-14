import SwiftUI
import Observation
import AnalyzersKit
#if canImport(ProKit)
import ProKit
#endif

/// What can be pushed from the app's own screens.
enum AppRoute: Hashable, Codable, Sendable {
    /// One feature of What's New on its own screen, by its id (the release's version and its position in it).
    case whatsNew(String)
    /// One How It Works topic.
    case topic(HowItWorksTopic)
}

/// Whether a newer release exists, for the Updates row's badge: read from the app's one
/// `UpdateState` (the main window hands it over), never fetched or compared here.
@MainActor @Observable
final class UpdateBadge {
    static let shared = UpdateBadge()
    weak var state: UpdateState?
    var updateAvailable: Bool { state?.isAvailable ?? false }
}

/// Updates, How It Works and Support.
///
/// A supporter build has no Support row: its badge at the foot of the
/// sidebar is the way in, and the `support` target still lands on the
/// licence screen.
@MainActor
enum AppGroup {

    static let updates = SectionID("updates")
    static let howItWorks = SectionID("howItWorks")
    static let support = SectionID("support")

    static let group = SidebarGroup(
        title: Names.Group.app,
        rows: rows,
        hidden: [support],
        root: screen,
        aliases: [
            "update": .main(Location(updates)),
            "about": .main(Location(howItWorks)),
            "howItWorks": .main(Location(howItWorks)),
            "support": .main(Location(support)),
            // the What's New list: scrolls to it, or also narrows it to the newest release
            "updates:whatsNew": .mainWithIntent(Location(updates), SectionIntent(section: updates, payload: "whatsNew")),
            "updates:whatsNew:latest": .mainWithIntent(Location(updates), SectionIntent(section: updates, payload: "whatsNew:latest")),
        ],
        resolveDynamic: { target in
            if let link = whatsNewLink(target) { return link }
            // `howItWorks:<topic>`: How It Works with that topic's screen on top
            if let topic = HowItWorksTopic.parse(target) { return .main(Location(howItWorks, path: [.app(.topic(topic))])) }
            // `howItWorks:memory|storage|system|yourData`: the screen on that tab (a link only selects and navigates)
            if target.hasPrefix("howItWorks:"), let tab = HowItWorksTab(rawValue: String(target.dropFirst("howItWorks:".count))) {
                ScopeTabMemory.select(tab.rawValue, in: "howItWorks")
                return .main(Location(howItWorks))
            }
            return nil
        },
        load: nil)

    /// `updates:whatsNew:<version>`: the first feature of that release on its own screen.
    private static func whatsNewLink(_ target: String) -> Resolution? {
        let prefix = "updates:whatsNew:"
        guard target.hasPrefix(prefix) else { return nil }
        let version = String(target.dropFirst(prefix.count))
        guard !version.isEmpty else { return nil }
        return .main(Location(updates, path: [.app(.whatsNew("\(version)#0"))]))
    }

    private static var rows: [SidebarRow] {
        var rows = [
            SidebarRow(updates, Names.Screen.updates, symbol: "arrow.down.circle",
                       badge: { UpdateBadge.shared.updateAvailable ? "1" : nil }),
            SidebarRow(howItWorks, Names.Screen.howItWorks, symbol: "questionmark.circle"),
        ]
        #if !canImport(ProKit)
        rows.append(SidebarRow(support, Names.Screen.support, symbol: "heart"))
        #endif
        return rows
    }

    @ViewBuilder private static func screen(_ section: SectionID) -> some View {
        switch section {
        case updates: UpdateSettingsView()
        case howItWorks: HowItWorksView()
        case support:
            #if canImport(ProKit)
            ProLicenseScreen()
            #else
            SupportSettingsView()
            #endif
        default: EmptyView()
        }
    }

    @ViewBuilder static func destination(for route: AppRoute) -> some View {
        switch route {
        case .whatsNew(let id): WhatsNewDetailScreen(id: id)
        case .topic(let topic): TopicScreen(topic: topic)
        }
    }
}
