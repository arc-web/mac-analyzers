import AppKit
import Foundation

/// What one look found: the rules in force, what each does, and the groups it looked at.
public struct RulesLook: Sendable {
    public let rules: GuardRules
    public let evaluation: RuleEvaluation
    public let groups: [CensusGroup]
}

/// The rules engine in the app: looks at what is running now and then, says what each rule would do, and writes it down.
/// It acts on nothing in this version: its only output is rows in `rule-outcomes.jsonl` and what the Memory Guard screen
/// shows. The guard script does what it always did. One engine for the app, so a rule that waits for a time (over its
/// limit for five minutes) is remembered between looks.
public actor RulesEngine {

    public static let shared = RulesEngine()

    private var state = RulesState()
    private var watching = false
    private var seeded = false

    /// One look at the real process table. With `write`, the would-have rows are added to the file; without it (a screen
    /// asking what matches now) no file is written AND the once-a-day keys stay as they were, so the watcher's next look still
    /// writes the day's row. The time a unit has been over its limit is still updated: that is what was observed.
    public func look(frontApps: Set<String> = [], write: Bool) -> RulesLook {
        if write, !seeded {
            // a relaunch does not write the day's rows again: what today's file holds counts as written
            state.seed(from: RuleOutcomes.read(since: Calendar.current.startOfDay(for: Date())), now: Date())
            seeded = true
        }
        let rules = GuardRules.load()
        let groups = MemoryCensus.take().groups
        let result = state.look(rules: rules, groups: groups, facts: .live(frontApps: frontApps), write: write)
        if write { RuleOutcomes.append(result.outcomes) }
        return RulesLook(rules: rules, evaluation: result, groups: groups)
    }

    /// One look a minute for as long as the app runs, the first after a short wait so a launch is not slowed. The caller
    /// supplies the app in front (it can only be read on the main thread).
    public func startWatching(frontApps: @escaping @Sendable () async -> Set<String>) {
        guard !watching else { return }
        watching = true
        Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(for: .seconds(90))
            while !Task.isCancelled {
                let front = await frontApps()
                _ = await self?.look(frontApps: front, write: true)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }
}

public extension RulesState {
    /// One evaluation on this state. `evaluate` marks every row it returns as written for the day, so a look whose rows are
    /// discarded (`write` false) puts those keys back: the watcher's next look must still produce the day's row. The time a
    /// unit has been over its limit stays updated, since that was observed.
    mutating func look(rules: GuardRules, groups: [CensusGroup], facts: RuleFacts, write: Bool) -> RuleEvaluation {
        let before = written
        let result = RuleEvaluator.evaluate(rules: rules, groups: groups, facts: facts, state: &self)
        if !write { written = before }
        return result
    }
}

public extension RulesEngine {
    /// The names (lowercased) of the app in front, read on the main thread.
    @MainActor static func frontAppNames() -> Set<String> {
        var names = Set<String>()
        if let app = NSWorkspace.shared.frontmostApplication {
            if let name = app.localizedName { names.insert(name.lowercased()) }
            if let id = app.bundleIdentifier { names.insert(id.lowercased()) }
        }
        return names
    }
}
