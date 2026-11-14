import Foundation
import AnalyzersKit

/// The Memory tab's topics, written with this Mac's numbers.
extension HowItWorksTopic {

    func memoryContent(_ f: HowItWorksFacts) -> TopicContent {
        switch self {
        case .measures:
            return TopicContent(
                summary: "\(f.usedMemory) of your \(f.totalMemory) is in use right now.",
                does: [
                    "The Monitor shows resident memory: the physical memory a program occupies right now. That is the number every size in Mac Analyzers shows, and the one Memory Guard acts on. On this Mac, \(f.totalMemory) is installed and \(f.usedMemory) is in use.",
                    "Activity Monitor's “Memory” column also counts compressed and swapped-out memory, so a program can show 7 GB or more there while its resident size stays under your limit of \(f.limit). That is why a big program can survive when memory pressure is low: macOS has already compressed it. Right now the compressor holds about \(f.compressedOriginal) of idle app memory in \(f.compressed) of real memory.",
                ],
                never: [
                    "Graphics (GPU) memory is deliberately not counted. macOS offers no public figure for how much of it each program uses, and on Apple Silicon's shared memory the pressure signal that Memory Guard already watches is the one that matters.",
                ],
                written: ["Looking at the Monitor writes nothing. What Memory Guard does is kept in its log (see \(Names.HowItWorks.whereWritten))."],
                buttons: [.init(title: "Open \(Names.Screen.monitor)", target: "monitor")])

        case .guardSteps:
            let hardCap = f.hardCapStops
                ? "When that program is over your limit (\(f.limit) on this Mac, \(f.limitShare)), it is stopped at any pressure level, at most once a minute, and a crisis report is written first so you can see what was using the memory. You can change Memory Guard to only warn you in Settings › Memory."
                : "When that program is over your limit (\(f.limit) on this Mac, \(f.limitShare)), Memory Guard writes a crisis report and tells you. You have switched it to warn only in Settings › Memory, so it stops nothing."
            let pressure = f.pressureStops
                ? "When macOS says memory is critically short, the biggest program Memory Guard may stop that is using more than 500 MB is stopped. You can switch this to warn only in Settings › Memory."
                : "When macOS says memory is critically short, Memory Guard tells you. You have switched it to warn only in Settings › Memory."
            let kinds = f.devToolKinds.isEmpty
                ? "Only developer tools are ever stopped automatically."
                : "Only developer tools are ever stopped automatically: \(f.devToolKinds.joined(separator: ", ")). That covers programs such as node, npm, bun, tsx and deno, the dev servers of Next.js, Vite, Webpack and Turbo, Vitest and Jest, and Playwright and headless browsers."
            return TopicContent(
                summary: "Your limit is \(f.limit), \(f.limitShare)." + (f.logsRead ? " This week: \(f.week.stopped) stopped, \(f.week.spikes) sudden jumps." : ""),
                does: [
                    "Memory Guard checks every 15 seconds. Each time it looks at the single biggest program it is allowed to stop.",
                    hardCap,
                    pressure,
                    "A sudden jump (a program growing by \(f.megabytes(f.spikeMB)) since the last check while using more than \(f.megabytes(f.spikeMinMB))) and a program using more than \(f.cpuHogPercent) percent of a processor for \(f.cpuHogChecks) checks in a row only ever notify you. Nothing is stopped for either.",
                    kinds,
                    "Rules for other kinds of program are only being watched: Memory Guard shows what they would have done and stops nothing for them.",
                ] + (f.logsRead ? ["In the last 7 days: \(f.week.stopped) programs stopped, \(f.week.spikes) sudden jumps, \(f.week.pressure) pressure warnings and \(f.week.cpuHogs) busy-processor alerts."] : []),
                never: [
                    "Stop and Quit in the Monitor are different: those are your own actions, so they work on any program, just as they do in Activity Monitor.",
                ],
                written: ["Every action is written in the guard log, and every stop first writes a crisis report (see \(Names.HowItWorks.whereWritten))."],
                buttons: [.init(title: "Open \(Names.Screen.memoryGuard)", target: "guard"),
                          .init(title: Names.HowItWorks.change, target: "memory")])

        case .guardNever:
            let extra = f.protectedExtra == 0
                ? "You have not added any programs of your own to the protected list."
                : "You have added \(f.protectedExtra) \(f.protectedExtra == 1 ? "program" : "programs") of your own to the protected list."
            return TopicContent(
                summary: "Apps and anything you protect are never stopped by themselves.",
                does: [
                    "Real apps, and anything on your protected list, are never stopped automatically. \(extra)",
                    "A program that belongs to a coding session that is running right now is always kept safe, and that is checked again at every stop.",
                ],
                never: [
                    "Memory Guard never stops an app or a protected program by itself, at any pressure.",
                    "It never stops anything that belongs to a live coding session.",
                    "Spikes and busy processors never stop anything: they only tell you.",
                ],
                written: ["The protected list is kept in your settings file (see \(Names.HowItWorks.editByHand))."],
                buttons: [.init(title: "Open \(Names.Screen.memoryGuard)", target: "guard"),
                          .init(title: Names.HowItWorks.change, target: "memory")])

        case .cleanup:
            let schedule = f.schedules.first { $0.name == "Memory auto-clean" }?.text ?? "Not scheduled"
            let alsoQuit = f.alsoQuit == 0
                ? "You have not listed any apps to be asked to quit."
                : "\(f.alsoQuit) \(f.alsoQuit == 1 ? "app is" : "apps are") on your list of apps to ask to quit."
            return TopicContent(
                summary: "Runs \(schedule.lowercased())." + (f.logsRead ? " This week it helped free \(f.megabytes(f.week.memoryFreedMB))." : ""),
                does: [
                    "Memory Cleanup looks for leftover developer and AI servers and old headless browsers. It runs \(schedule.lowercased()), and you can run it yourself from its screen.",
                    "It always shows a preview first. Nothing is closed until you review the preview and apply it. \(alsoQuit)",
                ],
                never: ["It never closes anything you did not see in a preview, and it never touches your protected programs."],
                written: ["Each run writes a full report (see \(Names.HowItWorks.whereWritten)) and appears in Activity."],
                buttons: [.init(title: "Open \(Names.Screen.memoryCleanup)", target: "actions:memoryClean"),
                          .init(title: Names.HowItWorks.change, target: "schedule")])
        default:
            return TopicContent(summary: "")
        }
    }
}
