import Foundation
import Observation
import AnalyzersKit

/// This Mac's own numbers, as the topics quote them. Every figure comes from the kernel that already owns it (the memory
/// breakdown, the config reader, the schedules, the guard log through Trends, the disk runway, the kind catalog): this
/// file reads them once and never classifies or counts a second way.
struct HowItWorksFacts: Sendable {
    struct Week: Sendable {
        var stopped = 0, spikes = 0, pressure = 0, cpuHogs = 0
        var memoryFreedMB = 0
        var storageFreedBytes: Int64 = 0
        var cleanRuns = 0
        var reclaimableBytes: Int64?
    }

    /// One background job as it is INSTALLED on this Mac: when it runs, and whether the installed command applies what it
    /// finds by itself (`--apply`) or only previews. Read from the plist through `ScheduleKit`, never assumed.
    struct ScheduleLine: Identifiable, Sendable {
        let label: String
        let name: String
        let installed: Bool
        let when: String?
        /// nil when the installed command could not be read.
        let appliesByItself: Bool?
        /// What the job does, from the kit's own description of it.
        let detail: String
        var id: String { label }
    }

    var memory: MemoryBreakdown?
    var disk: DiskUsage?
    var runway: String?
    var week = Week()
    /// The week's figures and the disk runway read whole logs and arrive after the rest: until `logsRead`, the topics leave
    /// out any sentence that quotes them rather than say "0".
    var logsRead = false

    // the settings the topics quote
    var hardCapMB = 6144
    var hardCapStops = true
    var pressureStops = true
    var spikeMB = 400
    var spikeMinMB = 1024
    var cpuHogPercent = 150
    var cpuHogChecks = 3
    var guardIntervalSeconds = 15
    var tempIdleHours = 24
    var tempAgentScratchDays = 3
    var tempToolDownloadDays = 14
    var protectedExtra = 0
    var alsoQuit = 0
    var downloadsDays = 30
    var screenshotsDays = 14
    var nodeModulesDays = 14
    var nodeModulesNeedClean = true
    var recordingsDays = 90
    var turboCacheMaxGB = 2

    /// The kinds of program the guard may stop by itself: the kind catalog's developer-tooling kinds, by name.
    var devToolKinds: [String] = []
    var schedules: [ScheduleLine] = []
    var channel = UpdateChannel.releases
    var guardLogBytes: Int64?
    var timeMachinePermission = false
    var version = ""

    // MARK: - sentences the topics share
    // A value that was not read is nil, and the sentence that would quote it is left out (never a stand-in word).

    var totalMemory: String? { memory.map { ByteSize.text($0.totalBytes, .headline) } }
    var usedMemory: String? { memory.map { ByteSize.text($0.usedBytes, .headline) } }
    var compressed: String? { memory.map { ByteSize.text($0.compressedBytes, .headline) } }
    var compressedOriginal: String? { memory.map { ByteSize.text($0.compressedOriginalBytes, .headline) } }
    var limit: String { megabytes(hardCapMB) }
    /// "about 20 percent of your 32 GB", when this Mac's memory was read.
    var limitShare: String? {
        guard let memory, memory.totalBytes > 0, let total = totalMemory else { return nil }
        let share = Double(hardCapMB) * 1_048_576 / Double(memory.totalBytes)
        return "about \(Int((share * 100).rounded())) percent of your \(total)"
    }
    var freeDisk: String? { disk.map { ByteSize.text($0.freeBytes, .headline) } }
    var totalDisk: String? { disk.map { ByteSize.text($0.totalBytes, .headline) } }
    /// "6.5 GB, about 20 percent of your 32 GB", or just "6.5 GB".
    var limitPhrase: String { limitShare.map { "\(limit), \($0)" } ?? limit }
    /// "1 day", "14 days".
    func days(_ n: Int) -> String { "\(n) \(n == 1 ? "day" : "days")" }
    /// A size kept in megabytes, written the way every size in the app is (`ByteSize`).
    func megabytes(_ mb: Int) -> String { ByteSize.text(Int64(mb) * 1_048_576, .headline) }

    func schedule(_ label: String) -> ScheduleLine? { schedules.first { $0.label == label } }

    /// What one background job does BY ITSELF on this Mac, from its installed schedule: when, and that it applies without
    /// a preview if the installed command does. nil when it is not installed (the caller says so).
    func byItself(_ label: String, does what: String) -> String? {
        guard let line = schedule(label), line.installed, let when = line.when else { return nil }
        let applying = line.appliesByItself == true
            ? " It applies what it finds by itself, without a preview, so nothing waits for your review."
            : ""
        return "\(line.name) runs \(when.lowercased()) and \(what).\(applying)"
    }

