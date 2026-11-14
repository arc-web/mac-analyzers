import Foundation
import AnalyzersKit

/// What an installed background job does by itself, written for the person from the arguments its plist actually passes (a
/// flag in the plist is the only source of a claim here: `--apply` applies, `--dev`, `--docker-running-only`, `--prune-snapshots`
/// and the rest each add one sentence) and from the settings the script reads. A job whose command could not be read says only
/// when it runs.
extension HowItWorksFacts.ScheduleLine {
    func has(_ flag: String) -> Bool { arguments.contains(flag) }

    func value(after flag: String) -> String? {
        arguments.firstIndex(of: flag).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
    }
}

extension HowItWorksFacts {
    private static let withoutPreview = " It applies what it finds by itself, without a preview, so nothing waits for your review."

    /// The memory clean's own sentence (`memory-auto-clean.sh`, sections 1, 2 and 4 to 10 of its header, or 1, 2 and 7 to 10 with `--dev`).
    func memoryCleanDoes(_ label: String) -> String? {
        guard let line = schedule(label), line.installed, let when = line.when else { return nil }
        guard !line.arguments.isEmpty else { return "\(line.name) runs \(when.lowercased())." }
        guard line.has("--apply") else {
            return "\(line.name) runs \(when.lowercased()), but only previews: it closes nothing."
        }
        var does = ["closes coding-agent servers whose session has ended",
                    "closes developer-tool processes whose parent is gone once they have sat idle"]
        if !line.has("--dev") {
            does.append("closes development servers left running for more than \(line.value(after: "--dev-age-hours") ?? "24") hours")
            does.append("closes headless test browsers left running for more than 2 hours")
        }
        does.append("closes development servers nobody is using")
        does.append("shuts down emulators and simulators nobody is using")
        does.append("stops Gradle and Kotlin build daemons while no build is running")
        return "\(line.name) runs \(when.lowercased()) and \(Names.Setup.list(does)). It never touches your apps, your protected programs or anything that belongs to a coding session that is running now."
            + Self.withoutPreview
    }

    /// A storage clean's own sentence (`storage-auto-clean.sh`), daily or deep by the plist's `--mode`.
    func storageCleanDoes(_ label: String) -> String? {
        guard let line = schedule(label), line.installed, let when = line.when else { return nil }
        guard !line.arguments.isEmpty else { return "\(line.name) runs \(when.lowercased())." }
        guard line.has("--apply") else {
            return "\(line.name) runs \(when.lowercased()), but only previews: it removes nothing."
        }
        let deep = line.value(after: "--mode") == "deep"
        var does = ["removes build folders (.next, .turbo, dist, build and the like) that nothing has written to for \(days(Int(line.value(after: "--cache-age-days") ?? "") ?? 3))",
                    "trims each project's Turborepo cache to \(turboCacheMaxGB) GB"]
        if toolCacheCount > 0 { does.append("clears the \(toolCacheCount) \(toolCacheCount == 1 ? "tool cache" : "tool caches") you opted into") }
        if deep {
            does.append("removes the dependency folders (node_modules) of projects whose files have not changed for \(days(nodeModulesDays))\(nodeModulesNeedClean ? " and whose changes are all saved in git" : "")")
            if worktreeIdleDays > 0 { does.append("removes git worktrees idle for \(days(worktreeIdleDays)) (never a project's main checkout)") }
            does.append("empties npm's cache and prunes the packages pnpm no longer references")
        }
        if line.has("--docker-images") {
            does.append("removes every Docker image nothing uses, starting Docker first if it is not running and quitting it again if it started it")
        } else if line.has("--docker") {
            does.append("prunes stopped containers, unused networks and dangling images in Docker, starting it first if needed")
        } else if line.has("--docker-running-only") {
            does.append("when Docker is already running, prunes its stopped containers, unused networks and dangling images (it never starts Docker)")
        }
        if line.has("--prune-snapshots") {
            does.append(timeMachinePermission
                ? "thins Time Machine's local snapshots on this Mac (never the backups on the backup disk)"
                : "would thin Time Machine's local snapshots, but skips them until you give the permission (see \(Names.HowItWorks.timeMachine))")
        }
        let live = deep ? " Projects that something live runs from, a running process or a loaded background agent, are left alone." : ""
        return "\(line.name) runs \(when.lowercased()) and \(Names.Setup.list(does)).\(live)" + Self.withoutPreview
    }
}
