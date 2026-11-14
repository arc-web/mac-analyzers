import SwiftUI
import AnalyzersKit
import UIComponents

/// Which releases the What's New list shows: a filter (the same rows, fewer), so a toolbar menu and not tabs.
enum WhatsNewFilter: String, CaseIterable, Identifiable {
    case all, latest
    var id: String { rawValue }
    var title: String { self == .all ? Names.WhatsNew.allReleases : Names.WhatsNew.latestRelease }
    var symbol: String { self == .all ? "clock.arrow.circlepath" : "sparkles" }
}

/// Where the notes behind What's New come from, shared by the list and each feature's screen so both read the
/// same releases (and the same cached load).
@MainActor
enum WhatsNewSource {
    static func notes(updates: UpdateState) async -> [ReleaseNote] {
        let channel = updates.channel
        let channelText = updates.channelChangelog
        // Beta and This Copy read the unreleased section from THEIR changelog (development's, or the
        // clone's with its uncommitted edits); the releases below are the bundled ones.
        let includeNext = channel == .releases && updates.build.isDevelopment
        // keyed by what the notes are made of: the channel, whether the unreleased part is in, and the text itself
        var result: [ReleaseNote] = []
        await awaitLoad({ ReleaseNote.channelNotes(channel: channel, changelog: channelText, includeNext: includeNext) },
                        key: "update.notes.\(channel).\(includeNext).\(channelText.hashValue)") { result = $0 }
        return result
    }
}

/// The What's New sections of the Updates list: what is not yet released first, then the features of the
/// releases grouped by the screen they belong to, each a row that pushes its own screen. Returns sections, so it
/// goes inside the screen's `List`.
struct WhatsNewSections: View {
    let notes: [ReleaseNote]
    let filter: WhatsNewFilter
    /// The release the person had seen before this visit: later ones are marked New.
    let seen: String?

    /// The id of the first row, which a link to the list scrolls to.
    static let anchor = "whatsNew"

    @Environment(Navigator.self) private var navigator
    /// Features shown at once: a list never gains more than 200 rows in one update.
    @State private var limit = 200

    var body: some View {
        let unreleased = notes.filter(\.isUnreleased)
        let shown = releasedItems
        let capped = Array(shown.prefix(limit))
        ForEach(unreleased) { note in
            Section {
                rows(note.items)
            } header: {
                header(title: note.title, symbol: "hammer", count: note.items.count)
            }
        }
        ForEach(WhatsNewGroups.build(items: capped)) { group in
            Section {
                rows(group.items)
            } header: {
                header(title: group.title, symbol: group.symbol, count: group.items.count)
            }
        }
        if shown.count > capped.count {
            Button { limit += 200 } label: {
                Label(Names.Raw.showOlder, systemImage: "clock.arrow.circlepath")
                Text("\(shown.count - capped.count) earlier features").foregroundStyle(.secondary)
            }
        }
    }

    /// The released features, newest release first, narrowed by the filter.
    private var releasedItems: [WhatsNewItem] {
        let released = notes.filter { !$0.isUnreleased }
        let chosen = filter == .latest ? Array(released.prefix(1)) : released
        return chosen.flatMap(\.items)
    }

    private func rows(_ items: [WhatsNewItem]) -> some View {
        ForEach(items) { item in
            WhatsNewRow(item: item, isNew: WhatsNewSeen.isNew(item.version, seen: seen)) {
                navigator.push(.app(.whatsNew(item.id)))
            }
            .id(item.id == firstID ? Self.anchor : item.id)
        }
    }

    private var firstID: String? {
        notes.first(where: \.isUnreleased)?.items.first?.id
            ?? WhatsNewGroups.build(items: Array(releasedItems.prefix(limit))).first?.items.first?.id
    }

    private func header(title: String, symbol: String, count: Int) -> some View {
        HStack {
            Label(title, systemImage: symbol).font(.headline)
            Text("\(count)").foregroundStyle(.secondary).monospacedDigit()
        }
    }
}
