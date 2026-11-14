import SwiftUI
import AnalyzersKit

/// The explainer's four tabs: three kinds of thing the app looks after, and the files it keeps.
enum HowItWorksTab: String, CaseIterable, Hashable, Sendable {
    case memory, storage, system, yourData

    var title: String {
        switch self {
        case .memory: Names.Group.memory
        case .storage: Names.Group.storage
        case .system: Names.Group.system
        case .yourData: Names.HowItWorks.yourData
        }
    }

    var symbol: String {
        switch self {
        case .memory: "memorychip"
        case .storage: "internaldrive"
        case .system: "gearshape.2"
        case .yourData: "folder"
        }
    }
}

/// One thing the app explains. Its deep link is `howItWorks:<raw value>`; each data screen's help button names one.
enum HowItWorksTopic: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case measures, guardSteps, guardNever, cleanup
    case safeToRemove, downloadsTemp, timeMachine, unusedApps, oldRecordings
    case loginItems, network
    case whereWritten, editByHand, healthReport, privacy

    var id: String { rawValue }

    var tab: HowItWorksTab {
        switch self {
        case .measures, .guardSteps, .guardNever, .cleanup: .memory
        case .safeToRemove, .downloadsTemp, .timeMachine, .unusedApps, .oldRecordings: .storage
        case .loginItems, .network: .system
        case .whereWritten, .editByHand, .healthReport, .privacy: .yourData
        }
    }

    var title: String {
        switch self {
        case .measures: Names.HowItWorks.measures
        case .guardSteps: Names.HowItWorks.guardSteps
        case .guardNever: Names.HowItWorks.guardNever
        case .cleanup: Names.HowItWorks.cleanup
        case .safeToRemove: Names.HowItWorks.safeToRemove
        case .downloadsTemp: Names.HowItWorks.downloadsTemp
        case .timeMachine: Names.HowItWorks.timeMachine
        case .unusedApps: Names.HowItWorks.unusedApps
        case .oldRecordings: Names.HowItWorks.oldRecordings
        case .loginItems: Names.HowItWorks.loginItems
        case .network: Names.HowItWorks.network
        case .whereWritten: Names.HowItWorks.whereWritten
        case .editByHand: Names.HowItWorks.editByHand
        case .healthReport: Names.HowItWorks.healthReport
        case .privacy: Names.HowItWorks.privacy
        }
    }

    var symbol: String {
        switch self {
        case .measures: "gauge.with.dots.needle.67percent"
        case .guardSteps: "shield.lefthalf.filled"
        case .guardNever: "hand.raised"
        case .cleanup: "sparkles"
        case .safeToRemove: "shippingbox"
        case .downloadsTemp: "arrow.down.circle"
        case .timeMachine: "clock.arrow.circlepath"
        case .unusedApps: "square.dashed"
        case .oldRecordings: "film"
        case .loginItems: "person.crop.circle.badge.questionmark"
        case .network: "network"
        case .whereWritten: "doc.text"
        case .editByHand: "slider.horizontal.3"
        case .healthReport: "heart.text.square"
        case .privacy: "lock.shield"
        }
    }

    /// A deep link target string for this topic.
    var target: String { "howItWorks:\(rawValue)" }

    static func parse(_ target: String) -> HowItWorksTopic? {
        guard target.hasPrefix("howItWorks:") else { return nil }
        return HowItWorksTopic(rawValue: String(target.dropFirst("howItWorks:".count)))
    }
}

/// What a topic's screen says, written with this Mac's numbers.
struct TopicContent {
    struct Button: Identifiable {
        let title: String
        let target: String
        var id: String { title }
    }

    /// The one sentence on the topic's row in the list, with this Mac's number in it.
    var summary: String
    var does: [String] = []
    var never: [String] = []
    var written: [String] = []
    var buttons: [Button] = []
}
