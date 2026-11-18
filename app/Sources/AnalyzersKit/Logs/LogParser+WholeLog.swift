import Foundation
import os

/// Every run in a block log, for totals over a period.
///
/// `LogParser.runs(for:)` reads the last 256 KB and keeps the newest 20 runs:
/// the right size for a list, the wrong one for a 30-day sum, because a log that
/// is previewed every few minutes pushes the runs that freed space out of both
/// limits within a day. The grouping is `LogParser.runBlocks`, the one the list
/// uses, so a run begins in the same place for every reader.
extension LogParser {

    /// Newest first, no window, no cap. Day-style logs (the guard) have no
    /// block structure and read as `runs(for:)` does.
    public static func allRuns(for kind: EngineLog, includingRestores: Bool = false) -> [LogRun] {
        kind.url.map { allRuns(at: $0, includingRestores: includingRestores) } ?? []
    }

    /// The same over any file (a probe reads a copy the way the real one is read).
    public static func allRuns(at url: URL, includingRestores: Bool = false) -> [LogRun] {
        // Trends asks for the same whole log several times in one load (reaped, removed, latest preview, by project)
        // and again on every period change: it is read and split once for as long as the file is unchanged.
        let stamp = (try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]))
            .map { WholeLogStamp(path: url.path, modified: $0.contentModificationDate, size: $0.fileSize, restores: includingRestores) }
        if let stamp, let hit = wholeLogCache.withLock({ $0[stamp] }) { return hit }
        let runs = readAllRuns(at: url, includingRestores: includingRestores)
        if let stamp {
            wholeLogCache.withLock { cache in
                // one entry per file and flavour: a changed file replaces its older entry instead of piling up
                cache = cache.filter { $0.key.path != stamp.path || $0.key.restores != stamp.restores }
                cache[stamp] = runs
            }
        }
        return runs
    }

    private struct WholeLogStamp: Hashable {
        let path: String
        let modified: Date?
        let size: Int?
        let restores: Bool
    }
    private static let wholeLogCache = OSAllocatedUnfairLock(initialState: [WholeLogStamp: [LogRun]]())

    private static func readAllRuns(at url: URL, includingRestores: Bool) -> [LogRun] {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return [] }
        guard data.range(of: Data("====".utf8)) != nil else { return runs(at: url, includingRestores: includingRestores) }
        return runBlocks(LogLines.lines(in: data), includingRestores: includingRestores, limit: nil)
    }
}
