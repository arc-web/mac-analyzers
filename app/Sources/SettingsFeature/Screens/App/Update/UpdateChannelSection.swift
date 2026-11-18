import SwiftUI
import AnalyzersKit
import UIComponents

/// The channel part of the Updates screen: which channel this copy follows (a segmented picker, shown
/// when there is more than one to choose from) and, for Beta and This Copy, what that channel found. Releases
/// is the screen's own rows; this adds nothing to it but the picker.
struct UpdateChannelSection: View {
    @Bindable var updates: UpdateState
    let checking: Bool

    var body: some View {
        Section {
            if updates.channels.count > 1 {
                FullWidthSegments(options: updates.channels.map { ($0, $0.title) }, selection: $updates.channel,
                                  help: "Releases: the newest published release. Beta: the newest pre-release, published ahead of the next release (a release newer than it is offered too). This Copy: your own clone, uncommitted changes included.")
            } else {
                Text(Names.ChannelText.notAClone)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The rows a development channel adds under the installed version.
struct UpdateChannelRows: View {
    let updates: UpdateState
    let checking: Bool

    var body: some View {
        switch updates.channel {
        case .releases:
            EmptyView()
        case .beta:
            LabeledContent(Names.Channel.newestBeta) {
                Text(updates.newestBeta ?? (checking ? "Checking…" : "None Yet"))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .help("The newest beta published on GitHub: a pre-release of the next version")
            stateLabel
            if updates.cloneDirty == true {
                Label("Your clone has changes that are not committed yet. Updating moves your clone to the newest beta and builds those changes in too.",
                      systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
        case .thisCopy:
            if let facts = updates.cloneFacts {
                LabeledContent("Your Clone") {
                    Text(cloneLine(facts)).foregroundStyle(.secondary)
                }
                .help("The git clone this copy was built from, read with git on this Mac")
            }
            stateLabel
        }
    }

    private func cloneLine(_ facts: CloneFacts) -> String {
        var parts = [facts.branch ?? "no branch"]
        if case .cloneAhead(let count) = facts.relation { parts.append(count == 1 ? "1 newer commit" : "\(count) newer commits") }
        if facts.isDirty { parts.append("uncommitted changes") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var stateLabel: some View {
        if let state = updates.channelState {
            let text = state.sentence(for: updates.channel, facts: updates.cloneFacts)
            switch state {
            case .upToDate:
                Label(text, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .behind, .differs, .offered:
                Label(text, systemImage: "exclamationmark.circle.fill").foregroundStyle(.orange)
            case .ahead:
                Label(text, systemImage: "hammer.fill").foregroundStyle(.blue)
            case .unknown, .unavailable:
                Label(text, systemImage: "info.circle").foregroundStyle(.secondary)
            }
        }
    }
}