    /// "1 hour", "24 hours".
    func hours(_ n: Int) -> String { "\(n) \(n == 1 ? "hour" : "hours")" }
    /// "every 15 seconds", "every second".
    var guardEvery: String { guardIntervalSeconds == 1 ? "every second" : "every \(guardIntervalSeconds) seconds" }

    func notScheduled(_ label: String) -> String {
        "\(schedule(label)?.name ?? label) is not scheduled on this Mac."
    }
}

/// Loads the facts once and keeps them for a minute, so opening a topic from the list does not read the logs again.
@MainActor @Observable
final class HowItWorksModel {
    static let shared = HowItWorksModel()

    private(set) var facts: HowItWorksFacts?
    private var loadedAt = Date.distantPast

    func load() async {
        if facts?.logsRead == true, Date().timeIntervalSince(loadedAt) < 60 { return }
        var f = HowItWorksFacts()
        let config = ConfigStore()
        f.hardCapMB = config.memory.hardCapMB
        f.hardCapStops = config.memory.hardCapKill
        f.pressureStops = config.memory.pressureKill
        f.spikeMB = config.memory.spikeMB
        f.spikeMinMB = config.memory.spikeMinMB
        f.cpuHogPercent = config.memory.cpuHogPct
        f.cpuHogChecks = config.memory.cpuHogTicks
        f.guardIntervalSeconds = config.memory.guardIntervalSeconds
        f.tempIdleHours = config.storage.tempIdleHours
        f.tempAgentScratchDays = config.storage.tempAgentScratchDays
        f.tempToolDownloadDays = config.storage.tempToolDownloadDays
        f.protectedExtra = config.memory.protectExtra.count
        f.alsoQuit = config.memory.reclaimApps.count
        f.downloadsDays = config.storage.janitorDownloadsDays
        f.screenshotsDays = config.storage.janitorScreenshotsDays
        f.nodeModulesDays = config.storage.nmAgeDays
        f.nodeModulesNeedClean = config.storage.nmRequireClean
        f.recordingsDays = config.storage.recordingsDays
        f.turboCacheMaxGB = config.storage.turboCacheMaxGB
        f.devToolKinds = KindCatalog.current.kinds.filter(\.devTooling).map(\.name)
        f.schedules = ScheduleKit.jobs.map { job in
            let installed = ScheduleKit.isInstalled(job.label)
            return HowItWorksFacts.ScheduleLine(
                label: job.label, name: Names.Setup.jobTitle(job.label), installed: installed,
                when: installed ? ScheduleKit.describe(job.label) : nil,
                appliesByItself: ScheduleKit.programArguments(for: job.label).map { $0.contains("--apply") },
                detail: job.detail)
        }
        f.channel = UpdateChannel.saved
        f.timeMachinePermission = TimeMachinePermission.ruleFileExists()
        f.version = BuildInfo.current.shortVersion
        f.disk = LiveStats.diskUsage()
        if let size = try? FileManager.default.attributesOfItem(atPath: AnalyzersPaths.guardLog.path)[.size] as? Int64 {
            f.guardLogBytes = size
        }
        await awaitLoad({ MemoryBreakdown.current() }, ttl: 10, key: "howItWorks.memory") { f.memory = $0 }
        guard !Task.isCancelled else { return }
        // the screen opens now, with everything that was quick to read
        facts = f
        loadedAt = Date()
        await awaitLoad({ DiskRunway.current()?.text }, ttl: 60, key: "howItWorks.runway") { f.runway = $0 }
        await awaitLoad({ TrendsModel.snapshot(period: .week) }, ttl: 60, key: "howItWorks.week") { snapshot in
            f.week = .init(stopped: snapshot.kills, spikes: snapshot.spikes, pressure: snapshot.pressure,
                           cpuHogs: snapshot.cpuHogs, memoryFreedMB: snapshot.memoryFreedMB,
                           storageFreedBytes: snapshot.storageFreedBytes, cleanRuns: snapshot.cleanRuns,
                           reclaimableBytes: snapshot.latestReclaimableBytes)
        }
        guard !Task.isCancelled else { return }
        f.logsRead = true
        facts = f
        loadedAt = Date()
    }
}
