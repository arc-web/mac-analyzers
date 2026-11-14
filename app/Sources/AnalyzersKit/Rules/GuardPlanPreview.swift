import AppKit
import Foundation

/// What the Memory Guard Plan tab says about the plan right now, written once: the steps of "When Memory Runs Out" in the order
/// they are tried, what each would pick now, what is protected, and whether it is Watching or Acting. The Plan tab and the Welcome
/// flow's Memory Guard step both read it, so the two can never interpret the plan differently.
public enum GuardPlanPreview {

    /// The sentence that keeps "only watches" true wherever the plan is shown.
    public static let watchingNote = "Memory Guard is only watching in this version: a step marked Watching records what it would have done and stops nothing. "
        + "The dev-tooling steps marked Acting are the ones the guard script already carries out."

    /// "Would pick now: next-server, 3.1 GB (Dev Servers).", or why it cannot say.
    public static func wouldPick(_ pick: StepPick?, _ step: ResolvedRule) -> String {
        if case .cantRun(let why) = step.state { return "Can't run: \(why)." }
        if step.state == .off { return "Off." }
        if let note = pick?.note { return note }
        if let match = pick?.match { return "Would pick now: \(match.unit.name), \(MemorySize.text(match.unit.bytes)) (\(match.kind.name))." }
        return "Would pick now: nothing."
    }

    public struct Protected: Sendable, Hashable {
        public let name: String
        public let why: String
        public let symbol: String
    }

    /// What nothing may touch right now, from what is running. `front` is the app in front.
    public static func protectedNow(rules: GuardRules, groups: [CensusGroup], front: String?) -> [Protected] {
        var found: [Protected] = []
        for group in groups {
            if rules.protected.kinds.contains(group.kind.id) {
                found.append(Protected(name: group.name, why: group.kind == rules.catalog.kind(id: "tools.codingAgents") ? "a live coding session" : group.kind.name,
                                       symbol: "lock.fill"))
            } else if rules.protected.names.contains(group.name.lowercased()) {
                found.append(Protected(name: group.name, why: "never touched", symbol: "lock.fill"))
            }
        }
        if let front { found.append(Protected(name: front, why: "the app in front", symbol: "macwindow")) }
        for name in rules.local.neverClose { found.append(Protected(name: name, why: "on your Never Close list", symbol: "hand.raised.fill")) }
        var seen = Set<String>()
        return Array(found.filter { seen.insert($0.name.lowercased() + $0.why).inserted }.prefix(24))
    }

    /// One step of the plan as the Welcome step shows it.
    public struct Step: Sendable, Identifiable {
        public let id: String
        public let summary: String
        public let state: RuleState
        public let wouldPick: String
    }

    /// The plan as one value: read from a look at what is running (`RulesEngine.look`, which writes nothing when asked not to).
    public struct Plan: Sendable {
        public let ladder: String
        public let steps: [Step]
        public let protected: [Protected]
        public let note: String

        public init(ladder: String, steps: [Step], protected: [Protected], note: String = GuardPlanPreview.watchingNote) {
            self.ladder = ladder
            self.steps = steps
            self.protected = protected
            self.note = note
        }

        public init(look: RulesLook, front: String?) {
            let picks = look.evaluation.picks
            ladder = GuardRule.ladderSentence(look.rules.steps.filter { $0.state != .off }.map(\.rule))
            steps = look.rules.steps.map { step in
                Step(id: step.id, summary: step.rule.summary, state: step.state,
                     wouldPick: GuardPlanPreview.wouldPick(picks.first { $0.rule.id == step.id }, step))
            }
            protected = GuardPlanPreview.protectedNow(rules: look.rules, groups: look.groups, front: front)
            note = GuardPlanPreview.watchingNote
        }
    }
}
