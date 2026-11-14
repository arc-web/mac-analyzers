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

    struct ScheduleLine: Identifiable, Sendable {
        let name: String
        let text: String
        var id: String { name }
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
    var guardLogBytes: Int64?
    var timeMachinePermission = false
    var version = ""

    // MARK: - sentences the topics share

    var totalMemory: String { memory.map { ByteSize.text($0.totalBytes, .headline) } ?? "your Mac's memory" }
    var usedMemory: String { memory.map { ByteSize.text($0.usedBytes, .headline) } ?? "some" }
    var compressed: String { memory.map { ByteSize.text($0.compressedBytes, .headline) } ?? "some" }
    var compressedOriginal: String { memory.map { ByteSize.text($0.compressedOriginalBytes, .headline) } ?? "some" }
    var limit: String { megabytes(hardCapMB) }
    /// "1 day", "14 days".
    func days(_ n: Int) -> String { "\(n) \(n == 1 ? "day" : "days")" }
    /// A size kept in megabytes, written the way every size in the app is (`ByteSize`).
    func megabytes(_ mb: Int) -> String { ByteSize.text(Int64(mb) * 1_048_576, .headline) }
    /// "a fifth of your 32 GB", or "about 21 percent of your 32 GB".
    var limitShare: String {
        guard let memory, memory.totalBytes > 0 else { return limit }
        let share = Double(hardCapMB) * 1_048_576 / Double(memory.totalBytes)
        return "about \(Int((share * 100).rounded())) percent of your \(totalMemory)"
    }
    var freeDisk: String { disk.map { ByteSize.text($0.freeBytes, .headline) } ?? "some" }
    var totalDisk: String { disk.map { ByteSize.text($0.totalBytes, .headline) } ?? "your startup disk" }
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
        f.protectedExtra = config.memory.protectExtra.count
        f.alsoQuit = config.memory.reclaimApps.count
        f.downloadsDays = config.storage.janitorDownloadsDays
        f.screenshotsDays = config.storage.janitorScreenshotsDays
        f.nodeModulesDays = config.storage.nmAgeDays
        f.nodeModulesNeedClean = config.storage.nmRequireClean
        f.recordingsDays = config.storage.recordingsDays
        f.turboCacheMaxGB = config.storage.turboCacheMaxGB
        f.devToolKinds = KindCatalog.current.kinds.filter(\.devTooling).map(\.name)
        f.schedules = ScheduleKit.jobs.map { .init(name: $0.displayName, text: ScheduleKit.describe($0.label)) }
        f.timeMachinePermission = TimeMachinePermission.ruleFileExists()
        f.version = UpdateChecker.installedVersion
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
