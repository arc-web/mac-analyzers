import Foundation
import AnalyzersKit

/// The Your Data tab's topics: what is kept, where, and that none of it leaves this Mac.
extension HowItWorksTopic {

    func yourDataContent(_ f: HowItWorksFacts) -> TopicContent {
        let records = "~/mac-analyzers"
        switch self {
        case .whereWritten:
            let log = f.guardLogBytes.map { "The guard log is \(ByteSize.text($0, .headline)) on this Mac." } ?? "There is no guard log yet."
            return TopicContent(
                summary: "Everything is kept in \(records), nothing inside the app.",
                does: [
                    "Every action Memory Guard takes is written in the guard log. \(log)",
                    "Every cleanup writes a full report under \(records)/reports/, a folder for each day. Clicking any notification opens the app or the exact log behind it.",
                    "The Clear button in the menu-bar panel only resets what the panel shows. The logs are never trimmed by the app.",
                ],
                never: ["Nothing is written inside the app itself, so removing or updating the app never loses your records."],
                written: ["Your records folder is \(records). Your settings file is \(records)/config.local.sh."],
                buttons: [.init(title: "Open \(Names.Screen.reports)", target: "reports")])

        case .editByHand:
            let jobs = f.schedules.map { "\($0.name): \($0.text.lowercased())" }.joined(separator: "; ")
            return TopicContent(
                summary: "Plain shell scripts and one settings file you can open in any editor.",
                does: [
                    "The watching and cleaning is done by plain shell scripts that macOS's own scheduler (launchd) runs. This app is the control surface over them. On this Mac the jobs run like this: \(jobs).",
                    "The settings you change in this app are written into one marked block of \(records)/config.local.sh. Anything you write by hand outside that block is kept exactly as you wrote it.",
                ],
                never: ["The app never rewrites the parts of your settings file that it did not write."],
                written: ["Your settings file is \(records)/config.local.sh."],
                buttons: [.init(title: "Open \(Names.Screen.schedule) Settings", target: "schedule")])

        case .healthReport:
            return TopicContent(
                summary: "A one-page summary of the last 30 days, made on this Mac.",
                does: [
                    "The Mac Health Report is a one-page HTML summary of the last 30 days, for IT, family or a buyer. It is generated locally, from this Mac's own records: memory (\(f.totalMemory) installed), storage (\(f.freeDisk) free of \(f.totalDisk)) and what Mac Analyzers did.",
                ],
                never: ["It is not sent anywhere. You choose where to save it."],
                written: ["The report is saved where you choose; nothing is kept by the app."])

        case .privacy:
            return TopicContent(
                summary: "Everything is read and written on this Mac.",
                does: [
                    "Memory, storage, login items and network figures are read from this Mac and stay on it.",
                    "The only network request the app makes is a public check for a newer release, at launch and every 6 hours. It asks which version is newest and sends nothing about your Mac. You are on version \(f.version).",
                ],
                never: ["No usage data, logs or reports are uploaded, and there is no account."],
                written: ["Your records are in \(records) (see \(Names.HowItWorks.whereWritten))."],
                buttons: [.init(title: "Open \(Names.Screen.updates)", target: "update")])
        default:
            return TopicContent(summary: "")
        }
    }

    /// What a topic says on this Mac.
    func content(_ f: HowItWorksFacts) -> TopicContent {
        switch tab {
        case .memory: memoryContent(f)
        case .storage: storageContent(f)
        case .system: systemContent(f)
        case .yourData: yourDataContent(f)
        }
    }
}
