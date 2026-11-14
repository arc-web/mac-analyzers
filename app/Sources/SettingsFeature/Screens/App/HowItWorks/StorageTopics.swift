import Foundation
import AnalyzersKit

/// The Storage tab's topics, written with this Mac's numbers.
extension HowItWorksTopic {

    func storageContent(_ f: HowItWorksFacts) -> TopicContent {
        let runway = f.runway.map { " At your current pace the disk fills in \($0)." } ?? ""
        let weekCleanups = f.logsRead ? " \(f.week.cleanRuns) cleanups this week." : ""
        switch self {
        case .safeToRemove:
            let reclaimable = !f.logsRead ? "" : (f.week.reclaimableBytes.map {
                "The latest preview found \(ByteSize.text($0, .headline)) you could take back."
            } ?? "Nothing is waiting from a preview.")
            return TopicContent(
                summary: "\(f.freeDisk) free of \(f.totalDisk)." + weekCleanups,
                does: [
                    "Your startup disk has \(f.freeDisk) free of \(f.totalDisk).\(runway)",
                    "Caches & Builds finds what can be made again: build caches, the dependency folders of projects you have not touched for \(f.days(f.nodeModulesDays))\(f.nodeModulesNeedClean ? ", and only when they have no unsaved changes" : ""), and package-manager caches. \(reclaimable)",
                    "Every cleanup is a preview first. You see what would be removed and untick anything you want kept. Only then does Apply start, and what it removes goes to the Trash or is made again by your tools, so Undo can bring it back where that is possible.",
                ] + (f.logsRead ? ["In the last 7 days, \(f.week.cleanRuns) cleanups freed \(ByteSize.text(f.week.storageFreedBytes, .headline))."] : []),
                never: [
                    "Nothing is removed from a project that is open in an editor or in use, and nothing is removed without a preview you reviewed.",
                ],
                written: ["Each run writes a full report and appears in Activity (see \(Names.HowItWorks.whereWritten))."],
                buttons: [.init(title: "Open \(Names.Screen.cachesAndBuilds)", target: "caches"),
                          .init(title: Names.HowItWorks.change, target: "storage")])

        case .downloadsTemp:
            return TopicContent(
                summary: "Downloads older than \(f.days(f.downloadsDays)), screenshots older than \(f.days(f.screenshotsDays)).",
                does: [
                    "Downloads looks for files you have not changed for \(f.days(f.downloadsDays)), and for screenshots older than \(f.days(f.screenshotsDays)). You review them in a preview; what you apply goes to the Trash.",
                    "Temp & Agents clears temporary files that have been idle for a day, scratch folders of coding agents idle for three days, and tool downloads idle for two weeks.",
                    "macOS also clears /tmp by itself every night: files nobody has touched for three days. It skips mounted disk images and anything still in use.",
                ],
                never: ["Anything that is open, in use, owned by someone else, or a mounted disk image you have not approved is never touched."],
                written: ["Each run writes a report and appears in Activity (see \(Names.HowItWorks.whereWritten))."],
                buttons: [.init(title: "Open \(Names.Screen.downloads)", target: "downloads"),
                          .init(title: "Open \(Names.Screen.tempAndAgents)", target: "temp")])

        case .timeMachine:
            let permission = f.timeMachinePermission
                ? "You have given that permission on this Mac."
                : "You have not given that permission on this Mac yet, so Mac Analyzers will ask the first time you delete snapshots."
            return TopicContent(
                summary: f.timeMachinePermission ? "Permission given on this Mac." : "Needs a one-time permission.",
                does: [
                    "While Time Machine backs up, macOS keeps hourly snapshots on this Mac, and they use disk space. The Time Machine screen lists them so you can delete the ones you do not need.",
                    "Deleting snapshots needs a one-time permission, with your administrator password, for exactly one command. After that, any program running on your account can delete local snapshots without asking, and nothing else is allowed. \(permission)",
                ],
                never: ["Mac Analyzers never touches your backups on the backup disk. It only deletes local snapshots on this Mac, and only after you confirm."],
                written: ["The permission is one small file. You can remove it from the \(Names.Screen.timeMachine) screen or from Setup."],
                buttons: [.init(title: "Open \(Names.Screen.timeMachine)", target: "timemachine")])

        case .unusedApps:
            return TopicContent(
                summary: "Apps you have not opened in a long time, shown for you to decide.",
                does: [
                    "Unused Apps lists apps you have never opened or have not opened in a long time, using what macOS recorded about their use. Apps with no record of use are listed separately, since not knowing is not the same as not using.",
                    "You choose what to move, and it goes to the Trash.",
                ],
                never: ["Apps that are running now are left alone, and nothing is moved without your review."],
                written: ["Each run appears in Activity (see \(Names.HowItWorks.whereWritten))."],
                buttons: [.init(title: "Open \(Names.Screen.unusedApps)", target: "unused")])
        default:
            return TopicContent(summary: "")
        }
    }
}
